import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_backup/vault_backup.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_objects/vault_objects.dart';

void main() {
  const passphrase = 'correct horse battery staple citizen vault';
  final objectId = ObjectId.parse('00000000000000000000000001');
  final secondObjectId = ObjectId.parse('00000000000000000000000002');
  late Directory fixtureRoot;
  late File archive;
  late Map<String, List<Map<String, Object?>>> expectedGraphRows;

  setUpAll(() async {
    fixtureRoot = Directory.systemTemp.createTempSync('vault_backup_fixture_');
    archive = File('${fixtureRoot.path}/portable.cvault');
    final source = Directory('${fixtureRoot.path}/source')..createSync();
    final masterKey = SecretBytes(List<int>.generate(32, (index) => index));
    final vaultSalt = List<int>.generate(32, (index) => 0x20 + index);
    final derived = await VaultKeyHierarchy().deriveAll(
      masterKey: masterKey,
      vaultSalt: vaultSalt,
    );
    final databaseKey = SecretBytes(
      derived[VaultSubkeyContext.database].extractBytes(),
    );
    final fileRootBytes = derived[VaultSubkeyContext.fileRoot].extractBytes();
    final fileRootKey = VaultFileRootKey.fromBytes(
      fileRootBytes,
      keyVersion: 1,
    );
    fileRootBytes.fillRange(0, fileRootBytes.length, 0);
    final session = await EncryptedDatabaseOpener.open(
      file: File('${source.path}/vault.db'),
      databaseKey: databaseKey,
      runInBackground: false,
    );
    databaseKey.destroy();
    final random = _DeterministicRandom();
    final objectStore = FileEncryptedObjectStore(
      rootDirectory: source,
      random: random,
      retentionRepository: DatabaseObjectRetentionRepository(session),
    );
    final documentObject = await objectStore.put(
      plaintext: _generatedStream(5 * 1024 * 1024 + 17),
      objectId: objectId,
      fileRootKey: fileRootKey,
    );
    await objectStore.put(
      plaintext: Stream<List<int>>.value(_patternBytes(17)),
      objectId: secondObjectId,
      fileRootKey: fileRootKey,
      chunkSize: 64 * 1024,
    );
    await session.write((database) async {
      await database.customStatement(
        'UPDATE object_references SET reference_count = 1',
      );
      await database.customStatement(
        'INSERT INTO pipeline_versions(version, configuration_sha256, '
        'is_active, created_at) VALUES (1, ?, 1, 1)',
        <Object>['fixture'],
      );
      await _seedLifeGraph(database, documentObject);
    });
    expectedGraphRows = await _captureLifeGraph(session);
    final backup = VaultBackupService(
      session: session,
      snapshots: SqlCipherDatabaseSnapshotService(session),
      objectRootDirectory: source,
      random: random,
    );
    final result = await backup.create(
      VaultBackupRequest(
        generationId: BackupGenerationId('generation-1'),
        vaultId: 'vault-fixture-1',
        outputFile: archive,
        workingDirectory: Directory('${fixtureRoot.path}/working'),
        masterKey: masterKey,
        vaultHkdfSalt: vaultSalt,
        recoveryPassphrase: passphrase,
        kdfParameters: const RecoveryKdfParameters.productionPbkdf2Fallback(),
      ),
    );
    expect(result.objectCount, 2);
    await session.close();
    fileRootKey.destroy();
    derived.destroy();
    masterKey.destroy();
    source.deleteSync(recursive: true);
  });

  tearDownAll(() {
    fixtureRoot.deleteSync(recursive: true);
  });

  test('restores a wiped vault using only archive and passphrase', () async {
    final vaults = Directory('${fixtureRoot.path}/restore-clean');
    final provisioner = _RecordingProvisioner();
    final random = _DeterministicRandom();
    final restore = BackupRestoreService(
      archiveVerifier: VaultBackupArchiveVerifier(random: random),
      capacityPolicy: const _AllowStorage(),
      provisioner: provisioner,
      randomSource: random,
    );

    final result = await restore.restore(
      archive: archive,
      recoveryPassphrase: passphrase,
      vaultsParent: vaults,
    );

    expect(result.vaultId, 'vault-fixture-1');
    expect(result.objectCount, 2);
    expect(result.previousDirectory, isNull);
    expect(
      File('${result.activeDirectory.path}/vault.db').existsSync(),
      isTrue,
    );
    expect(
      File(
        '${result.activeDirectory.path}/objects/${objectId.value}.bin',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${result.activeDirectory.path}/objects/${secondObjectId.value}.bin',
      ).existsSync(),
      isTrue,
    );
    expect(provisioner.provisionedVaultId, 'vault-fixture-1');
  });

  test('Life Graph survives backup, wipe, and restore exactly', () async {
    final vaults = Directory('${fixtureRoot.path}/restore-life-graph');
    final restore = BackupRestoreService(
      archiveVerifier: VaultBackupArchiveVerifier(
        random: _DeterministicRandom(),
      ),
      capacityPolicy: const _AllowStorage(),
      provisioner: _RecordingProvisioner(),
      randomSource: _DeterministicRandom(),
    );
    final restored = await restore.restore(
      archive: archive,
      recoveryPassphrase: passphrase,
      vaultsParent: vaults,
    );
    final masterKey = SecretBytes(List<int>.generate(32, (index) => index));
    final salt = List<int>.generate(32, (index) => 0x20 + index);
    final keys = await VaultKeyHierarchy().deriveAll(
      masterKey: masterKey,
      vaultSalt: salt,
    );
    final databaseKey = SecretBytes(
      keys[VaultSubkeyContext.database].extractBytes(),
    );
    VaultDatabaseSession? restoredSession;
    try {
      restoredSession = await EncryptedDatabaseOpener.open(
        file: File('${restored.activeDirectory.path}/vault.db'),
        databaseKey: databaseKey,
        runInBackground: false,
      );
      expect(await _captureLifeGraph(restoredSession), expectedGraphRows);
    } finally {
      await restoredSession?.close();
      databaseKey.destroy();
      keys.destroy();
      masterKey.destroy();
      salt.fillRange(0, salt.length, 0);
    }
  });

  test('creates and verifies an empty-vault archive', () async {
    final empty = await _createEmptyVaultArchive(
      fixtureRoot,
      passphrase,
    );
    final unlocked = await VaultBackupArchiveVerifier(
      random: _DeterministicRandom(),
    ).unlockAndVerify(archive: empty, recoveryPassphrase: passphrase);
    try {
      expect(unlocked.manifest.objects, isEmpty);
    } finally {
      unlocked.destroy();
    }
  });

  test(
    'wrong passphrase returns only generic authentication failure',
    () async {
      final verifier = VaultBackupArchiveVerifier(
        random: _DeterministicRandom(),
      );
      await expectLater(
        verifier.unlockAndVerify(
          archive: archive,
          recoveryPassphrase: 'this passphrase is definitely wrong',
        ),
        throwsA(
          isA<BackupAuthenticationFailure>().having(
            (failure) => failure.toString(),
            'safe text',
            'BackupFailure(backup_authentication_failed)',
          ),
        ),
      );
    },
  );

  test('tampered public header is rejected', () async {
    final copy = archive.copySync('${fixtureRoot.path}/tampered-header.cvault');
    final reader = CvaultArchiveReader(copy);
    final header = (await reader.inspect()).first;
    await _flipByte(copy, header.dataOffset + 3);
    await expectLater(
      VaultBackupArchiveVerifier(
        random: _DeterministicRandom(),
      ).unlockAndVerify(archive: copy, recoveryPassphrase: passphrase),
      throwsA(isA<BackupFailure>()),
    );
  });

  test('modified encrypted manifest is rejected', () async {
    final copy = archive.copySync(
      '${fixtureRoot.path}/tampered-manifest.cvault',
    );
    final manifest = (await CvaultArchiveReader(copy).inspect())[2];
    await _flipByte(copy, manifest.dataOffset + 10);
    await expectLater(
      VaultBackupArchiveVerifier(
        random: _DeterministicRandom(),
      ).unlockAndVerify(archive: copy, recoveryPassphrase: passphrase),
      throwsA(isA<BackupVerificationFailure>()),
    );
  });

  test('missing manifest entry is rejected', () async {
    final copy = archive.copySync(
      '${fixtureRoot.path}/missing-manifest.cvault',
    );
    final manifest = (await CvaultArchiveReader(copy).inspect())[2];
    final nameOffset = manifest.dataOffset - 40 - manifest.name.length;
    await _flipByte(copy, nameOffset);
    await expectLater(
      CvaultArchiveReader(copy).inspect(),
      throwsA(isA<InvalidBackupFormatFailure>()),
    );
  });

  test('modified database snapshot is rejected', () async {
    final copy = archive.copySync(
      '${fixtureRoot.path}/tampered-snapshot.cvault',
    );
    final snapshot = (await CvaultArchiveReader(copy).inspect())[3];
    await _flipByte(copy, snapshot.dataOffset + 100);
    await expectLater(
      CvaultArchiveReader(copy).inspect(),
      throwsA(isA<BackupVerificationFailure>()),
    );
  });

  test('truncated archive is rejected and cannot be marked complete', () async {
    final copy = archive.copySync('${fixtureRoot.path}/truncated.cvault');
    copy.openSync(mode: FileMode.append)
      ..truncateSync(copy.lengthSync() - 100)
      ..closeSync();
    await expectLater(
      CvaultArchiveReader(copy).inspect(),
      throwsA(isA<InvalidBackupFormatFailure>()),
    );
  });

  test('entry-count policy is enforced before extraction', () async {
    const restrictive = VaultImportPolicy(maximumArchiveEntries: 4);
    await expectLater(
      CvaultArchiveReader(archive, policy: restrictive).inspect(),
      throwsA(isA<InvalidBackupFormatFailure>()),
    );
  });

  test('ZIP-slip style names are rejected by the writer', () async {
    final byte = await CvaultEntrySource.bytes('header.cbor', <int>[1]);
    await expectLater(
      CvaultArchiveWriter.write(
        File('${fixtureRoot.path}/zip-slip.cvault'),
        <CvaultEntrySource>[
          byte,
          await CvaultEntrySource.bytes(
            'recovery-envelope.cbor',
            <int>[1],
          ),
          await CvaultEntrySource.bytes('encrypted-manifest.bin', <int>[1]),
          await CvaultEntrySource.bytes('database/snapshot.bin', <int>[1]),
          await CvaultEntrySource.bytes('objects/../escape.bin', <int>[1]),
        ],
      ),
      throwsA(isA<InvalidBackupFormatFailure>()),
    );
  });

  test('unexpected but well-formed object entry is rejected', () async {
    final infos = await CvaultArchiveReader(archive).inspect();
    final output = File('${fixtureRoot.path}/unexpected-entry.cvault');
    await CvaultArchiveWriter.write(
      output,
      <CvaultEntrySource>[
        for (final info in infos) _sourceFromArchive(archive, info),
        await CvaultEntrySource.bytes(
          'objects/00000000000000000000000003.bin',
          <int>[1],
        ),
      ],
    );
    await expectLater(
      VaultBackupArchiveVerifier(
        random: _DeterministicRandom(),
      ).unlockAndVerify(archive: output, recoveryPassphrase: passphrase),
      throwsA(isA<BackupVerificationFailure>()),
    );
  });

  test('duplicated archive entry names are rejected', () async {
    final infos = await CvaultArchiveReader(archive).inspect();
    final sources = <CvaultEntrySource>[
      for (final info in infos) _sourceFromArchive(archive, info),
      _sourceFromArchive(archive, infos.last),
    ];
    await expectLater(
      CvaultArchiveWriter.write(
        File('${fixtureRoot.path}/duplicate-entry.cvault'),
        sources,
      ),
      throwsA(isA<InvalidBackupFormatFailure>()),
    );
  });

  test(
    'compressed ZIP containers are rejected instead of decompressed',
    () async {
      final zip = File('${fixtureRoot.path}/not-supported.zip')
        ..writeAsBytesSync(<int>[0x50, 0x4B, 0x03, 0x04]);
      await expectLater(
        CvaultArchiveReader(zip).inspect(),
        throwsA(isA<InvalidBackupFormatFailure>()),
      );
    },
  );

  test(
    'object deleted after inventory fails without publishing archive',
    () async {
      final result = await _attemptBackupWithMissingInventoriedObject(
        fixtureRoot,
        passphrase,
      );
      expect(result.failure, isA<BackupCreationFailure>());
      expect(result.output.existsSync(), isFalse);
      expect(File('${result.output.path}.partial').existsSync(), isFalse);
    },
  );

  test('insufficient storage leaves active vault untouched', () async {
    final vaults = Directory('${fixtureRoot.path}/restore-no-space')
      ..createSync();
    final active = Directory('${vaults.path}/active_vault')..createSync();
    File('${active.path}/sentinel').writeAsStringSync('old-vault');
    final restore = BackupRestoreService(
      archiveVerifier: VaultBackupArchiveVerifier(
        random: _DeterministicRandom(),
      ),
      capacityPolicy: const _RejectStorage(),
      provisioner: _RecordingProvisioner(),
      randomSource: _DeterministicRandom(),
    );

    await expectLater(
      restore.restore(
        archive: archive,
        recoveryPassphrase: passphrase,
        vaultsParent: vaults,
      ),
      throwsA(isA<InsufficientRestoreStorageFailure>()),
    );
    expect(File('${active.path}/sentinel').readAsStringSync(), 'old-vault');
    expect(
      vaults.listSync().where((entry) => entry.path.contains('.restore-')),
      isEmpty,
    );
  });

  test(
    'device provisioning failure cleans staging and preserves active',
    () async {
      final vaults = Directory('${fixtureRoot.path}/restore-provision-fails')
        ..createSync();
      final active = Directory('${vaults.path}/active_vault')..createSync();
      File('${active.path}/sentinel').writeAsStringSync('old-vault');
      final restore = BackupRestoreService(
        archiveVerifier: VaultBackupArchiveVerifier(
          random: _DeterministicRandom(),
        ),
        capacityPolicy: const _AllowStorage(),
        provisioner: const _FailingProvisioner(),
        randomSource: _DeterministicRandom(),
      );

      await expectLater(
        restore.restore(
          archive: archive,
          recoveryPassphrase: passphrase,
          vaultsParent: vaults,
        ),
        throwsA(isA<BackupRestoreFailure>()),
      );
      expect(File('${active.path}/sentinel').readAsStringSync(), 'old-vault');
      expect(
        vaults.listSync().where((entry) => entry.path.contains('.restore-')),
        isEmpty,
      );
    },
  );

  test('unsafe KDF and future header versions fail before derivation', () {
    final unsafe = BackupPublicHeader(
      kdfParameters: const RecoveryKdfParameters(
        algorithm: RecoveryKdfAlgorithm.argon2id,
        iterations: 2,
        memoryKiB: 300 * 1024,
        parallelism: 1,
      ),
      kdfSalt: List<int>.filled(16, 1),
    );
    expect(
      () => BackupPublicHeaderCodec.decode(
        BackupPublicHeaderCodec.encode(unsafe),
      ),
      throwsA(isA<BackupFailure>()),
    );

    final supported = BackupPublicHeader(
      kdfParameters: const RecoveryKdfParameters.productionPbkdf2Fallback(),
      kdfSalt: List<int>.filled(16, 1),
    );
    final future = BackupPublicHeaderCodec.encode(supported);
    future[22] = 2;
    expect(
      () => BackupPublicHeaderCodec.decode(future),
      throwsA(isA<UnsupportedBackupVersionFailure>()),
    );
  });
}

