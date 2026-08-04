import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_domain/vault_domain.dart' as domain;

final class _UniqueRandom implements CryptographicRandom {
  var _sequence = 0;

  @override
  Future<Uint8List> secureBytes(int length) async {
    final sequence = _sequence++;
    return Uint8List.fromList(
      List<int>.generate(
        length,
        (index) => (sequence * 31 + index * 17) & 0xff,
      ),
    );
  }
}

void main() {
  test('State, Attention, Tasks and Checklists remain explainable', () async {
    final directory = Directory.systemTemp.createTempSync('attention_');
    final key = SecretBytes(List<int>.generate(32, (index) => index + 1));
    VaultDatabaseSession? session;
    try {
      session = await EncryptedDatabaseOpener.open(
        file: File('${directory.path}/vault.db'),
        databaseKey: key,
        runInBackground: false,
      );
      final random = _UniqueRandom();
      final graph = SqlCipherLifeGraphRepository(session, random);
      final attention = SqlCipherAttentionRepository(session, random);
      final vehicle = await graph.createEntity(
        type: domain.LifeEntityType.vehicle,
        displayName: 'Family Car',
      );
      final unknownProfile = await graph.createEntity(
        type: domain.LifeEntityType.person,
        displayName: 'New Person',
      );
      final incompleteProfile = await graph.createEntity(
        type: domain.LifeEntityType.property,
        displayName: 'New Property',
      );
      await session.write((db) async {
        for (final values in <List<Object>>[
          [
            'insurance-document',
            'insurance.pdf',
            'VERIFIED',
          ],
          [
            'corrupt-document',
            'damaged.pdf',
            'CORRUPT',
          ],
        ]) {
          await db.customStatement(
            'INSERT INTO documents(id, logical_filename, mime_type, '
            'source_type, status, primary_object_id, plaintext_sha256, '
            'plaintext_size, encrypted_size, imported_at, updated_at, '
            'integrity_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              values[0],
              values[1],
              'application/pdf',
              'FILE',
              'READY',
              'object-${values[0]}',
              Uint8List(32),
              1,
              1,
              1,
              1,
              values[2],
            ],
          );
        }
      });
      final provenance = await graph.createProvenance(
        sourceType: domain.ProvenanceSourceType.documentExtracted,
        sourceDocumentId: 'insurance-document',
        extractorId: 'test',
        extractorVersion: '1',
        confidence: 1,
        confidenceSource: 'USER',
      );
      final now = DateTime.utc(2026, 7, 26, 12);
      final expiry = await graph.suggestClaim(
        subjectEntityId: vehicle,
        predicate: 'INSURANCE_EXPIRY',
        value: domain.ClaimValue.date(DateTime.utc(2026, 8, 5)),
        cardinality: domain.ClaimCardinality.singleCurrent,
        provenanceId: provenance,
      );
      await graph.addEvidence(
        documentId: 'insurance-document',
        claimId: expiry,
        provenanceId: provenance,
      );
      await graph.setClaimStatus(expiry, domain.ClaimStatus.confirmed);
      await graph.suggestClaim(
        subjectEntityId: incompleteProfile,
        predicate: 'PROPERTY_REFERENCE',
        value: const domain.ClaimValue.string('Needs review'),
        cardinality: domain.ClaimCardinality.singleCurrent,
        provenanceId: provenance,
      );
      final due = await graph.suggestClaim(
        subjectEntityId: vehicle,
        predicate: 'PAYMENT_DUE',
        value: domain.ClaimValue.date(DateTime.utc(2026, 7, 25)),
        cardinality: domain.ClaimCardinality.singleCurrent,
        provenanceId: provenance,
      );
      await graph.setClaimStatus(due, domain.ClaimStatus.confirmed);
      final service = await graph.suggestEvent(
        type: domain.LifeEventType.service,
        title: 'Vehicle serviced',
        startAt: DateTime.utc(2025),
        entityRoles: {vehicle: 'SUBJECT'},
        provenanceId: provenance,
      );
      await graph.addEventEvidence(
        eventId: service,
        documentId: 'insurance-document',
        provenanceId: provenance,
      );
      await graph.setEventStatus(service, domain.LifeEventStatus.confirmed);
      final warranty = await graph.suggestEvent(
        type: domain.LifeEventType.warranty,
        title: 'Vehicle warranty',
        startAt: DateTime.utc(2025),
        endAt: DateTime.utc(2026, 8, 10),
        entityRoles: {vehicle: 'SUBJECT'},
        provenanceId: provenance,
      );
      await graph.addEventEvidence(
        eventId: warranty,
        documentId: 'insurance-document',
        provenanceId: provenance,
      );
      await graph.setEventStatus(warranty, domain.LifeEventStatus.confirmed);

      await attention.recalculate(now: now, inboxCount: 2);
      final first = await attention.listAttention();
      expect(
        first.map((item) => item.category),
        containsAll(<domain.AttentionCategory>[
          domain.AttentionCategory.integrity,
          domain.AttentionCategory.dueBill,
          domain.AttentionCategory.expiry,
          domain.AttentionCategory.missingEvidence,
          domain.AttentionCategory.service,
          domain.AttentionCategory.warranty,
          domain.AttentionCategory.inbox,
        ]),
      );
      expect(
        first,
        everyElement(
          isA<domain.AttentionItem>()
              .having((item) => item.ruleVersion, 'ruleVersion', '1')
              .having(
                (item) => item.explanation,
                'explanation',
                isNotEmpty,
              ),
        ),
      );
      final ids = first.map((item) => item.id).toSet();
      await attention.recalculate(now: now, inboxCount: 2);
      expect(
        (await attention.listAttention()).map((item) => item.id).toSet(),
        ids,
      );
      final states = await attention.listStates();
      expect(
        states
            .singleWhere(
              (state) =>
                  state.subjectEntityId == unknownProfile &&
                  state.ruleId == 'entity.completeness',
            )
            .kind,
        domain.LifeStateKind.unknown,
      );
      expect(
        states
            .singleWhere(
              (state) =>
                  state.subjectEntityId == incompleteProfile &&
                  state.ruleId == 'entity.completeness',
            )
            .kind,
        domain.LifeStateKind.incomplete,
      );
      expect(
        states
            .singleWhere(
              (state) =>
                  state.subjectEntityId == vehicle &&
                  state.ruleId == 'entity.completeness',
            )
            .kind,
        domain.LifeStateKind.ok,
      );

      final expiryAttention = first.singleWhere(
        (item) =>
            item.category == domain.AttentionCategory.expiry &&
            item.claimId != null,
      );
      expect(expiryAttention.evidenceDocumentId, 'insurance-document');
      await attention.dismissAttention(expiryAttention.id);
      await attention.recalculate(now: now, inboxCount: 2);
      expect(
        (await attention.listAttention()).map((item) => item.id),
        isNot(contains(expiryAttention.id)),
      );
      await attention.createTaskFromAttention(expiryAttention.id);
      final recurring = await attention.createTask(
        title: 'Review vehicle',
        dueAt: DateTime.utc(2026, 7, 27),
        recurrenceRule: 'DAILY',
        entityId: vehicle,
      );
      await attention.snoozeTask(recurring, DateTime.utc(2026, 7, 28));
      await attention.rescheduleTask(recurring, DateTime.utc(2026, 7, 29));
      final next = await attention.completeTask(recurring);
      expect(next, isNotNull);
      final tasks = await attention.listTasks(includeClosed: true);
      expect(
        tasks.where((task) => task.origin == domain.LifeTaskOrigin.generated),
        hasLength(1),
      );
      expect(
        tasks.singleWhere((task) => task.id == recurring).status,
        domain.LifeTaskStatus.completed,
      );
      expect(
        tasks.singleWhere((task) => task.id == next).dueAt,
        DateTime.utc(2026, 7, 30),
      );

      final checklist = await attention.createChecklist(
        title: 'Vehicle renewal',
        items: const ['Check policy', 'Confirm payment'],
        entityId: vehicle,
        eventId: warranty,
        evidenceDocumentId: 'insurance-document',
      );
      final list = await attention.listChecklists();
      expect(list.single.id, checklist);
      expect(list.single.items, hasLength(2));
      await attention.setChecklistItemCompleted(
        list.single.items.first.id,
        true,
      );
      expect(
        (await attention.listChecklists()).single.items.first.isCompleted,
        isTrue,
      );
    } finally {
      await session?.close();
      key.destroy();
      directory.deleteSync(recursive: true);
    }
  });
}
