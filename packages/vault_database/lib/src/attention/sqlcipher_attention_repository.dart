// SQL is intentionally visible for auditability of deterministic rules.
// ignore_for_file: public_member_api_docs, avoid_dynamic_calls
// ignore_for_file: always_use_package_imports, prefer_single_quotes
// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: prefer_if_elements_to_conditional_expressions
// ignore_for_file: avoid_escaping_inner_quotes

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_domain/vault_domain.dart';

import '../database/encrypted_database_opener.dart';

final class SqlCipherAttentionRepository {
  SqlCipherAttentionRepository(this.session, this.random);

  final VaultDatabaseSession session;
  final CryptographicRandom random;

  Future<void> recalculate({
    required DateTime now,
    int inboxCount = 0,
  }) => session.write((db) async {
    final calculatedAt = now.toUtc().millisecondsSinceEpoch;
    await db.customStatement(
      "UPDATE attention_items SET status = 'RESOLVED', updated_at = ? "
      "WHERE status = 'ACTIVE'",
      [calculatedAt],
    );
    final entities = await db
        .customSelect(
          'SELECT e.id, '
          "SUM(CASE WHEN c.status = 'CONFIRMED' THEN 1 ELSE 0 END) "
          'AS confirmed_count, '
          "SUM(CASE WHEN c.status = 'SUGGESTED' THEN 1 ELSE 0 END) "
          'AS suggested_count '
          'FROM entities e LEFT JOIN claims c ON c.subject_entity_id = e.id '
          "WHERE e.status = 'ACTIVE' GROUP BY e.id",
        )
        .get();
    for (final entity in entities) {
      final confirmed = entity.read<int>('confirmed_count');
      final suggested = entity.read<int>('suggested_count');
      final kind = confirmed > 0
          ? LifeStateKind.ok
          : suggested > 0
          ? LifeStateKind.incomplete
          : LifeStateKind.unknown;
      await _recordEvaluation(
        db,
        kind: kind,
        category: AttentionCategory.inbox,
        title: 'Profile completeness',
        explanation: confirmed > 0
            ? 'The profile has $confirmed user-confirmed fact(s).'
            : suggested > 0
            ? 'The profile has $suggested suggested fact(s) awaiting a user '
                  'decision and no confirmed facts.'
            : 'The profile has no confirmed or suggested facts. OwnKeep '
                  'reports UNKNOWN instead of guessing.',
        priority: 100,
        entityId: entity.read<String>('id'),
        ruleId: 'entity.completeness',
        ruleVersion: '1',
        inputFingerprint: 'confirmed:$confirmed;suggested:$suggested',
        calculatedAt: calculatedAt,
        createAttention: false,
      );
    }
    final claims = await db
        .customSelect(
          'SELECT c.id, c.subject_entity_id, c.predicate, c.value_type, '
          'v.date_value, v.datetime_value, '
          '(SELECT e.document_id FROM evidence_links e '
          'WHERE e.claim_id = c.id ORDER BY e.created_at LIMIT 1) '
          'AS evidence_document_id FROM claims c '
          'JOIN claim_values v ON v.claim_id = c.id '
          "WHERE c.status = 'CONFIRMED'",
        )
        .get();
    for (final claim in claims) {
      final predicate = claim.read<String>('predicate').toUpperCase();
      final value =
          claim.readNullable<int>('date_value') ??
          claim.readNullable<int>('datetime_value');
      final evidence = claim.readNullable<String>('evidence_document_id');
      if (value != null && predicate.contains('EXPIR')) {
        final date = DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
        final result = _expiryResult(now.toUtc(), date);
        await _recordEvaluation(
          db,
          kind: result.kind,
          category: AttentionCategory.expiry,
          title: result.kind == LifeStateKind.expired
              ? 'An item has expired'
              : 'An item expires soon',
          explanation:
              'Confirmed Claim $predicate has date ${date.toIso8601String()}. '
              'Rule compares that date with ${now.toUtc().toIso8601String()}.',
          priority: result.kind == LifeStateKind.expired ? 10 : 30,
          dueAt: date,
          entityId: claim.read<String>('subject_entity_id'),
          claimId: claim.read<String>('id'),
          evidenceDocumentId: evidence,
          ruleId: 'claim.expiry',
          ruleVersion: '1',
          calculatedAt: calculatedAt,
          createAttention: result.kind != LifeStateKind.ok,
        );
      } else if (value != null && predicate.contains('DUE')) {
        final date = DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
        final overdue = date.isBefore(now.toUtc());
        final soon =
            !overdue && date.difference(now.toUtc()) <= const Duration(days: 7);
        final kind = overdue
            ? LifeStateKind.overdue
            : soon
            ? LifeStateKind.actionRequired
            : LifeStateKind.ok;
        await _recordEvaluation(
          db,
          kind: kind,
          category: AttentionCategory.dueBill,
          title: overdue ? 'A payment is overdue' : 'A payment is due soon',
          explanation:
              'Confirmed Claim $predicate has due date '
              '${date.toIso8601String()}. Rule uses a 7-day review window.',
          priority: overdue ? 5 : 25,
          dueAt: date,
          entityId: claim.read<String>('subject_entity_id'),
          claimId: claim.read<String>('id'),
          evidenceDocumentId: evidence,
          ruleId: 'claim.due',
          ruleVersion: '1',
          calculatedAt: calculatedAt,
          createAttention: kind != LifeStateKind.ok,
        );
      }
      if (evidence == null) {
        await _recordEvaluation(
          db,
          kind: LifeStateKind.missing,
          category: AttentionCategory.missingEvidence,
          title: 'Confirmed fact needs evidence',
          explanation:
              'Claim $predicate is confirmed but has no EvidenceLink. '
              'OwnKeep does not change the Claim; it only requests review.',
          priority: 60,
          entityId: claim.read<String>('subject_entity_id'),
          claimId: claim.read<String>('id'),
          ruleId: 'claim.evidence',
          ruleVersion: '1',
          calculatedAt: calculatedAt,
        );
      }
    }

    final events = await db
        .customSelect(
          'SELECT e.*, '
          '(SELECT x.document_id FROM event_evidence_links x '
          'WHERE x.event_id = e.id ORDER BY x.created_at LIMIT 1) '
          'AS evidence_document_id, '
          '(SELECT ee.entity_id FROM event_entities ee '
          'WHERE ee.event_id = e.id ORDER BY ee.created_at LIMIT 1) '
          'AS subject_entity_id FROM life_events e '
          "WHERE e.status = 'CONFIRMED'",
        )
        .get();
    for (final event in events) {
      final type = LifeEventType.fromStorage(
        event.read<String>('event_type'),
      );
      final start = DateTime.fromMillisecondsSinceEpoch(
        event.read<int>('start_at'),
        isUtc: true,
      );
      final endValue = event.readNullable<int>('end_at');
      final end = endValue == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endValue, isUtc: true);
      final evidence = event.readNullable<String>('evidence_document_id');
      final entityId = event.readNullable<String>('subject_entity_id');
      if (type == LifeEventType.expiry ||
          (type == LifeEventType.warranty && end != null)) {
        final date = type == LifeEventType.expiry ? start : end!;
        final result = _expiryResult(now.toUtc(), date);
        await _recordEvaluation(
          db,
          kind: result.kind,
          category: type == LifeEventType.warranty
              ? AttentionCategory.warranty
              : AttentionCategory.expiry,
          title: type == LifeEventType.warranty
              ? (result.kind == LifeStateKind.expired
                    ? 'A warranty has expired'
                    : 'A warranty expires soon')
              : (result.kind == LifeStateKind.expired
                    ? 'An event date has passed'
                    : 'An event date is approaching'),
          explanation:
              'Confirmed ${type.displayName} Event has date '
              '${date.toIso8601String()}. Rule uses a 30-day window.',
          priority: result.kind == LifeStateKind.expired ? 10 : 30,
          dueAt: date,
          entityId: entityId,
          eventId: event.read<String>('id'),
          evidenceDocumentId: evidence,
          ruleId: type == LifeEventType.warranty
              ? 'event.warranty'
              : 'event.expiry',
          ruleVersion: '1',
          calculatedAt: calculatedAt,
          createAttention: result.kind != LifeStateKind.ok,
        );
      }
      if (type == LifeEventType.service &&
          now.toUtc().difference(start) > const Duration(days: 365)) {
        await _recordEvaluation(
          db,
          kind: LifeStateKind.actionRequired,
          category: AttentionCategory.service,
          title: 'Review service history',
          explanation:
              'The latest linked Service Event is more than 365 days old. '
              'This versioned rule is organizational guidance, not a '
              'manufacturer service requirement.',
          priority: 50,
          dueAt: start.add(const Duration(days: 365)),
          entityId: entityId,
          eventId: event.read<String>('id'),
          evidenceDocumentId: evidence,
          ruleId: 'event.service-review',
          ruleVersion: '1',
          calculatedAt: calculatedAt,
        );
      }
      if (evidence == null) {
        await _recordEvaluation(
          db,
          kind: LifeStateKind.missing,
          category: AttentionCategory.missingEvidence,
          title: 'Confirmed event needs evidence',
          explanation:
              'Confirmed ${type.displayName} Event has no encrypted evidence. '
              'The Event remains unchanged until the user edits it.',
          priority: 65,
          entityId: entityId,
          eventId: event.read<String>('id'),
          ruleId: 'event.evidence',
          ruleVersion: '1',
          calculatedAt: calculatedAt,
        );
      }
    }

    final corruptDocuments = await db
        .customSelect(
          "SELECT id, logical_filename FROM documents "
          "WHERE integrity_status = 'CORRUPT' AND deleted_at IS NULL",
        )
        .get();
    for (final document in corruptDocuments) {
      await _recordEvaluation(
        db,
        kind: LifeStateKind.actionRequired,
        category: AttentionCategory.integrity,
        title: 'Record integrity check failed',
        explanation:
            '${document.read<String>('logical_filename')} failed authenticated '
            'integrity verification. Restore it only from a verified backup.',
        priority: 0,
        documentId: document.read<String>('id'),
        evidenceDocumentId: document.read<String>('id'),
        ruleId: 'document.integrity',
        ruleVersion: '1',
        calculatedAt: calculatedAt,
      );
    }

    if (inboxCount > 0) {
      await _recordEvaluation(
        db,
        kind: LifeStateKind.incomplete,
        category: AttentionCategory.inbox,
        title: '$inboxCount Inbox item${inboxCount == 1 ? '' : 's'} to review',
        explanation:
            'OwnKeep counted $inboxCount durable import or review item(s). '
            'No extracted Claim or Event is confirmed automatically.',
        priority: 40,
        ruleId: 'inbox.pending-review',
        ruleVersion: '1',
        inputFingerprint: 'inbox:$inboxCount',
        calculatedAt: calculatedAt,
      );
    }
  });

  Future<List<DerivedLifeState>> listStates({String? entityId}) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM derived_states '
              '${entityId == null ? '' : 'WHERE subject_entity_id = ? '}'
              'ORDER BY calculated_at DESC, id',
              variables: entityId == null
                  ? const []
                  : [Variable.withString(entityId)],
            )
            .get();
        return rows.map(_stateFromRow).toList(growable: false);
      });

  Future<List<AttentionItem>> listAttention({
    bool includeResolved = false,
    String? entityId,
  }) => session.read((db) async {
    final clauses = <String>[
      if (!includeResolved) "status = 'ACTIVE'",
      if (entityId != null) 'entity_id = ?',
    ];
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await db
        .customSelect(
          'SELECT * FROM attention_items $where '
          'ORDER BY priority, due_at, updated_at DESC',
          variables: entityId == null
              ? const []
              : [Variable.withString(entityId)],
        )
        .get();
    return rows.map(_attentionFromRow).toList(growable: false);
  });

  Future<void> dismissAttention(String id) => session.write(
    (db) => db.customStatement(
      "UPDATE attention_items SET status = 'DISMISSED', updated_at = ? "
      'WHERE id = ?',
      [_now, id],
    ),
  );

  Future<String> createTask({
    required String title,
    String? notes,
    DateTime? dueAt,
    String? recurrenceRule,
    String? entityId,
    String? eventId,
    String? documentId,
    String? sourceAttentionId,
    LifeTaskOrigin origin = LifeTaskOrigin.manual,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError.value(title, 'title');
    final id = await _id();
    final now = _now;
    await session.write((db) async {
      await db.customStatement(
        'INSERT INTO life_tasks(id, title, notes, origin, status, due_at, '
        'recurrence_rule, source_attention_id, entity_id, event_id, '
        'document_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          title.trim(),
          notes?.trim(),
          origin.storageValue,
          LifeTaskStatus.open.storageValue,
          dueAt?.toUtc().millisecondsSinceEpoch,
          recurrenceRule,
          sourceAttentionId,
          entityId,
          eventId,
          documentId,
          now,
          now,
        ],
      );
    });
    return id;
  }

  Future<String> createTaskFromAttention(String attentionId) async {
    final item = await session.read(
      (db) => db
          .customSelect(
            'SELECT * FROM attention_items WHERE id = ?',
            variables: [Variable.withString(attentionId)],
          )
          .getSingleOrNull(),
    );
    if (item == null) throw StateError('Unknown attention item: $attentionId');
    return createTask(
      title: item.read<String>('title'),
      notes: item.read<String>('explanation'),
      dueAt: _date(item.readNullable<int>('due_at')),
      entityId: item.readNullable<String>('entity_id'),
      eventId: item.readNullable<String>('event_id'),
      documentId:
          item.readNullable<String>('document_id') ??
          item.readNullable<String>('evidence_document_id'),
      sourceAttentionId: attentionId,
      origin: LifeTaskOrigin.generated,
    );
  }

  Future<List<LifeTask>> listTasks({bool includeClosed = false}) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM life_tasks '
              "${includeClosed ? '' : "WHERE status = 'OPEN' "}"
              'ORDER BY COALESCE(snoozed_until, due_at, 9223372036854775807), '
              'created_at DESC',
            )
            .get();
        return rows.map(_taskFromRow).toList(growable: false);
      });

  Future<void> snoozeTask(String id, DateTime until) => session.write(
    (db) => db.customStatement(
      "UPDATE life_tasks SET status = 'OPEN', snoozed_until = ?, "
      'updated_at = ? WHERE id = ?',
      [until.toUtc().millisecondsSinceEpoch, _now, id],
    ),
  );

  Future<void> rescheduleTask(String id, DateTime dueAt) => session.write(
    (db) => db.customStatement(
      "UPDATE life_tasks SET status = 'OPEN', due_at = ?, "
      'snoozed_until = NULL, updated_at = ? WHERE id = ?',
      [dueAt.toUtc().millisecondsSinceEpoch, _now, id],
    ),
  );

  Future<void> dismissTask(String id) => session.write(
    (db) => db.customStatement(
      "UPDATE life_tasks SET status = 'DISMISSED', dismissed_at = ?, "
      'updated_at = ? WHERE id = ?',
      [_now, _now, id],
    ),
  );

  Future<String?> completeTask(String id) async {
    String? nextId;
    await session.write((db) async {
      final row = await db
          .customSelect(
            'SELECT * FROM life_tasks WHERE id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      if (row == null) throw StateError('Unknown task: $id');
      final now = _now;
      await db.customStatement(
        "UPDATE life_tasks SET status = 'COMPLETED', completed_at = ?, "
        'updated_at = ? WHERE id = ?',
        [now, now, id],
      );
      final recurrence = row.readNullable<String>('recurrence_rule');
      final dueAt = _date(row.readNullable<int>('due_at'));
      if (recurrence == null || dueAt == null) return;
      final nextDue = _nextOccurrence(dueAt, recurrence);
      if (nextDue == null) return;
      nextId = await _id();
      await db.customStatement(
        'INSERT INTO life_tasks(id, title, notes, origin, status, due_at, '
        'recurrence_rule, source_attention_id, entity_id, event_id, '
        'document_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          nextId,
          row.read<String>('title'),
          row.readNullable<String>('notes'),
          row.read<String>('origin'),
          LifeTaskStatus.open.storageValue,
          nextDue.millisecondsSinceEpoch,
          recurrence,
          row.readNullable<String>('source_attention_id'),
          row.readNullable<String>('entity_id'),
          row.readNullable<String>('event_id'),
          row.readNullable<String>('document_id'),
          now,
          now,
        ],
      );
    });
    return nextId;
  }

  Future<String> createChecklist({
    required String title,
    required List<String> items,
    String? entityId,
    String? eventId,
    String? evidenceDocumentId,
  }) async {
    if (title.trim().isEmpty ||
        items.where((item) => item.trim().isNotEmpty).isEmpty) {
      throw ArgumentError('Checklist title and items are required');
    }
    final id = await _id();
    final now = _now;
    await session.write((db) async {
      await db.customStatement(
        'INSERT INTO life_checklists(id, title, entity_id, event_id, '
        'evidence_document_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [id, title.trim(), entityId, eventId, evidenceDocumentId, now, now],
      );
      var position = 0;
      for (final item
          in items
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)) {
        await db.customStatement(
          'INSERT INTO life_checklist_items(id, checklist_id, title, '
          'position) VALUES (?, ?, ?, ?)',
          [await _id(), id, item, position++],
        );
      }
    });
    return id;
  }

  Future<List<LifeChecklist>> listChecklists() => session.read((db) async {
    final checklists = await db
        .customSelect('SELECT * FROM life_checklists ORDER BY created_at DESC')
        .get();
    final result = <LifeChecklist>[];
    for (final row in checklists) {
      final itemRows = await db
          .customSelect(
            'SELECT * FROM life_checklist_items WHERE checklist_id = ? '
            'ORDER BY position',
            variables: [Variable.withString(row.read<String>('id'))],
          )
          .get();
      result.add(
        LifeChecklist(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          entityId: row.readNullable<String>('entity_id'),
          eventId: row.readNullable<String>('event_id'),
          evidenceDocumentId: row.readNullable<String>('evidence_document_id'),
          createdAt: _date(row.read<int>('created_at'))!,
          updatedAt: _date(row.read<int>('updated_at'))!,
          items: itemRows.map(_checklistItemFromRow).toList(growable: false),
        ),
      );
    }
    return result;
  });

  Future<void> setChecklistItemCompleted(String id, bool completed) =>
      session.write(
        (db) => db.customStatement(
          'UPDATE life_checklist_items SET is_completed = ?, '
          'completed_at = ? WHERE id = ?',
          [completed ? 1 : 0, completed ? _now : null, id],
        ),
      );

  Future<void> _recordEvaluation(
    dynamic db, {
    required LifeStateKind kind,
    required AttentionCategory category,
    required String title,
    required String explanation,
    required int priority,
    required String ruleId,
    required String ruleVersion,
    required int calculatedAt,
    DateTime? dueAt,
    String? entityId,
    String? claimId,
    String? eventId,
    String? documentId,
    String? evidenceDocumentId,
    String? inputFingerprint,
    bool createAttention = true,
  }) async {
    final existingState = await db
        .customSelect(
          'SELECT id FROM derived_states WHERE rule_id = ? '
          'AND COALESCE(source_claim_id, \'\') = COALESCE(?, \'\') '
          'AND COALESCE(source_event_id, \'\') = COALESCE(?, \'\') '
          'AND COALESCE(source_document_id, \'\') = COALESCE(?, \'\') '
          'AND COALESCE(subject_entity_id, \'\') = COALESCE(?, \'\') '
          'ORDER BY calculated_at DESC LIMIT 1',
          variables: [
            Variable.withString(ruleId),
            Variable<String>(claimId),
            Variable<String>(eventId),
            Variable<String>(documentId),
            Variable<String>(entityId),
          ],
        )
        .getSingleOrNull();
    final stateId =
        (existingState == null ? await _id() : existingState.read<String>('id'))
            as String;
    if (existingState == null) {
      await db.customStatement(
        'INSERT INTO derived_states(id, subject_entity_id, state_kind, '
        'rule_id, rule_version, explanation, calculated_at, source_claim_id, '
        'source_event_id, source_document_id, evidence_document_id, '
        'input_fingerprint) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          stateId,
          entityId,
          kind.storageValue,
          ruleId,
          ruleVersion,
          explanation,
          calculatedAt,
          claimId,
          eventId,
          documentId,
          evidenceDocumentId,
          inputFingerprint,
        ],
      );
    } else {
      await db.customStatement(
        'UPDATE derived_states SET state_kind = ?, rule_version = ?, '
        'explanation = ?, calculated_at = ?, evidence_document_id = ?, '
        'input_fingerprint = ? WHERE id = ?',
        [
          kind.storageValue,
          ruleVersion,
          explanation,
          calculatedAt,
          evidenceDocumentId,
          inputFingerprint,
          stateId,
        ],
      );
    }
    if (claimId != null || eventId != null || documentId != null) {
      await db.customStatement(
        'DELETE FROM state_inputs WHERE state_id = ?',
        [stateId],
      );
      await db.customStatement(
        'INSERT OR IGNORE INTO state_inputs(id, state_id, input_type, '
        'claim_id, event_id, document_id) VALUES (?, ?, ?, ?, ?, ?)',
        [
          await _id(),
          stateId,
          claimId != null
              ? 'CLAIM'
              : eventId != null
              ? 'EVENT'
              : 'DOCUMENT',
          claimId,
          eventId,
          documentId,
        ],
      );
    }
    if (!createAttention) return;
    final existingAttention = await db
        .customSelect(
          'SELECT id, status FROM attention_items WHERE state_id = ? '
          'ORDER BY created_at DESC LIMIT 1',
          variables: [Variable.withString(stateId)],
        )
        .getSingleOrNull();
    final attentionId = existingAttention?.read<String>('id') ?? await _id();
    if (existingAttention == null) {
      await db.customStatement(
        'INSERT INTO attention_items(id, state_id, category, title, '
        'explanation, priority, status, rule_id, rule_version, due_at, '
        'entity_id, claim_id, event_id, document_id, evidence_document_id, '
        'created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          attentionId,
          stateId,
          category.storageValue,
          title,
          explanation,
          priority,
          AttentionStatus.active.storageValue,
          ruleId,
          ruleVersion,
          dueAt?.toUtc().millisecondsSinceEpoch,
          entityId,
          claimId,
          eventId,
          documentId,
          evidenceDocumentId,
          calculatedAt,
          calculatedAt,
        ],
      );
    } else if (existingAttention.read<String>('status') !=
        AttentionStatus.dismissed.storageValue) {
      await db.customStatement(
        "UPDATE attention_items SET category = ?, title = ?, "
        "explanation = ?, priority = ?, status = 'ACTIVE', "
        'rule_version = ?, due_at = ?, evidence_document_id = ?, '
        'updated_at = ? WHERE id = ?',
        [
          category.storageValue,
          title,
          explanation,
          priority,
          ruleVersion,
          dueAt?.toUtc().millisecondsSinceEpoch,
          evidenceDocumentId,
          calculatedAt,
          attentionId,
        ],
      );
    }
  }

  static ({LifeStateKind kind}) _expiryResult(
    DateTime now,
    DateTime expiry,
  ) {
    if (expiry.isBefore(now)) return (kind: LifeStateKind.expired);
    if (expiry.difference(now) <= const Duration(days: 30)) {
      return (kind: LifeStateKind.expiresSoon);
    }
    return (kind: LifeStateKind.ok);
  }

  static DateTime? _nextOccurrence(DateTime dueAt, String rule) =>
      switch (rule.toUpperCase()) {
        'DAILY' => dueAt.toUtc().add(const Duration(days: 1)),
        'WEEKLY' => dueAt.toUtc().add(const Duration(days: 7)),
        'MONTHLY' => DateTime.utc(
          dueAt.year,
          dueAt.month + 1,
          dueAt.day,
          dueAt.hour,
          dueAt.minute,
        ),
        _ => null,
      };

  static DerivedLifeState _stateFromRow(QueryRow row) => DerivedLifeState(
    id: row.read<String>('id'),
    kind: LifeStateKind.fromStorage(row.read<String>('state_kind')),
    ruleId: row.read<String>('rule_id'),
    ruleVersion: row.read<String>('rule_version'),
    explanation: row.read<String>('explanation'),
    calculatedAt: _date(row.read<int>('calculated_at'))!,
    subjectEntityId: row.readNullable<String>('subject_entity_id'),
    sourceClaimId: row.readNullable<String>('source_claim_id'),
    sourceEventId: row.readNullable<String>('source_event_id'),
    sourceDocumentId: row.readNullable<String>('source_document_id'),
    evidenceDocumentId: row.readNullable<String>('evidence_document_id'),
    inputFingerprint: row.readNullable<String>('input_fingerprint'),
  );

  static AttentionItem _attentionFromRow(QueryRow row) => AttentionItem(
    id: row.read<String>('id'),
    category: AttentionCategory.fromStorage(row.read<String>('category')),
    title: row.read<String>('title'),
    explanation: row.read<String>('explanation'),
    priority: row.read<int>('priority'),
    status: AttentionStatus.fromStorage(row.read<String>('status')),
    ruleId: row.read<String>('rule_id'),
    ruleVersion: row.read<String>('rule_version'),
    stateId: row.readNullable<String>('state_id'),
    dueAt: _date(row.readNullable<int>('due_at')),
    entityId: row.readNullable<String>('entity_id'),
    claimId: row.readNullable<String>('claim_id'),
    eventId: row.readNullable<String>('event_id'),
    documentId: row.readNullable<String>('document_id'),
    evidenceDocumentId: row.readNullable<String>('evidence_document_id'),
    createdAt: _date(row.read<int>('created_at'))!,
    updatedAt: _date(row.read<int>('updated_at'))!,
  );

  static LifeTask _taskFromRow(QueryRow row) => LifeTask(
    id: row.read<String>('id'),
    title: row.read<String>('title'),
    notes: row.readNullable<String>('notes'),
    origin: LifeTaskOrigin.fromStorage(row.read<String>('origin')),
    status: LifeTaskStatus.fromStorage(row.read<String>('status')),
    dueAt: _date(row.readNullable<int>('due_at')),
    recurrenceRule: row.readNullable<String>('recurrence_rule'),
    snoozedUntil: _date(row.readNullable<int>('snoozed_until')),
    completedAt: _date(row.readNullable<int>('completed_at')),
    dismissedAt: _date(row.readNullable<int>('dismissed_at')),
    sourceAttentionId: row.readNullable<String>('source_attention_id'),
    entityId: row.readNullable<String>('entity_id'),
    eventId: row.readNullable<String>('event_id'),
    documentId: row.readNullable<String>('document_id'),
    createdAt: _date(row.read<int>('created_at'))!,
    updatedAt: _date(row.read<int>('updated_at'))!,
  );

  static LifeChecklistItem _checklistItemFromRow(QueryRow row) =>
      LifeChecklistItem(
        id: row.read<String>('id'),
        checklistId: row.read<String>('checklist_id'),
        title: row.read<String>('title'),
        position: row.read<int>('position'),
        isCompleted: row.read<int>('is_completed') == 1,
        completedAt: _date(row.readNullable<int>('completed_at')),
      );

  Future<String> _id() async =>
      base64UrlEncode(await random.secureBytes(24)).replaceAll('=', '');

  static DateTime? _date(int? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

  static int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;
}