Future<void> _seedLifeGraph(
  CitizenVaultDatabase database,
  EncryptedObjectWriteResult object,
) async {
  const time = 1784203200000;
  await database.customStatement(
    'INSERT INTO documents(id, logical_filename, document_type, mime_type, '
    'source_type, status, primary_object_id, plaintext_sha256, plaintext_size, '
    'encrypted_size, imported_at, updated_at, integrity_status) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object>[
      'insurance-document',
      'insurance.pdf',
      'INSURANCE',
      'application/pdf',
      'FILE',
      'READY',
      object.objectId.value,
      object.plaintextSha256,
      object.plaintextSize,
      object.encryptedSize,
      time,
      time,
      'VERIFIED',
    ],
  );
  await database.customStatement(
    'INSERT INTO entities(id, entity_type, display_name, status, created_at, '
    'updated_at) VALUES '
    "('vehicle-1', 'VEHICLE', 'My Car', 'ACTIVE', ?, ?), "
    "('vehicle-duplicate', 'VEHICLE', 'My Car', 'ARCHIVED', ?, ?), "
    "('policy-1', 'POLICY', 'Car Insurance', 'ACTIVE', ?, ?)",
    <Object>[time, time, time, time, time, time],
  );
  await database.customStatement(
    'INSERT INTO entity_attributes(id, entity_id, attribute_key, value_type, '
    'string_value, entity_reference_id, created_at, updated_at) VALUES '
    "('attribute-notes', 'vehicle-1', 'NOTES', 'STRING', "
    "'Primary family vehicle', NULL, ?, ?), "
    "('attribute-merge', 'vehicle-duplicate', 'MERGED_INTO', "
    "'ENTITY_REFERENCE', NULL, 'vehicle-1', ?, ?)",
    <Object>[time, time, time, time],
  );
  await database.customStatement(
    'INSERT INTO provenance_records(id, source_type, source_document_id, '
    'extractor_id, extractor_version, confidence, confidence_source, '
    "created_at) VALUES ('provenance-1', 'OCR_EXTRACTED', "
    "'insurance-document', 'insurance-extractor', '1', 0.94, 'OCR', ?)",
    <Object>[time],
  );
  await database.customStatement(
    'INSERT INTO claims(id, subject_entity_id, predicate, value_type, status, '
    'cardinality, provenance_id, created_at, updated_at, confirmed_at, '
    'rejected_at) VALUES '
    "('claim-registration', 'vehicle-1', 'VEHICLE_REGISTRATION_NUMBER', "
    "'IDENTIFIER', 'CONFIRMED', 'SINGLE_CURRENT', 'provenance-1', "
    '?, ?, ?, NULL), '
    "('claim-insurer', 'policy-1', 'INSURER_NAME', 'STRING', 'CONFIRMED', "
    "'SINGLE_CURRENT', 'provenance-1', ?, ?, ?, NULL), "
    "('claim-expiry', 'policy-1', 'INSURANCE_EXPIRY', 'DATE', 'REJECTED', "
    "'SINGLE_CURRENT', 'provenance-1', ?, ?, NULL, ?)",
    <Object>[time, time, time, time, time, time, time, time, time],
  );
  await database.customStatement(
    'INSERT INTO claim_values(id, claim_id, identifier_value) VALUES '
    "('value-registration', 'claim-registration', 'AP05AB1234')",
  );
  await database.customStatement(
    'INSERT INTO claim_values(id, claim_id, string_value) VALUES '
    "('value-insurer', 'claim-insurer', 'ICICI')",
  );
  await database.customStatement(
    'INSERT INTO claim_values(id, claim_id, date_value) VALUES '
    "('value-expiry', 'claim-expiry', 1818028800000)",
  );
  for (final entry in <String, String>{
    'claim-registration': 'CONFIRMED',
    'claim-insurer': 'CONFIRMED',
    'claim-expiry': 'REJECTED',
  }.entries) {
    await database.customStatement(
      'INSERT INTO claim_history(id, claim_id, event_type, provenance_id, '
      'created_at) VALUES (?, ?, ?, ?, ?)',
      <Object>[
        'history-${entry.key}',
        entry.key,
        entry.value,
        'provenance-1',
        time,
      ],
    );
  }
  await database.customStatement(
    'INSERT INTO relationships(id, from_entity_id, to_entity_id, '
    'relationship_type, status, provenance_id, created_at, updated_at, '
    "confirmed_at) VALUES ('relationship-1', 'policy-1', 'vehicle-1', "
    "'COVERS', 'CONFIRMED', 'provenance-1', ?, ?, ?)",
    <Object>[time, time, time],
  );
  await database.customStatement(
    'INSERT INTO relationship_history(id, relationship_id, event_type, '
    "provenance_id, created_at) VALUES ('relationship-history-1', "
    "'relationship-1', 'CONFIRMED', 'provenance-1', ?)",
    <Object>[time],
  );
  await database.customStatement(
    'INSERT INTO evidence_links(id, document_id, claim_id, evidence_role, '
    'page_number, bounding_polygon_json, text_fragment_hash, provenance_id, '
    "created_at) VALUES ('evidence-1', 'insurance-document', "
    "'claim-registration', 'SOURCE', 1, '[0.1,0.2,0.3,0.4]', ?, "
    "'provenance-1', ?)",
    <Object>[Uint8List.fromList(List<int>.filled(32, 7)), time],
  );
  await database.customStatement(
    'INSERT INTO life_events(id, event_type, title, start_at, status, '
    'amount_minor, currency, supersedes_id, provenance_id, created_at, '
    'updated_at, confirmed_at) VALUES '
    "('event-purchase', 'PURCHASE', 'Vehicle purchased', 1736467200000, "
    "'CONFIRMED', 180000000, 'INR', NULL, 'provenance-1', ?, ?, ?), "
    "('event-payment-old', 'PAYMENT', 'Premium entered incorrectly', "
    "1748736000000, 'SUPERSEDED', 120000, 'INR', NULL, 'provenance-1', "
    '?, ?, ?), '
    "('event-payment', 'PAYMENT', 'Insurance premium paid', 1748822400000, "
    "'CONFIRMED', 130000, 'INR', 'event-payment-old', 'provenance-1', "
    '?, ?, ?), '
    "('event-service', 'SERVICE', 'Vehicle serviced', 1752537600000, "
    "'CONFIRMED', 85000, 'INR', NULL, 'provenance-1', ?, ?, ?), "
    "('event-renewal', 'RENEWAL', 'Insurance renewed', 1754956800000, "
    "'CONFIRMED', 125000, 'INR', NULL, 'provenance-1', ?, ?, ?)",
    <Object>[
      time,
      time,
      time,
      time,
      time,
      time,
      time,
      time,
      time,
      time,
      time,
      time,
      time,
      time,
      time,
    ],
  );
  for (final eventId in <String>[
    'event-purchase',
    'event-payment-old',
    'event-payment',
    'event-service',
    'event-renewal',
  ]) {
    final isSuperseded = eventId == 'event-payment-old';
    final historyEventType = isSuperseded ? 'SUPERSEDED' : 'CONFIRMED';
    final previousStatus = isSuperseded ? 'CONFIRMED' : 'SUGGESTED';
    await database.customStatement(
      'INSERT INTO event_entities(id, event_id, entity_id, role, created_at) '
      'VALUES (?, ?, ?, ?, ?)',
      <Object>[
        'entity-link-$eventId',
        eventId,
        'vehicle-1',
        'SUBJECT',
        time,
      ],
    );
    await database.customStatement(
      'INSERT INTO event_evidence_links(id, event_id, document_id, '
      'evidence_role, page_number, bounding_polygon_json, '
      'text_fragment_hash, provenance_id, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object>[
        'event-evidence-$eventId',
        eventId,
        'insurance-document',
        'SOURCE',
        1,
        '[0.1,0.2,0.3,0.4]',
        Uint8List.fromList(List<int>.filled(32, 9)),
        'provenance-1',
        time,
      ],
    );
    await database.customStatement(
      'INSERT INTO event_history(id, event_id, event_type, previous_status, '
      'provenance_id, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      <Object>[
        'event-history-$eventId',
        eventId,
        historyEventType,
        previousStatus,
        'provenance-1',
        time,
      ],
    );
  }
  await database.customStatement(
    'INSERT INTO derived_states(id, subject_entity_id, state_kind, rule_id, '
    'rule_version, explanation, calculated_at, source_event_id, '
    'evidence_document_id, input_fingerprint) VALUES '
    "('state-expiry', 'vehicle-1', 'EXPIRES_SOON', 'event.expiry', '1', "
    "'Confirmed event is inside the 30-day window.', ?, 'event-renewal', "
    "'insurance-document', 'event-renewal:1818028800000')",
    <Object>[time],
  );
  await database.customStatement(
    'INSERT INTO state_inputs(id, state_id, input_type, event_id) VALUES '
    "('state-input-expiry', 'state-expiry', 'EVENT', 'event-renewal')",
  );
  await database.customStatement(
    'INSERT INTO attention_items(id, state_id, category, title, explanation, '
    'priority, status, rule_id, rule_version, due_at, entity_id, claim_id, '
    'event_id, evidence_document_id, created_at, updated_at) VALUES '
    "('attention-expiry', 'state-expiry', 'EXPIRY', 'Insurance expires soon', "
    "'Confirmed event is inside the 30-day window.', 30, 'ACTIVE', "
    "'event.expiry', '1', 1818028800000, 'vehicle-1', NULL, 'event-renewal', "
    "'insurance-document', ?, ?)",
    <Object>[time, time],
  );
  await database.customStatement(
    'INSERT INTO life_tasks(id, title, notes, origin, status, due_at, '
    'recurrence_rule, source_attention_id, entity_id, document_id, '
    'created_at, updated_at) VALUES '
    "('task-renewal', 'Renew insurance', 'Generated from expiry attention', "
    "'GENERATED', 'OPEN', 1818028800000, 'YEARLY', 'attention-expiry', "
    "'vehicle-1', 'insurance-document', ?, ?)",
    <Object>[time, time],
  );
  await database.customStatement(
    'INSERT INTO life_checklists(id, title, entity_id, event_id, '
    'evidence_document_id, created_at, updated_at) VALUES '
    "('checklist-renewal', 'Renewal checklist', 'vehicle-1', "
    "'event-renewal', 'insurance-document', ?, ?)",
    <Object>[time, time],
  );
  await database.customStatement(
    'INSERT INTO life_checklist_items(id, checklist_id, title, position, '
    'is_completed, completed_at) VALUES '
    "('checklist-item-1', 'checklist-renewal', 'Compare policy', 0, 1, ?), "
    "('checklist-item-2', 'checklist-renewal', 'Confirm payment', 1, 0, NULL)",
    <Object>[time],
  );
  await database.customStatement(
    'INSERT INTO smart_packs(id, title, pack_type, template_id, '
    'template_version, country_pack_id, country_pack_version, country_code, '
    'entity_id, guidance_disclaimer, created_at, updated_at) VALUES '
    "('pack-vehicle', 'Vehicle Pack', 'VEHICLE', 'preset.vehicle', 1, "
    "'country.in', 1, 'IN', 'vehicle-1', 'Guidance only; not a legal "
    "requirement.', ?, ?)",
    <Object>[time, time],
  );
  await database.customStatement(
    'INSERT INTO smart_pack_items(id, pack_id, item_key, label, guidance, '
    'position, source_template_id, source_template_version, claim_predicate, '
    'document_type, is_optional, is_enabled, include_in_export, '
    'linked_claim_id, linked_event_id, linked_document_id, linked_task_id, '
    'created_at, updated_at) VALUES '
    "('pack-item-registration', 'pack-vehicle', 'core.vehicle:registration', "
    "'Registration details', 'Organizational guidance.', 0, 'core.vehicle', "
    "1, 'VEHICLE_REGISTRATION_NUMBER', 'VEHICLE_DOCUMENT', 0, 1, 1, "
    "'claim-registration', 'event-renewal', 'insurance-document', "
    "'task-renewal', ?, ?)",
    <Object>[time, time],
  );
  await database.customStatement(
    'INSERT INTO graph_audit_events(id, event_type, subject_type, subject_id, '
    'payload_json, event_hash, created_at) VALUES '
    "('audit-merge-primary', 'ENTITY_MERGED_FROM', 'ENTITY', 'vehicle-1', "
    "'{\"duplicate_entity_id\":\"vehicle-duplicate\"}', ?, ?), "
    "('audit-merge-duplicate', 'ENTITY_MERGED_INTO', 'ENTITY', "
    "'vehicle-duplicate', '{\"primary_entity_id\":\"vehicle-1\"}', ?, ?)",
    <Object>[Uint8List(32), time, Uint8List(32), time],
  );
}

