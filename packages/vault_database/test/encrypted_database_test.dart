import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';

void main() {
  group('encrypted database', () {
    late Directory temporaryDirectory;
    late File databaseFile;
    late SecretBytes databaseKey;
    VaultDatabaseSession? session;

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'citizen_vault_database_test_',
      );
      databaseFile = File('${temporaryDirectory.path}/vault.db');
      databaseKey = SecretBytes(List<int>.generate(32, (index) => index + 1));
    });

    tearDown(() async {
      await session?.close();
      databaseKey.destroy();
      temporaryDirectory.deleteSync(recursive: true);
    });

    test('creates the complete schema inside SQLCipher', () async {
      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );

      final tableNames = await session!.read(
        (database) => database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type IN ('table', 'view')",
            )
            .get()
            .then(
              (rows) => rows.map((row) => row.read<String>('name')).toSet(),
            ),
      );
      expect(tableNames, containsAll(requiredTables));

      final schemaVersion = await session!.read(
        (database) => database
            .customSelect(
              'SELECT schema_sha256 FROM schema_versions WHERE version = 7',
            )
            .getSingle(),
      );
      expect(
        schemaVersion.read<String>('schema_sha256'),
        CitizenVaultDatabase.schemaV7Sha256,
      );

      final bytes = databaseFile.readAsBytesSync();
      final header = String.fromCharCodes(bytes.take(16));
      expect(header, isNot('SQLite format 3\u0000'));
    });

    test(
      'rejects the wrong key without exposing the underlying error',
      () async {
        session = await EncryptedDatabaseOpener.open(
          file: databaseFile,
          databaseKey: databaseKey,
          runInBackground: false,
        );
        await session!.close();
        session = null;

        final wrongKey = SecretBytes(List<int>.filled(32, 0xA5));
        addTearDown(wrongKey.destroy);
        await expectLater(
          EncryptedDatabaseOpener.open(
            file: databaseFile,
            databaseKey: wrongKey,
            runInBackground: false,
          ),
          throwsA(isA<DatabaseOpenFailure>()),
        );
      },
    );

    test('opens through the production background executor', () async {
      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
      );
      final cipherVersion = await session!.read(
        (database) => database
            .customSelect('PRAGMA cipher_version;')
            .getSingle()
            .then((row) => row.data.values.single),
      );
      expect(cipherVersion, isA<String>());
      expect(cipherVersion, isNotEmpty);
    });

    test(
      'indexes searchable metadata and rebuilds FTS deterministically',
      () async {
        session = await EncryptedDatabaseOpener.open(
          file: databaseFile,
          databaseKey: databaseKey,
          runInBackground: false,
        );
        await session!.write((database) async {
          await insertDocument(database);
          await database.customStatement(
            '''
          INSERT INTO document_text(
            id, document_id, page_number, raw_text, normalized_text,
            ocr_engine_id, ocr_engine_version, ocr_pipeline_version, created_at
          ) VALUES (?, ?, 1, ?, ?, ?, ?, 1, ?)
          ''',
            <Object>[
              'text-1',
              'document-1',
              'Passport issued by Republic of India',
              'passport issued by republic of india',
              'test-ocr',
              '1.0',
              1,
            ],
          );
          await database.customStatement(
            '''
          INSERT INTO extracted_fields(
            id, document_id, field_type, normalized_value, extractor_id,
            extractor_version, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
            <Object>[
              'field-1',
              'document-1',
              'DOCUMENT_NUMBER',
              'P1234567',
              'test-extractor',
              '1.0',
              1,
              1,
            ],
          );
          await database.indexDocument('document-1');
        });

        final results = await session!.read(
          (database) => database.searchDocumentIds('P1234567', 10, 0).get(),
        );
        expect(results.single.documentId, 'document-1');
        await session!.write((database) => database.rebuildFtsIndex());
        final integrity = await session!.read(DatabaseIntegrityService.verify);
        expect(integrity.isValid, isTrue);
      },
    );

    test('rolls back an interrupted transaction', () async {
      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );

      await expectLater(
        session!.write(
          (database) => database.transaction(() async {
            await insertDocument(database);
            throw StateError('simulated migration interruption');
          }),
        ),
        throwsStateError,
      );
      final documents = await session!.read(
        (database) => database.allDocuments().get(),
      );
      expect(documents, isEmpty);
    });

    test(
      'reopens a populated version-one database without data loss',
      () async {
        session = await EncryptedDatabaseOpener.open(
          file: databaseFile,
          databaseKey: databaseKey,
          runInBackground: false,
        );
        await session!.write(insertDocument);
        await session!.close();
        session = null;

        session = await EncryptedDatabaseOpener.open(
          file: databaseFile,
          databaseKey: databaseKey,
          runInBackground: false,
        );
        final documents = await session!.read(
          (database) => database.allDocuments().get(),
        );
        expect(documents.single.logicalFilename, 'my-passport.pdf');
      },
    );

    test('migrates populated schema version one object metadata', () async {
      final keyBytes = databaseKey.extractBytes();
      final raw = sqlite.sqlite3.open(databaseFile.path);
      try {
        EncryptedDatabaseOpener.configureRawSqlCipher(
          raw,
          keyBytes,
          useWal: false,
        );
        final schema =
            jsonDecode(
                  File(
                    '../../docs/database/drift_schemas/drift_schema_v1.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        final fixedSql = schema['fixed_sql']! as List<Object?>;
        for (final entityValue in fixedSql) {
          final entity = entityValue! as Map<String, Object?>;
          final dialects = entity['sql']! as List<Object?>;
          final sqliteDialect = dialects
              .cast<Map<String, Object?>>()
              .singleWhere((value) => value['dialect'] == 'sqlite');
          raw.execute(sqliteDialect['sql']! as String);
        }
        raw
          ..execute(
            'INSERT INTO schema_versions VALUES (1, 1, ?)',
            <Object>[CitizenVaultDatabase.schemaV1Sha256],
          )
          ..execute(
            '''
            INSERT INTO object_references(
              object_id, reference_count, plaintext_sha256, plaintext_size,
              encrypted_size, created_at, last_referenced_at
            ) VALUES (?, 0, ?, 10, 20, 1, 1)
            ''',
            <Object>['legacy-object', Uint8List(32)],
          )
          ..execute('PRAGMA user_version = 1;');
      } finally {
        raw.close();
        keyBytes.fillRange(0, keyBytes.length, 0);
      }

      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      final migrated = await session!.read(
        (database) => database.customSelect(
          '''
          SELECT object_format_version, key_version, chunk_count,
                 verification_status, last_verified_at
          FROM object_references WHERE object_id = 'legacy-object'
          ''',
        ).getSingle(),
      );
      expect(migrated.read<int>('object_format_version'), 1);
      expect(migrated.read<int>('key_version'), 1);
      expect(migrated.read<int>('chunk_count'), 0);
      expect(migrated.read<String>('verification_status'), 'UNVERIFIED');
      expect(migrated.readNullable<int>('last_verified_at'), isNull);
      final versions = await session!.read(
        (database) => database
            .customSelect(
              'SELECT version FROM schema_versions ORDER BY version',
            )
            .get(),
      );
      expect(
        versions.map((row) => row.read<int>('version')),
        <int>[1, 2, 3, 4, 5, 6, 7],
      );
    });

    test('migrates populated schema version two backup inventory', () async {
      final keyBytes = databaseKey.extractBytes();
      final raw = sqlite.sqlite3.open(databaseFile.path);
      try {
        EncryptedDatabaseOpener.configureRawSqlCipher(
          raw,
          keyBytes,
          useWal: false,
        );
        _createSchemaFromArtifact(
          raw,
          '../../docs/database/drift_schemas/drift_schema_v2.json',
        );
        raw
          ..execute(
            'INSERT INTO schema_versions VALUES (2, 1, ?)',
            <Object>[CitizenVaultDatabase.schemaV2Sha256],
          )
          ..execute(
            '''
            INSERT INTO backup_generations(id, status, created_at)
            VALUES ('legacy-generation', 'VERIFIED', 1)
            ''',
          )
          ..execute(
            '''
            INSERT INTO backup_generation_objects(
              generation_id, object_id, plaintext_sha256, encrypted_size
            ) VALUES ('legacy-generation', 'legacy-object', ?, 20)
            ''',
            <Object>[Uint8List(32)],
          )
          ..execute('PRAGMA user_version = 2;');
      } finally {
        raw.close();
        keyBytes.fillRange(0, keyBytes.length, 0);
      }

      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      final generation = await session!.read(
        (database) => database.customSelect(
          '''
              SELECT archive_path_token FROM backup_generations
              WHERE id = 'legacy-generation'
              ''',
        ).getSingle(),
      );
      expect(generation.readNullable<String>('archive_path_token'), isNull);
      final object = await session!.read(
        (database) => database.customSelect(
          '''
          SELECT required_until, status FROM backup_generation_objects
          WHERE generation_id = 'legacy-generation'
          ''',
        ).getSingle(),
      );
      expect(object.readNullable<int>('required_until'), isNull);
      expect(object.read<String>('status'), 'INVENTORIED');
    });

    test('migrates a populated version-four Life Graph to Events', () async {
      final keyBytes = databaseKey.extractBytes();
      final raw = sqlite.sqlite3.open(databaseFile.path);
      try {
        EncryptedDatabaseOpener.configureRawSqlCipher(
          raw,
          keyBytes,
          useWal: false,
        );
        _createSchemaFromArtifact(
          raw,
          '../../docs/database/drift_schemas/drift_schema_v4.json',
        );
        raw
          ..execute(
            'INSERT INTO schema_versions VALUES (4, 1, ?)',
            <Object>[CitizenVaultDatabase.schemaV4Sha256],
          )
          ..execute(
            'INSERT INTO entities(id, entity_type, display_name, status, '
            'created_at, updated_at) VALUES '
            "('legacy-vehicle', 'VEHICLE', 'Existing Car', 'ACTIVE', 1, 1)",
          )
          ..execute('PRAGMA user_version = 4;');
      } finally {
        raw.close();
        keyBytes.fillRange(0, keyBytes.length, 0);
      }

      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      final preserved = await session!.read(
        (database) => database
            .customSelect(
              "SELECT display_name FROM entities WHERE id = 'legacy-vehicle'",
            )
            .getSingle(),
      );
      expect(preserved.read<String>('display_name'), 'Existing Car');
      final eventTables = await session!.read(
        (database) => database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('life_events', 'event_entities', "
              "'event_evidence_links', 'event_history')",
            )
            .get(),
      );
      expect(eventTables, hasLength(4));
    });

    test('migrates a populated version-five Timeline to Attention', () async {
      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      await session!.write(
        (database) => database.customStatement(
          'INSERT INTO life_events(id, event_type, title, start_at, status, '
          'created_at, updated_at) VALUES '
          "('existing-event', 'SERVICE', 'Existing service', 1, "
          "'CONFIRMED', 1, 1)",
        ),
      );
      await session!.close();
      session = null;
      final keyBytes = databaseKey.extractBytes();
      final raw = sqlite.sqlite3.open(databaseFile.path);
      try {
        EncryptedDatabaseOpener.configureRawSqlCipher(
          raw,
          keyBytes,
          useWal: false,
        );
        raw
          ..execute('DROP TABLE smart_pack_items')
          ..execute('DROP TABLE smart_packs')
          ..execute('DROP TABLE life_checklist_items')
          ..execute('DROP TABLE life_checklists')
          ..execute('DROP TABLE life_tasks')
          ..execute('DROP TABLE attention_items')
          ..execute('DROP TABLE state_inputs')
          ..execute('DROP TABLE derived_states')
          ..execute('DELETE FROM schema_versions WHERE version = 7')
          ..execute('DELETE FROM schema_versions WHERE version = 6')
          ..execute(
            'INSERT OR REPLACE INTO schema_versions VALUES (5, 1, ?)',
            <Object>[CitizenVaultDatabase.schemaV5Sha256],
          )
          ..execute('PRAGMA user_version = 5;');
      } finally {
        raw.close();
        keyBytes.fillRange(0, keyBytes.length, 0);
      }
      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      final preserved = await session!.read(
        (database) => database
            .customSelect(
              "SELECT title FROM life_events WHERE id = 'existing-event'",
            )
            .getSingle(),
      );
      expect(preserved.read<String>('title'), 'Existing service');
      final tables = await session!.read(
        (database) => database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('derived_states', 'state_inputs', "
              "'attention_items', 'life_tasks', 'life_checklists', "
              "'life_checklist_items')",
            )
            .get(),
      );
      expect(tables, hasLength(6));
    });

    test('migrates populated schema version six to Smart Packs', () async {
      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      await session!.write(
        (database) => database.customStatement(
          'INSERT INTO life_tasks(id, title, origin, status, created_at, '
          "updated_at) VALUES ('existing-task', 'Existing task', 'MANUAL', "
          "'OPEN', 1, 1)",
        ),
      );
      await session!.close();
      session = null;
      final keyBytes = databaseKey.extractBytes();
      final raw = sqlite.sqlite3.open(databaseFile.path);
      try {
        EncryptedDatabaseOpener.configureRawSqlCipher(
          raw,
          keyBytes,
          useWal: false,
        );
        raw
          ..execute('DROP TABLE smart_pack_items')
          ..execute('DROP TABLE smart_packs')
          ..execute('DELETE FROM schema_versions WHERE version = 7')
          ..execute(
            'INSERT OR REPLACE INTO schema_versions VALUES (6, 1, ?)',
            <Object>[CitizenVaultDatabase.schemaV6Sha256],
          )
          ..execute('PRAGMA user_version = 6;');
      } finally {
        raw.close();
        keyBytes.fillRange(0, keyBytes.length, 0);
      }
      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      final task = await session!.read(
        (database) => database
            .customSelect(
              "SELECT title FROM life_tasks WHERE id = 'existing-task'",
            )
            .getSingle(),
      );
      expect(task.read<String>('title'), 'Existing task');
      final tables = await session!.read(
        (database) => database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('smart_packs', 'smart_pack_items')",
            )
            .get(),
      );
      expect(tables, hasLength(2));
    });

    test('creates an independently verifiable encrypted snapshot', () async {
      session = await EncryptedDatabaseOpener.open(
        file: databaseFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      await session!.write(insertDocument);
      await session!.write((database) => database.rebuildFtsIndex());
      final snapshotFile = File('${temporaryDirectory.path}/snapshot.db');
      final snapshots = SqlCipherDatabaseSnapshotService(session!);

      final result = await snapshots.createSnapshot(
        generationId: BackupGenerationId('generation-1'),
        outputPath: snapshotFile.path,
      );
      expect(result.encryptedBytes, greaterThan(4096));
      await snapshots.verifySnapshot(snapshotFile.path);
      await session!.close();
      session = null;

      final snapshotSession = await EncryptedDatabaseOpener.open(
        file: snapshotFile,
        databaseKey: databaseKey,
        runInBackground: false,
      );
      addTearDown(snapshotSession.close);
      final documents = await snapshotSession.read(
        (database) => database.allDocuments().get(),
      );
      expect(documents.single.id, 'document-1');
      final snapshotIntegrity = await snapshotSession.read(
        DatabaseIntegrityService.verify,
      );
      expect(snapshotIntegrity.isValid, isTrue);
    });
  });

  group('DatabaseWriteBarrier', () {
    test('waits for active writes and queues snapshots in order', () async {
      final barrier = DatabaseWriteBarrier();
      final writerMayFinish = Completer<void>();
      final firstWrite = barrier.runWrite(() => writerMayFinish.future);
      final firstLeaseFuture = barrier.acquireSnapshot();
      var firstLeaseAcquired = false;
      unawaited(firstLeaseFuture.then((_) => firstLeaseAcquired = true));
      await Future<void>.delayed(Duration.zero);
      expect(firstLeaseAcquired, isFalse);

      writerMayFinish.complete();
      await firstWrite;
      final firstLease = await firstLeaseFuture;
      final secondLeaseFuture = barrier.acquireSnapshot();
      var secondLeaseAcquired = false;
      unawaited(secondLeaseFuture.then((_) => secondLeaseAcquired = true));
      await Future<void>.delayed(Duration.zero);
      expect(secondLeaseAcquired, isFalse);

      firstLease.release();
      final secondLease = await secondLeaseFuture;
      secondLease.release();
    });
  });
}

const Set<String> requiredTables = <String>{
  'vault_metadata',
  'schema_versions',
  'documents',
  'document_assets',
  'document_text',
  'document_fts',
  'document_classifications',
  'extracted_fields',
  'document_tags',
  'document_tag_links',
  'reminders',
  'processing_jobs',
  'processing_job_steps',
  'backup_generations',
  'backup_generation_objects',
  'object_references',
  'object_tombstones',
  'audit_events',
  'app_settings',
  'ocr_engines',
  'pipeline_versions',
  'entities',
  'entity_attributes',
  'provenance_records',
  'relationships',
  'relationship_history',
  'claims',
  'claim_values',
  'claim_history',
  'life_events',
  'event_entities',
  'event_evidence_links',
  'event_history',
  'derived_states',
  'state_inputs',
  'attention_items',
  'life_tasks',
  'life_checklists',
  'life_checklist_items',
  'smart_packs',
  'smart_pack_items',
  'evidence_links',
  'graph_audit_events',
};

Future<void> insertDocument(CitizenVaultDatabase database) =>
    database.customStatement(
      '''
      INSERT INTO documents(
        id, logical_filename, document_type, mime_type, source_type, status,
        primary_object_id, plaintext_sha256, plaintext_size, encrypted_size,
        imported_at, updated_at, integrity_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object>[
        'document-1',
        'my-passport.pdf',
        'PASSPORT',
        'application/pdf',
        'IMPORT',
        'READY',
        'object-1',
        Uint8List(32),
        1024,
        1100,
        1,
        1,
        'VERIFIED',
      ],
    );

void _createSchemaFromArtifact(sqlite.Database database, String path) {
  final schema =
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
  final fixedSql = schema['fixed_sql']! as List<Object?>;
  for (final entityValue in fixedSql) {
    final entity = entityValue! as Map<String, Object?>;
    final dialects = entity['sql']! as List<Object?>;
    final sqliteDialect = dialects.cast<Map<String, Object?>>().singleWhere(
      (value) => value['dialect'] == 'sqlite',
    );
    database.execute(sqliteDialect['sql']! as String);
  }
}
