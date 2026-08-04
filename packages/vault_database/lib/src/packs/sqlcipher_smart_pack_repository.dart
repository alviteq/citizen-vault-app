// SQL is intentionally visible for auditability of pack completeness.
// ignore_for_file: public_member_api_docs
// ignore_for_file: always_use_package_imports, avoid_positional_boolean_parameters
// ignore_for_file: prefer_if_elements_to_conditional_expressions
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_domain/vault_domain.dart';

import '../database/citizen_vault_database.dart' hide SmartPack, SmartPackItem;
import '../database/encrypted_database_opener.dart';

final class SqlCipherSmartPackRepository {
  SqlCipherSmartPackRepository(this.session, this.random);

  final VaultDatabaseSession session;
  final CryptographicRandom random;

  Future<String> createFromPreset({
    required String presetId,
    String? title,
    String? entityId,
    bool includeIndiaPack = false,
  }) async {
    final preset = OrganizingPackRegistry.preset(presetId);
    final id = await _id();
    final now = _now;
    final definitions =
        <({String templateId, int version, PackItemDefinition item})>[];
    for (final templateId in preset.templateIds) {
      final template = OrganizingPackRegistry.template(templateId);
      for (final item in template.items) {
        definitions.add((
          templateId: template.id,
          version: template.version,
          item: item,
        ));
      }
      if (includeIndiaPack) {
        for (final countryItem in OrganizingPackRegistry.india.items.where(
          (item) => item.templateId == templateId,
        )) {
          definitions.add((
            templateId: template.id,
            version: template.version,
            item: countryItem.item,
          ));
        }
      }
    }
    await session.write((db) async {
      await db.customStatement(
        'INSERT INTO smart_packs(id, title, pack_type, template_id, '
        'template_version, country_pack_id, country_pack_version, '
        'country_code, entity_id, guidance_disclaimer, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          title?.trim().isNotEmpty == true ? title!.trim() : preset.title,
          preset.type.storageValue,
          preset.id,
          preset.version,
          includeIndiaPack ? OrganizingPackRegistry.india.id : null,
          includeIndiaPack ? OrganizingPackRegistry.india.version : null,
          includeIndiaPack ? OrganizingPackRegistry.india.countryCode : null,
          entityId,
          includeIndiaPack
              ? '${OrganizingPackRegistry.guidanceDisclaimer} '
                    '${OrganizingPackRegistry.india.disclaimer}'
              : OrganizingPackRegistry.guidanceDisclaimer,
          now,
          now,
        ],
      );
      var position = 0;
      for (final definition in definitions) {
        await _insertItem(
          db,
          packId: id,
          key: '${definition.templateId}:${definition.item.key}',
          definition: definition.item,
          position: position++,
          sourceTemplateId: definition.templateId,
          sourceTemplateVersion: definition.version,
          now: now,
        );
      }
    });
    return id;
  }

  Future<String> createCustom({
    required String title,
    required List<String> itemLabels,
    String? entityId,
  }) async {
    final labels = itemLabels
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    if (title.trim().isEmpty || labels.isEmpty) {
      throw ArgumentError('A custom pack needs a title and at least one item.');
    }
    final id = await _id();
    final now = _now;
    await session.write((db) async {
      await db.customStatement(
        'INSERT INTO smart_packs(id, title, pack_type, template_id, '
        'template_version, entity_id, guidance_disclaimer, created_at, '
        'updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          title.trim(),
          SmartPackType.custom.storageValue,
          'custom',
          1,
          entityId,
          OrganizingPackRegistry.guidanceDisclaimer,
          now,
          now,
        ],
      );
      for (var position = 0; position < labels.length; position++) {
        await _insertItem(
          db,
          packId: id,
          key: 'custom-${position + 1}',
          definition: PackItemDefinition(
            key: 'custom-${position + 1}',
            label: labels[position],
            guidance:
                'A user-created organizational item. Mark it not applicable '
                'or link supporting information when useful.',
            isOptional: true,
          ),
          position: position,
          now: now,
        );
      }
    });
    return id;
  }

  Future<String> addCustomItem({
    required String packId,
    required String label,
    String? guidance,
  }) async {
    if (label.trim().isEmpty) throw ArgumentError.value(label, 'label');
    final id = await _id();
    await session.write((db) async {
      final positionRow = await db
          .customSelect(
            'SELECT COALESCE(MAX(position), -1) + 1 AS next_position '
            'FROM smart_pack_items WHERE pack_id = ?',
            variables: [Variable.withString(packId)],
          )
          .getSingle();
      final now = _now;
      await db.customStatement(
        'INSERT INTO smart_pack_items(id, pack_id, item_key, label, guidance, '
        'position, is_optional, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)',
        [
          id,
          packId,
          'custom-$id',
          label.trim(),
          guidance?.trim().isNotEmpty == true
              ? guidance!.trim()
              : 'A user-created organizational item.',
          positionRow.read<int>('next_position'),
          now,
          now,
        ],
      );
      await _touchPack(db, packId, now);
    });
    return id;
  }

  Future<void> customizeItem({
    required String itemId,
    required String label,
    required bool isEnabled,
    required bool isOptional,
    required bool includeInExport,
  }) => session.write((db) async {
    if (label.trim().isEmpty) throw ArgumentError.value(label, 'label');
    final now = _now;
    final row = await db
        .customSelect(
          'SELECT pack_id FROM smart_pack_items WHERE id = ?',
          variables: [Variable.withString(itemId)],
        )
        .getSingle();
    await db.customStatement(
      'UPDATE smart_pack_items SET label = ?, is_enabled = ?, '
      'is_optional = ?, include_in_export = ?, updated_at = ? WHERE id = ?',
      [
        label.trim(),
        isEnabled ? 1 : 0,
        isOptional ? 1 : 0,
        includeInExport ? 1 : 0,
        now,
        itemId,
      ],
    );
    await _touchPack(db, row.read<String>('pack_id'), now);
  });

  Future<void> linkItem({
    required String itemId,
    String? claimId,
    String? eventId,
    String? documentId,
    String? taskId,
  }) => session.write((db) async {
    final now = _now;
    final row = await db
        .customSelect(
          'SELECT pack_id FROM smart_pack_items WHERE id = ?',
          variables: [Variable.withString(itemId)],
        )
        .getSingle();
    await db.customStatement(
      'UPDATE smart_pack_items SET linked_claim_id = ?, linked_event_id = ?, '
      'linked_document_id = ?, linked_task_id = ?, updated_at = ? '
      'WHERE id = ?',
      [claimId, eventId, documentId, taskId, now, itemId],
    );
    await _touchPack(db, row.read<String>('pack_id'), now);
  });

  Future<void> setArchived(String packId, bool archived) => session.write(
    (db) => db.customStatement(
      'UPDATE smart_packs SET is_archived = ?, updated_at = ? WHERE id = ?',
      [archived ? 1 : 0, _now, packId],
    ),
  );

  Future<List<SmartPack>> listPacks({bool includeArchived = false}) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM smart_packs '
              '${includeArchived ? '' : 'WHERE is_archived = 0 '}'
              'ORDER BY updated_at DESC, id',
            )
            .get();
        final result = <SmartPack>[];
        for (final row in rows) {
          result.add(await _packFromRow(db, row));
        }
        return result;
      });

  Future<SmartPack?> pack(String packId) => session.read((db) async {
    final row = await db
        .customSelect(
          'SELECT * FROM smart_packs WHERE id = ?',
          variables: [Variable.withString(packId)],
        )
        .getSingleOrNull();
    return row == null ? null : _packFromRow(db, row);
  });

  Future<List<String>> exportDocumentIds(String packId) => session.read((
    db,
  ) async {
    final packRow = await db
        .customSelect(
          'SELECT entity_id FROM smart_packs WHERE id = ?',
          variables: [Variable.withString(packId)],
        )
        .getSingle();
    final entityId = packRow.readNullable<String>('entity_id');
    final rows = await db
        .customSelect(
          'SELECT * FROM smart_pack_items WHERE pack_id = ? '
          'AND is_enabled = 1 AND include_in_export = 1',
          variables: [Variable.withString(packId)],
        )
        .get();
    final ids = <String>{};
    for (final row in rows) {
      final linked = row.readNullable<String>('linked_document_id');
      if (linked != null) ids.add(linked);
      final claimId = row.readNullable<String>('linked_claim_id');
      if (claimId != null) {
        final evidence = await db
            .customSelect(
              'SELECT document_id FROM evidence_links WHERE claim_id = ?',
              variables: [Variable.withString(claimId)],
            )
            .get();
        ids.addAll(evidence.map((item) => item.read<String>('document_id')));
      }
      final eventId = row.readNullable<String>('linked_event_id');
      if (eventId != null) {
        final evidence = await db
            .customSelect(
              'SELECT document_id FROM event_evidence_links '
              'WHERE event_id = ?',
              variables: [Variable.withString(eventId)],
            )
            .get();
        ids.addAll(evidence.map((item) => item.read<String>('document_id')));
      }
      final documentType = row.readNullable<String>('document_type');
      if (documentType != null) {
        final documents = await _matchingDocuments(
          db,
          documentType,
          entityId,
        );
        ids.addAll(
          documents.map((item) => item.read<String>('id')),
        );
      }
    }
    return ids.toList(growable: false)..sort();
  });

  Future<SmartPack> _packFromRow(
    CitizenVaultDatabase db,
    QueryRow row,
  ) async {
    final itemRows = await db
        .customSelect(
          'SELECT * FROM smart_pack_items WHERE pack_id = ? ORDER BY position',
          variables: [Variable.withString(row.read<String>('id'))],
        )
        .get();
    final entityId = row.readNullable<String>('entity_id');
    final items = <SmartPackItem>[];
    for (final item in itemRows) {
      items.add(
        SmartPackItem(
          id: item.read<String>('id'),
          key: item.read<String>('item_key'),
          label: item.read<String>('label'),
          guidance: item.read<String>('guidance'),
          position: item.read<int>('position'),
          isOptional: item.read<int>('is_optional') == 1,
          isEnabled: item.read<int>('is_enabled') == 1,
          includeInExport: item.read<int>('include_in_export') == 1,
          isSatisfied: await _isSatisfied(db, item, entityId),
          claimPredicate: item.readNullable<String>('claim_predicate'),
          eventType: item.readNullable<String>('event_type'),
          documentType: item.readNullable<String>('document_type'),
          linkedClaimId: item.readNullable<String>('linked_claim_id'),
          linkedEventId: item.readNullable<String>('linked_event_id'),
          linkedDocumentId: item.readNullable<String>('linked_document_id'),
          linkedTaskId: item.readNullable<String>('linked_task_id'),
        ),
      );
    }
    return SmartPack(
      id: row.read<String>('id'),
      title: row.read<String>('title'),
      type: SmartPackType.fromStorage(row.read<String>('pack_type')),
      templateId: row.read<String>('template_id'),
      templateVersion: row.read<int>('template_version'),
      countryCode: row.readNullable<String>('country_code'),
      entityId: entityId,
      guidanceDisclaimer: row.read<String>('guidance_disclaimer'),
      isArchived: row.read<int>('is_archived') == 1,
      items: items,
      createdAt: _date(row.read<int>('created_at')),
      updatedAt: _date(row.read<int>('updated_at')),
    );
  }

  Future<bool> _isSatisfied(
    CitizenVaultDatabase db,
    QueryRow item,
    String? entityId,
  ) async {
    if (item.read<int>('is_enabled') == 0) return false;
    final linkedClaim = item.readNullable<String>('linked_claim_id');
    if (linkedClaim != null &&
        await _rowExists(
          db,
          "SELECT 1 FROM claims WHERE id = ? AND status = 'CONFIRMED'",
          linkedClaim,
        )) {
      return true;
    }
    final linkedEvent = item.readNullable<String>('linked_event_id');
    if (linkedEvent != null &&
        await _rowExists(
          db,
          "SELECT 1 FROM life_events WHERE id = ? AND status = 'CONFIRMED'",
          linkedEvent,
        )) {
      return true;
    }
    final linkedDocument = item.readNullable<String>('linked_document_id');
    if (linkedDocument != null &&
        await _rowExists(
          db,
          'SELECT 1 FROM documents WHERE id = ? AND deleted_at IS NULL '
          'AND is_archived = 0',
          linkedDocument,
        )) {
      return true;
    }
    final linkedTask = item.readNullable<String>('linked_task_id');
    if (linkedTask != null &&
        await _rowExists(
          db,
          "SELECT 1 FROM life_tasks WHERE id = ? AND status = 'COMPLETED'",
          linkedTask,
        )) {
      return true;
    }
    final predicate = item.readNullable<String>('claim_predicate');
    if (predicate != null) {
      final claim = await db
          .customSelect(
            'SELECT 1 FROM claims WHERE predicate = ? AND status = '
            "'CONFIRMED' ${entityId == null ? '' : 'AND subject_entity_id = ? '}"
            'LIMIT 1',
            variables: [
              Variable.withString(predicate),
              if (entityId != null) Variable.withString(entityId),
            ],
          )
          .getSingleOrNull();
      if (claim != null) return true;
    }
    final eventType = item.readNullable<String>('event_type');
    if (eventType != null) {
      final event = await db
          .customSelect(
            'SELECT 1 FROM life_events e WHERE e.event_type = ? '
            "AND e.status = 'CONFIRMED' "
            '${entityId == null ? '' : 'AND EXISTS (SELECT 1 FROM event_entities x WHERE x.event_id = e.id AND x.entity_id = ?) '}'
            'LIMIT 1',
            variables: [
              Variable.withString(eventType),
              if (entityId != null) Variable.withString(entityId),
            ],
          )
          .getSingleOrNull();
      if (event != null) return true;
    }
    final documentType = item.readNullable<String>('document_type');
    return documentType != null &&
        (await _matchingDocuments(db, documentType, entityId)).isNotEmpty;
  }

  Future<List<QueryRow>> _matchingDocuments(
    CitizenVaultDatabase db,
    String documentType,
    String? entityId,
  ) => db
      .customSelect(
        'SELECT d.id FROM documents d WHERE d.document_type = ? '
        'AND d.deleted_at IS NULL AND d.is_archived = 0 '
        '${entityId == null ? '' : '''
AND (
  EXISTS (
    SELECT 1 FROM evidence_links el
    JOIN claims c ON c.id = el.claim_id
    WHERE el.document_id = d.id AND c.subject_entity_id = ?
      AND c.status = 'CONFIRMED'
  )
  OR EXISTS (
    SELECT 1 FROM event_evidence_links eel
    JOIN event_entities ee ON ee.event_id = eel.event_id
    WHERE eel.document_id = d.id AND ee.entity_id = ?
  )
) '''}'
        'ORDER BY d.imported_at DESC',
        variables: [
          Variable.withString(documentType),
          if (entityId != null) Variable.withString(entityId),
          if (entityId != null) Variable.withString(entityId),
        ],
      )
      .get();

  static Future<bool> _rowExists(
    CitizenVaultDatabase db,
    String sql,
    String id,
  ) async =>
      (await db
          .customSelect(
            sql,
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull()) !=
      null;

  Future<void> _insertItem(
    CitizenVaultDatabase db, {
    required String packId,
    required String key,
    required PackItemDefinition definition,
    required int position,
    required int now,
    String? sourceTemplateId,
    int? sourceTemplateVersion,
  }) async {
    await db.customStatement(
      'INSERT INTO smart_pack_items(id, pack_id, item_key, label, guidance, '
      'position, source_template_id, source_template_version, '
      'claim_predicate, event_type, document_type, is_optional, '
      'include_in_export, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        await _id(),
        packId,
        key,
        definition.label,
        definition.guidance,
        position,
        sourceTemplateId,
        sourceTemplateVersion,
        definition.claimPredicate,
        definition.eventType,
        definition.documentType,
        definition.isOptional ? 1 : 0,
        definition.includeInExport ? 1 : 0,
        now,
        now,
      ],
    );
  }

  static Future<void> _touchPack(
    CitizenVaultDatabase db,
    String packId,
    int now,
  ) => db.customStatement(
    'UPDATE smart_packs SET updated_at = ? WHERE id = ?',
    [now, packId],
  );

  Future<String> _id() async =>
      base64UrlEncode(await random.secureBytes(24)).replaceAll('=', '');

  static DateTime _date(int value) =>
      DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

  static int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;
}