Future<Map<String, List<Map<String, Object?>>>> _captureLifeGraph(
  VaultDatabaseSession session,
) async {
  const queries = <String, String>{
    'entities': 'SELECT * FROM entities ORDER BY id',
    'entity_attributes': 'SELECT * FROM entity_attributes ORDER BY id',
    'provenance_records': 'SELECT * FROM provenance_records ORDER BY id',
    'claims': 'SELECT * FROM claims ORDER BY id',
    'claim_values': 'SELECT * FROM claim_values ORDER BY id',
    'claim_history': 'SELECT * FROM claim_history ORDER BY id',
    'relationships': 'SELECT * FROM relationships ORDER BY id',
    'relationship_history': 'SELECT * FROM relationship_history ORDER BY id',
    'life_events': 'SELECT * FROM life_events ORDER BY id',
    'event_entities': 'SELECT * FROM event_entities ORDER BY id',
    'event_evidence_links':
        'SELECT id, event_id, document_id, asset_id, evidence_role, '
        'page_number, bounding_polygon_json, '
        'hex(text_fragment_hash) AS text_fragment_hash_hex, provenance_id, '
        'created_at FROM event_evidence_links ORDER BY id',
    'event_history': 'SELECT * FROM event_history ORDER BY id',
    'derived_states': 'SELECT * FROM derived_states ORDER BY id',
    'state_inputs': 'SELECT * FROM state_inputs ORDER BY id',
    'attention_items': 'SELECT * FROM attention_items ORDER BY id',
    'life_tasks': 'SELECT * FROM life_tasks ORDER BY id',
    'life_checklists': 'SELECT * FROM life_checklists ORDER BY id',
    'life_checklist_items': 'SELECT * FROM life_checklist_items ORDER BY id',
    'smart_packs': 'SELECT * FROM smart_packs ORDER BY id',
    'smart_pack_items': 'SELECT * FROM smart_pack_items ORDER BY id',
    'evidence_links':
        'SELECT id, document_id, asset_id, claim_id, relationship_id, '
        'evidence_role, page_number, bounding_polygon_json, '
        'hex(text_fragment_hash) AS text_fragment_hash_hex, provenance_id, '
        'created_at FROM evidence_links ORDER BY id',
    'graph_audit_events':
        'SELECT id, event_type, subject_type, subject_id, payload_json, '
        'hex(previous_event_hash) AS previous_event_hash_hex, '
        'hex(event_hash) AS event_hash_hex, created_at '
        'FROM graph_audit_events ORDER BY id',
  };
  return session.read((database) async {
    final result = <String, List<Map<String, Object?>>>{};
    for (final entry in queries.entries) {
      final rows = await database.customSelect(entry.value).get();
      result[entry.key] = rows
          .map((row) => Map<String, Object?>.from(row.data))
          .toList(growable: false);
    }
    return result;
  });
}

