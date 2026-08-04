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
        (index) => (sequence * 29 + index * 13) & 0xff,
      ),
    );
  }
}

void main() {
  test('versioned Smart Packs guide without mutating graph facts', () async {
    expect(
      domain.OrganizingPackRegistry.templates.map((item) => item.kind).toSet(),
      domain.OrganizingTemplateKind.values.toSet(),
    );
    expect(
      domain.OrganizingPackRegistry.presets.map((item) => item.type),
      containsAll(<domain.SmartPackType>[
        domain.SmartPackType.vehicle,
        domain.SmartPackType.home,
        domain.SmartPackType.travel,
        domain.SmartPackType.health,
        domain.SmartPackType.education,
        domain.SmartPackType.emergency,
      ]),
    );

    final directory = Directory.systemTemp.createTempSync('smart_pack_');
    final key = SecretBytes(List<int>.generate(32, (index) => index + 3));
    VaultDatabaseSession? session;
    try {
      session = await EncryptedDatabaseOpener.open(
        file: File('${directory.path}/vault.db'),
        databaseKey: key,
        runInBackground: false,
      );
      final random = _UniqueRandom();
      final graph = SqlCipherLifeGraphRepository(session, random);
      final tasks = SqlCipherAttentionRepository(session, random);
      final packs = SqlCipherSmartPackRepository(session, random);
      final vehicle = await graph.createEntity(
        type: domain.LifeEntityType.vehicle,
        displayName: 'Family Car',
      );
      await session.write(
        (db) => db.customStatement(
          'INSERT INTO documents(id, logical_filename, document_type, '
          'mime_type, source_type, status, primary_object_id, '
          'plaintext_sha256, plaintext_size, encrypted_size, imported_at, '
          'updated_at, integrity_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            'vehicle-document',
            'registration.pdf',
            'VEHICLE_DOCUMENT',
            'application/pdf',
            'FILE',
            'READY',
            'object-vehicle',
            Uint8List(32),
            1,
            1,
            1,
            1,
            'VERIFIED',
          ],
        ),
      );
      final provenance = await graph.createProvenance(
        sourceType: domain.ProvenanceSourceType.userEntered,
        sourceDocumentId: 'vehicle-document',
        confidence: 1,
        confidenceSource: 'USER',
      );
      final registration = await graph.suggestClaim(
        subjectEntityId: vehicle,
        predicate: 'VEHICLE_REGISTRATION_NUMBER',
        value: const domain.ClaimValue.identifier('AP05AB1234'),
        cardinality: domain.ClaimCardinality.singleCurrent,
        provenanceId: provenance,
      );
      await graph.setClaimStatus(registration, domain.ClaimStatus.confirmed);
      await graph.addEvidence(
        documentId: 'vehicle-document',
        claimId: registration,
        provenanceId: provenance,
      );
      final service = await graph.suggestEvent(
        type: domain.LifeEventType.service,
        title: 'Annual service',
        startAt: DateTime.utc(2026, 6),
        entityRoles: {vehicle: 'SUBJECT'},
        provenanceId: provenance,
      );
      await graph.setEventStatus(service, domain.LifeEventStatus.confirmed);
      final task = await tasks.createTask(
        title: 'Renew insurance',
        entityId: vehicle,
      );

      final factsBefore = await _graphFacts(session);
      final packId = await packs.createFromPreset(
        presetId: 'preset.vehicle',
        entityId: vehicle,
        includeIndiaPack: true,
      );
      var pack = (await packs.pack(packId))!;
      expect(pack.templateId, 'preset.vehicle');
      expect(pack.templateVersion, 1);
      expect(pack.countryCode, 'IN');
      expect(pack.guidanceDisclaimer, contains('not legal'));
      expect(
        pack.items
            .singleWhere((item) => item.key.endsWith(':registration'))
            .isSatisfied,
        isTrue,
      );
      expect(
        pack.items
            .singleWhere((item) => item.key.endsWith(':service'))
            .isSatisfied,
        isTrue,
      );
      expect(
        pack.items.any((item) => item.label.contains('Driving licence')),
        isTrue,
      );

      final insurance = pack.items.singleWhere(
        (item) => item.key.endsWith(':insurance'),
      );
      await packs.customizeItem(
        itemId: insurance.id,
        label: 'My chosen policy evidence',
        isEnabled: true,
        isOptional: true,
        includeInExport: true,
      );
      await packs.linkItem(itemId: insurance.id, taskId: task);
      pack = (await packs.pack(packId))!;
      expect(
        pack.items.singleWhere((item) => item.id == insurance.id).isSatisfied,
        isFalse,
      );
      await tasks.completeTask(task);
      pack = (await packs.pack(packId))!;
      expect(
        pack.items.singleWhere((item) => item.id == insurance.id).isSatisfied,
        isTrue,
      );
      expect(
        pack.items.singleWhere((item) => item.id == insurance.id).label,
        'My chosen policy evidence',
      );
      expect(await _graphFacts(session), factsBefore);

      final registrationItem = pack.items.singleWhere(
        (item) => item.key.endsWith(':registration'),
      );
      await packs.customizeItem(
        itemId: registrationItem.id,
        label: registrationItem.label,
        isEnabled: true,
        isOptional: false,
        includeInExport: true,
      );
      expect(await packs.exportDocumentIds(packId), ['vehicle-document']);

      final customId = await packs.createCustom(
        title: 'Moving day',
        itemLabels: const ['Keys', 'Meter reading'],
        entityId: vehicle,
      );
      await packs.addCustomItem(packId: customId, label: 'Address update');
      final custom = (await packs.pack(customId))!;
      expect(custom.type, domain.SmartPackType.custom);
      expect(custom.items, hasLength(3));
      await packs.setArchived(customId, true);
      expect(
        (await packs.listPacks()).map((item) => item.id),
        isNot(contains(customId)),
      );
    } finally {
      await session?.close();
      key.destroy();
      directory.deleteSync(recursive: true);
    }
  });
}

Future<List<Map<String, Object?>>> _graphFacts(
  VaultDatabaseSession session,
) => session.read((db) async {
  final rows = await db
      .customSelect(
        'SELECT id, subject_entity_id, predicate, status, confirmed_at '
        'FROM claims ORDER BY id',
      )
      .get();
  return rows.map((row) => row.data).toList(growable: false);
});
