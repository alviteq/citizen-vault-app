// SQL assertions are kept readable against the graph schema.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_domain/vault_domain.dart' as domain;

final class _TestRandom implements CryptographicRandom {
  var _sequence = 0;

  @override
  Future<Uint8List> secureBytes(int length) async {
    final sequence = _sequence++;
    return Uint8List.fromList(
      List<int>.generate(
        length,
        (index) => switch (index) {
          0 => sequence & 0xff,
          1 => (sequence >> 8) & 0xff,
          2 => (sequence >> 16) & 0xff,
          3 => (sequence >> 24) & 0xff,
          _ => (index * 37 + sequence) & 0xff,
        },
      ),
    );
  }
}

void main() {
  test('Life Graph preserves typed claims and review state', () async {
    final directory = Directory.systemTemp.createTempSync('life_graph_');
    final key = SecretBytes(List<int>.generate(32, (index) => index + 1));
    VaultDatabaseSession? session;
    try {
      session = await EncryptedDatabaseOpener.open(
        file: File('${directory.path}/vault.db'),
        databaseKey: key,
        runInBackground: false,
      );
      final graph = SqlCipherLifeGraphRepository(session, _TestRandom());
      final vehicle = await graph.createEntity(
        type: domain.LifeEntityType.vehicle,
        displayName: 'Family Car',
      );
      final duplicateVehicle = await graph.createEntity(
        type: domain.LifeEntityType.vehicle,
        displayName: ' Family Car ',
      );
      expect(
        await graph.duplicateCandidates(
          type: domain.LifeEntityType.vehicle,
          displayName: 'family car',
          excludingId: vehicle,
        ),
        hasLength(1),
      );
      await graph.updateEntity(
        entityId: duplicateVehicle,
        displayName: 'Second Car',
        subtype: 'Hatchback',
      );
      await graph.setEntityArchived(duplicateVehicle, true);
      expect(
        (await graph.entity(duplicateVehicle))?.status,
        domain.LifeEntityStatus.archived,
      );
      expect(await graph.listEntities(), hasLength(1));
      await graph.setEntityArchived(duplicateVehicle, false);
      expect(await graph.listEntities(), hasLength(2));
      await graph.upsertEntityAttribute(
        entityId: vehicle,
        key: 'NOTES',
        value: const domain.ClaimValue.string('Primary family vehicle'),
      );
      expect(
        (await graph.entityAttributes(vehicle)).single.value.stringValue,
        'Primary family vehicle',
      );
      await graph.mergeEntities(
        primaryEntityId: vehicle,
        duplicateEntityId: duplicateVehicle,
      );
      expect(
        (await graph.entity(duplicateVehicle))?.status,
        domain.LifeEntityStatus.archived,
      );
      final mergedAttributes = await graph.entityAttributes(duplicateVehicle);
      expect(
        mergedAttributes
            .singleWhere(
              (attribute) => attribute.key == 'MERGED_INTO',
            )
            .value
            .stringValue,
        vehicle,
      );
      expect(
        (await graph.entityHistory(vehicle)).map((event) => event.eventType),
        contains('ENTITY_MERGED_FROM'),
      );
      await session.write(
        (db) => db.customStatement(
          'INSERT INTO documents(id, logical_filename, mime_type, source_type, '
          'status, primary_object_id, plaintext_sha256, plaintext_size, '
          'encrypted_size, imported_at, updated_at, integrity_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            'insurance-document',
            'insurance.pdf',
            'application/pdf',
            'FILE',
            'READY',
            'object-1',
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
        sourceType: domain.ProvenanceSourceType.ocrExtracted,
        sourceDocumentId: 'insurance-document',
        extractorId: 'test-ocr',
        extractorVersion: '1',
        confidence: .94,
        confidenceSource: 'OCR',
      );
      final registration = await graph.suggestClaim(
        subjectEntityId: vehicle,
        predicate: 'VEHICLE_REGISTRATION_NUMBER',
        value: const domain.ClaimValue.identifier('AP05AB1234'),
        cardinality: domain.ClaimCardinality.singleCurrent,
        provenanceId: provenance,
      );
      final expiry = await graph.suggestClaim(
        subjectEntityId: vehicle,
        predicate: 'INSURANCE_EXPIRY',
        value: domain.ClaimValue.date(DateTime.utc(2027, 8, 12)),
        cardinality: domain.ClaimCardinality.singleCurrent,
        provenanceId: provenance,
      );
      await graph.addEvidence(
        documentId: 'insurance-document',
        claimId: registration,
        pageNumber: 1,
        boundingPolygonJson: '[0.1,0.2,0.3,0.4]',
        textFragmentHash: 'registration-fragment',
        provenanceId: provenance,
      );
      expect(await graph.evidenceForEntity(vehicle), hasLength(1));
      expect(await graph.claimsForEntity(vehicle), hasLength(2));
      await graph.setClaimStatus(registration, domain.ClaimStatus.confirmed);
      await graph.setClaimStatus(expiry, domain.ClaimStatus.rejected);
      final current = await graph.currentClaims(vehicle);
      expect(current, hasLength(1));
      expect(current.single.read<String>('identifier_value'), 'AP05AB1234');
      final replacementRegistration = await graph.suggestClaim(
        subjectEntityId: vehicle,
        predicate: 'VEHICLE_REGISTRATION_NUMBER',
        value: const domain.ClaimValue.identifier('AP05XY9999'),
        cardinality: domain.ClaimCardinality.singleCurrent,
        provenanceId: provenance,
      );
      await graph.setClaimStatus(
        replacementRegistration,
        domain.ClaimStatus.confirmed,
      );
      final registrationHistory = await graph.claimsForEntity(vehicle);
      expect(
        registrationHistory
            .singleWhere((claim) => claim.id == registration)
            .status,
        domain.ClaimStatus.superseded,
      );
      expect(
        registrationHistory
            .singleWhere((claim) => claim.id == replacementRegistration)
            .supersedesId,
        registration,
      );

      final policy = await graph.createEntity(
        type: domain.LifeEntityType.policy,
        displayName: 'Car Insurance',
      );
      final relationship = await graph.suggestRelationship(
        fromEntityId: policy,
        toEntityId: vehicle,
        type: domain.LifeRelationshipType.covers,
        provenanceId: provenance,
        validFrom: DateTime.utc(2026),
        validUntil: DateTime.utc(2027, 8, 12),
      );
      final row = await session.read(
        (db) => db
            .customSelect(
              'SELECT relationship_type, status FROM relationships WHERE id = ?',
              variables: [Variable.withString(relationship)],
            )
            .getSingle(),
      );
      expect(row.read<String>('relationship_type'), 'COVERS');
      expect(row.read<String>('status'), 'SUGGESTED');
      await graph.setRelationshipStatus(
        relationship,
        domain.ClaimStatus.confirmed,
      );
      final history = await session.read(
        (db) => db
            .customSelect(
              'SELECT event_type FROM relationship_history WHERE relationship_id = ?',
              variables: [Variable.withString(relationship)],
            )
            .get(),
      );
      expect(
        history.map((item) => item.read<String>('event_type')),
        containsAll(['SUGGESTED', 'CONFIRMED']),
      );
      expect(await graph.relationshipsForEntity(vehicle), hasLength(1));

      final eventSpecs =
          <
            (
              domain.LifeEventType,
              String,
              DateTime,
              int,
            )
          >[
            (
              domain.LifeEventType.purchase,
              'Vehicle purchased',
              DateTime.utc(2025, 1, 10),
              180000000,
            ),
            (
              domain.LifeEventType.payment,
              'Insurance premium paid',
              DateTime.utc(2025, 6),
              120000,
            ),
            (
              domain.LifeEventType.service,
              'Vehicle serviced',
              DateTime.utc(2025, 7, 15),
              85000,
            ),
            (
              domain.LifeEventType.renewal,
              'Insurance renewed',
              DateTime.utc(2025, 8, 12),
              125000,
            ),
          ];
      final eventIds = <String>[];
      for (final spec in eventSpecs) {
        final eventId = await graph.suggestEvent(
          type: spec.$1,
          title: spec.$2,
          startAt: spec.$3,
          amountMinorUnits: spec.$4,
          currency: 'INR',
          entityRoles: {vehicle: 'SUBJECT'},
          provenanceId: provenance,
        );
        await graph.addEventEvidence(
          eventId: eventId,
          documentId: 'insurance-document',
          pageNumber: 1,
          boundingPolygonJson: '[0.1,0.2,0.3,0.4]',
          provenanceId: provenance,
        );
        await graph.setEventStatus(
          eventId,
          domain.LifeEventStatus.confirmed,
        );
        eventIds.add(eventId);
      }
      final timeline = await graph.listEvents(entityId: vehicle);
      expect(timeline.map((event) => event.type), [
        domain.LifeEventType.renewal,
        domain.LifeEventType.service,
        domain.LifeEventType.payment,
        domain.LifeEventType.purchase,
      ]);
      expect(await graph.eventEvidence(eventIds.first), hasLength(1));
      expect(await graph.eventEntityLinks(eventIds.first), hasLength(1));

      final correctedPayment = await graph.correctEvent(
        eventId: eventIds[1],
        type: domain.LifeEventType.payment,
        title: 'Corrected insurance premium',
        startAt: DateTime.utc(2025, 6, 2),
        amountMinorUnits: 130000,
        currency: 'INR',
        provenanceId: provenance,
      );
      final fullHistory = await graph.listEvents(
        entityId: vehicle,
        includeHistorical: true,
      );
      expect(
        fullHistory.singleWhere((event) => event.id == eventIds[1]).status,
        domain.LifeEventStatus.superseded,
      );
      expect(
        fullHistory.singleWhere((event) => event.id == correctedPayment),
        isA<domain.LifeEvent>()
            .having(
              (event) => event.supersedesId,
              'supersedesId',
              eventIds[1],
            )
            .having(
              (event) => event.amountMinorUnits,
              'amountMinorUnits',
              130000,
            ),
      );
      expect(await graph.eventEvidence(correctedPayment), hasLength(1));
      expect(
        (await graph.eventHistory(eventIds[1])).last.eventType,
        domain.LifeEventStatus.superseded.storageValue,
      );
      final totals = await graph.expenseTotals(
        from: DateTime.utc(2025),
        until: DateTime.utc(2026),
        entityId: vehicle,
      );
      expect(totals.single.currency, 'INR');
      expect(
        totals.single.amountMinorUnits,
        180000000 + 130000 + 85000 + 125000,
      );
    } finally {
      await session?.close();
      key.destroy();
      directory.deleteSync(recursive: true);
    }
  });
}