Future<void> _flipByte(File file, int offset) async {
  final writer = await file.open(mode: FileMode.append);
  try {
    await writer.setPosition(offset);
    final value = await writer.readByte();
    await writer.setPosition(offset);
    await writer.writeByte(value ^ 1);
    await writer.flush();
  } finally {
    await writer.close();
  }
}

Uint8List _patternBytes(int length) => Uint8List.fromList(
  List<int>.generate(length, (index) => (index * 17 + 3) & 0xFF),
);

Stream<List<int>> _generatedStream(int length) async* {
  const segmentSize = 8191;
  var offset = 0;
  while (offset < length) {
    final count = length - offset < segmentSize ? length - offset : segmentSize;
    yield Uint8List.fromList(
      List<int>.generate(count, (index) => ((offset + index) * 17 + 3) & 0xFF),
    );
    offset += count;
  }
}

CvaultEntrySource _sourceFromArchive(
  File archive,
  CvaultArchiveEntryInfo info,
) => CvaultEntrySource(
  name: info.name,
  length: info.length,
  sha256: info.sha256,
  open: () => archive.openRead(info.dataOffset, info.dataOffset + info.length),
);

final class _DeterministicRandom implements CryptographicRandom {
  var _next = 1;

  @override
  Future<Uint8List> secureBytes(int length) async => Uint8List.fromList(
    List<int>.generate(length, (_) => _next++ & 0xFF),
  );
}

final class _AllowStorage implements RestoreStoragePolicy {
  const _AllowStorage();

  @override
  Future<void> ensureCapacity(Directory parent, int requiredBytes) async {}
}

final class _RejectStorage implements RestoreStoragePolicy {
  const _RejectStorage();

  @override
  Future<void> ensureCapacity(Directory parent, int requiredBytes) async {
    throw const InsufficientRestoreStorageFailure();
  }
}

final class _RecordingProvisioner implements RestoredVaultProvisioner {
  String? provisionedVaultId;

  @override
  Future<void> provision({
    required SecretBytes masterKey,
    required List<int> vaultHkdfSalt,
    required String recoveryPassphrase,
    required String vaultId,
    required Directory stagingDirectory,
  }) async {
    final bytes = masterKey.extractBytes();
    try {
      expect(bytes.length, 32);
      expect(vaultHkdfSalt, hasLength(32));
      expect(
        recoveryPassphrase,
        'correct horse battery staple citizen vault',
      );
      expect(stagingDirectory.existsSync(), isTrue);
      provisionedVaultId = vaultId;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}

final class _FailingProvisioner implements RestoredVaultProvisioner {
  const _FailingProvisioner();

  @override
  Future<void> provision({
    required SecretBytes masterKey,
    required List<int> vaultHkdfSalt,
    required String recoveryPassphrase,
    required String vaultId,
    required Directory stagingDirectory,
  }) async {
    throw StateError('simulated device provisioning failure');
  }
}

Future<File> _createEmptyVaultArchive(
  Directory fixtureRoot,
  String passphrase,
) async {
  final root = Directory('${fixtureRoot.path}/empty-source')..createSync();
  final master = SecretBytes(List<int>.generate(32, (index) => index + 3));
  final salt = List<int>.generate(32, (index) => index + 7);
  final derived = await VaultKeyHierarchy().deriveAll(
    masterKey: master,
    vaultSalt: salt,
  );
  final databaseKey = SecretBytes(
    derived[VaultSubkeyContext.database].extractBytes(),
  );
  final session = await EncryptedDatabaseOpener.open(
    file: File('${root.path}/vault.db'),
    databaseKey: databaseKey,
    runInBackground: false,
  );
  databaseKey.destroy();
  final output = File('${fixtureRoot.path}/empty.cvault');
  try {
    await VaultBackupService(
      session: session,
      snapshots: SqlCipherDatabaseSnapshotService(session),
      objectRootDirectory: root,
      random: _DeterministicRandom(),
    ).create(
      VaultBackupRequest(
        generationId: BackupGenerationId('empty-generation'),
        vaultId: 'empty-vault',
        outputFile: output,
        workingDirectory: Directory('${fixtureRoot.path}/empty-working'),
        masterKey: master,
        vaultHkdfSalt: salt,
        recoveryPassphrase: passphrase,
        kdfParameters: const RecoveryKdfParameters.productionPbkdf2Fallback(),
      ),
    );
    return output;
  } finally {
    await session.close();
    derived.destroy();
    master.destroy();
    root.deleteSync(recursive: true);
  }
}

Future<({BackupFailure failure, File output})>
_attemptBackupWithMissingInventoriedObject(
  Directory fixtureRoot,
  String passphrase,
) async {
  final root = Directory('${fixtureRoot.path}/missing-object-source')
    ..createSync();
  final master = SecretBytes(List<int>.generate(32, (index) => index + 9));
  final salt = List<int>.generate(32, (index) => index + 11);
  final derived = await VaultKeyHierarchy().deriveAll(
    masterKey: master,
    vaultSalt: salt,
  );
  final databaseKey = SecretBytes(
    derived[VaultSubkeyContext.database].extractBytes(),
  );
  final session = await EncryptedDatabaseOpener.open(
    file: File('${root.path}/vault.db'),
    databaseKey: databaseKey,
    runInBackground: false,
  );
  databaseKey.destroy();
  final output = File('${fixtureRoot.path}/missing-object.cvault');
  try {
    await session.write((database) async {
      await database.customStatement(
        '''
        INSERT INTO object_references(
          object_id, reference_count, plaintext_sha256, plaintext_size,
          encrypted_size, object_format_version, key_version, chunk_count,
          verification_status, created_at, last_referenced_at
        ) VALUES (?, 1, ?, 1, 1, 1, 1, 1, 'VERIFIED', 1, 1)
        ''',
        <Object>[
          '00000000000000000000000004',
          Uint8List(32),
        ],
      );
    });
    try {
      await VaultBackupService(
        session: session,
        snapshots: SqlCipherDatabaseSnapshotService(session),
        objectRootDirectory: root,
        random: _DeterministicRandom(),
      ).create(
        VaultBackupRequest(
          generationId: BackupGenerationId('missing-object-generation'),
          vaultId: 'missing-object-vault',
          outputFile: output,
          workingDirectory: Directory('${fixtureRoot.path}/missing-working'),
          masterKey: master,
          vaultHkdfSalt: salt,
          recoveryPassphrase: passphrase,
          kdfParameters: const RecoveryKdfParameters.productionPbkdf2Fallback(),
        ),
      );
      throw StateError('Expected backup failure');
    } on BackupFailure catch (failure) {
      return (failure: failure, output: output);
    }
  } finally {
    await session.close();
    derived.destroy();
    master.destroy();
    root.deleteSync(recursive: true);
  }
}
