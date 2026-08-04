// Synthetic fixture infrastructure intentionally exposes test-only constants.
// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:vault_backup/vault_backup.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_objects/vault_objects.dart';

const String portableFixturePassphrase =
    'citizen vault synthetic interoperability fixture passphrase';
const String portableFixtureVaultId = 'portable-fixture-v1';
const String portableFixtureGenerationId = 'portable-generation-v1';

final ObjectId portableFixtureTextObjectId = ObjectId.parse(
  '00000000000000000000000011',
);
final ObjectId portableFixtureBinaryObjectId = ObjectId.parse(
  '00000000000000000000000012',
);

final class PortableVaultFixtureContract {
  PortableVaultFixtureContract({
    required this.fixtureId,
    required this.producerPlatform,
    required this.producerRuntime,
    required this.vaultId,
    required this.databaseSchemaVersion,
    required this.objects,
    required this.databaseRows,
  });

  factory PortableVaultFixtureContract.fromJson(
    Map<String, Object?> json,
  ) {
    if (json['format'] != 'citizen-vault-portable-fixture' ||
        json['version'] != 1) {
      throw const FormatException('Unsupported portable fixture contract');
    }
    final rawObjects = json['objects']! as List<Object?>;
    final rawRows = json['database_rows']! as Map<String, Object?>;
    return PortableVaultFixtureContract(
      fixtureId: json['fixture_id']! as String,
      producerPlatform: json['producer_platform']! as String,
      producerRuntime: json['producer_runtime']! as String,
      vaultId: json['vault_id']! as String,
      databaseSchemaVersion: json['database_schema_version']! as int,
      objects: rawObjects
          .map(
            (value) => PortableVaultFixtureObject.fromJson(
              value! as Map<String, Object?>,
            ),
          )
          .toList(growable: false),
      databaseRows: <String, List<Map<String, Object?>>>{
        for (final entry in rawRows.entries)
          entry.key: (entry.value! as List<Object?>)
              .map(
                (value) => Map<String, Object?>.from(
                  value! as Map<String, Object?>,
                ),
              )
              .toList(growable: false),
      },
    );
  }

  factory PortableVaultFixtureContract.decode(String source) =>
      PortableVaultFixtureContract.fromJson(
        jsonDecode(source)! as Map<String, Object?>,
      );

  final String fixtureId;
  final String producerPlatform;
  final String producerRuntime;
  final String vaultId;
  final int databaseSchemaVersion;
  final List<PortableVaultFixtureObject> objects;
  final Map<String, List<Map<String, Object?>>> databaseRows;

  Map<String, Object> toJson() => <String, Object>{
    'format': 'citizen-vault-portable-fixture',
    'version': 1,
    'fixture_id': fixtureId,
    'producer_platform': producerPlatform,
    'producer_runtime': producerRuntime,
    'vault_id': vaultId,
    'database_schema_version': databaseSchemaVersion,
    'recovery_passphrase': portableFixturePassphrase,
    'objects': objects.map((object) => object.toJson()).toList(),
    'database_rows': databaseRows,
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

final class PortableVaultFixtureObject {
  PortableVaultFixtureObject({
    required this.objectId,
    required this.plaintextBase64,
    required this.plaintextSha256Hex,
    required this.encryptedSha256Hex,
    required this.plaintextSize,
  });

  factory PortableVaultFixtureObject.fromJson(Map<String, Object?> json) =>
      PortableVaultFixtureObject(
        objectId: json['object_id']! as String,
        plaintextBase64: json['plaintext_base64']! as String,
        plaintextSha256Hex: json['plaintext_sha256_hex']! as String,
        encryptedSha256Hex: json['encrypted_sha256_hex']! as String,
        plaintextSize: json['plaintext_size']! as int,
      );

  final String objectId;
  final String plaintextBase64;
  final String plaintextSha256Hex;
  final String encryptedSha256Hex;
  final int plaintextSize;

  Map<String, Object> toJson() => <String, Object>{
    'object_id': objectId,
    'plaintext_base64': plaintextBase64,
    'plaintext_sha256_hex': plaintextSha256Hex,
    'encrypted_sha256_hex': encryptedSha256Hex,
    'plaintext_size': plaintextSize,
  };
}

final class PortableVaultFixtureBuilder {
  PortableVaultFixtureBuilder({required this._random});

  final CryptographicRandom _random;

  Future<PortableVaultFixtureContract> create({
    required Directory workingRoot,
    required File archive,
    required String producerPlatform,
    String? producerRuntime,
  }) async {
    if (workingRoot.existsSync()) workingRoot.deleteSync(recursive: true);
    workingRoot.createSync(recursive: true);
    if (archive.existsSync()) archive.deleteSync();
    archive.parent.createSync(recursive: true);

    final source = Directory('${workingRoot.path}/source')..createSync();
    final masterKey = SecretBytes(
      List<int>.generate(32, (index) => index),
    );
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
    VaultDatabaseSession? session;
    try {
      session = await EncryptedDatabaseOpener.open(
        file: File('${source.path}/vault.db'),
        databaseKey: databaseKey,
        runInBackground: false,
      );
      final objectStore = FileEncryptedObjectStore(
        rootDirectory: source,
        random: _random,
        retentionRepository: DatabaseObjectRetentionRepository(session),
      );
      final plaintextById = <ObjectId, Uint8List>{
        portableFixtureTextObjectId: Uint8List.fromList(
          utf8.encode(
            'Citizen Vault interoperability fixture.\n'
            'தமிழ் · हिन्दी · English · offline and private.\n',
          ),
        ),
        portableFixtureBinaryObjectId: Uint8List.fromList(
          List<int>.generate(131089, (index) => (index * 29 + 7) & 0xFF),
        ),
      };
      final writeResults = <ObjectId, EncryptedObjectWriteResult>{};
      for (final entry in plaintextById.entries) {
        writeResults[entry.key] = await objectStore.put(
          plaintext: Stream<List<int>>.value(entry.value),
          objectId: entry.key,
          fileRootKey: fileRootKey,
          chunkSize: 64 * 1024,
        );
      }
      await _seedDatabase(
        session,
        vaultSalt,
        writeResults[portableFixtureTextObjectId]!,
        writeResults[portableFixtureBinaryObjectId]!,
      );
      final backup = VaultBackupService(
        session: session,
        snapshots: SqlCipherDatabaseSnapshotService(session),
        objectRootDirectory: source,
        random: _random,
      );
      await backup.create(
        VaultBackupRequest(
          generationId: BackupGenerationId(portableFixtureGenerationId),
          vaultId: portableFixtureVaultId,
          outputFile: archive,
          workingDirectory: Directory('${workingRoot.path}/backup-work'),
          masterKey: masterKey,
          vaultHkdfSalt: vaultSalt,
          recoveryPassphrase: portableFixturePassphrase,
          kdfParameters: const RecoveryKdfParameters.productionPbkdf2Fallback(),
        ),
      );
      final rows = await capturePortableDatabaseRows(session);
      final unlocked =
          await VaultBackupArchiveVerifier(
            random: _random,
          ).unlockAndVerify(
            archive: archive,
            recoveryPassphrase: portableFixturePassphrase,
          );
      try {
        final manifestById = <String, BackupManifestObject>{
          for (final object in unlocked.manifest.objects)
            object.objectId: object,
        };
        final sha = Sha256().toSync();
        final objects = <PortableVaultFixtureObject>[];
        for (final entry in plaintextById.entries) {
          final bytes = entry.value;
          final manifestObject = manifestById[entry.key.value]!;
          objects.add(
            PortableVaultFixtureObject(
              objectId: entry.key.value,
              plaintextBase64: base64Encode(bytes),
              plaintextSha256Hex: _hex(sha.hashSync(bytes).bytes),
              encryptedSha256Hex: _hex(manifestObject.encryptedSha256),
              plaintextSize: bytes.length,
            ),
          );
        }
        return PortableVaultFixtureContract(
          fixtureId: 'portable-vault-v1',
          producerPlatform: producerPlatform,
          producerRuntime:
              producerRuntime ??
              '${Platform.operatingSystem}-${Platform.version}',
          vaultId: portableFixtureVaultId,
          databaseSchemaVersion: unlocked.manifest.databaseSchemaVersion,
          objects: objects,
          databaseRows: rows,
        );
      } finally {
        unlocked.destroy();
      }
    } finally {
      await session?.close();
      databaseKey.destroy();
      fileRootKey.destroy();
      derived.destroy();
      masterKey.destroy();
    }
  }
}

final class PortableVaultFixtureVerification {
  const PortableVaultFixtureVerification({
    required this.vaultId,
    required this.objectCount,
    required this.databaseTableCount,
  });

  final String vaultId;
  final int objectCount;
  final int databaseTableCount;
}

abstract final class PortableVaultFixtureVerifier {
  static Future<PortableVaultFixtureVerification> verify({
    required File archive,
    required PortableVaultFixtureContract contract,
    required Directory restoreParent,
    required CryptographicRandom random,
    RestoredVaultProvisioner? provisioner,
  }) async {
    if (contract.vaultId != portableFixtureVaultId) {
      throw StateError('Fixture contract vault ID does not match');
    }
    final unlocked =
        await VaultBackupArchiveVerifier(
          random: random,
        ).unlockAndVerify(
          archive: archive,
          recoveryPassphrase: portableFixturePassphrase,
        );
    final masterBytes = unlocked.secrets.masterKey.extractBytes();
    final vaultSalt = Uint8List.fromList(unlocked.secrets.vaultHkdfSalt);
    try {
      if (unlocked.manifest.vaultId != contract.vaultId ||
          unlocked.manifest.databaseSchemaVersion !=
              contract.databaseSchemaVersion) {
        throw StateError('Fixture manifest does not match its contract');
      }
      final manifestObjects = <String, BackupManifestObject>{
        for (final object in unlocked.manifest.objects) object.objectId: object,
      };
      for (final object in contract.objects) {
        final manifestObject = manifestObjects[object.objectId];
        if (manifestObject == null ||
            _hex(manifestObject.encryptedSha256) != object.encryptedSha256Hex) {
          throw StateError(
            'Encrypted object hash mismatch: ${object.objectId}',
          );
        }
      }
    } finally {
      unlocked.destroy();
    }

    if (restoreParent.existsSync()) restoreParent.deleteSync(recursive: true);
    final result =
        await BackupRestoreService(
          archiveVerifier: VaultBackupArchiveVerifier(random: random),
          capacityPolicy: const _AllowFixtureStorage(),
          provisioner: provisioner ?? const _FixtureProvisioner(),
          randomSource: random,
        ).restore(
          archive: archive,
          recoveryPassphrase: portableFixturePassphrase,
          vaultsParent: restoreParent,
        );
    final masterKey = SecretBytes(masterBytes);
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
    VaultDatabaseSession? session;
    try {
      session = await EncryptedDatabaseOpener.open(
        file: File('${result.activeDirectory.path}/vault.db'),
        databaseKey: databaseKey,
        runInBackground: false,
      );
      final rows = await capturePortableDatabaseRows(session);
      // Opening an older portable vault applies non-destructive migrations;
      // compare its row content while allowing the recorded schema version to
      // advance independently of the fixture's producer version.
      final comparableRows = <String, List<Map<String, Object?>>>{
        ...rows,
        'vault_metadata': rows['vault_metadata']!
            .map((row) {
              return <String, Object?>{
                ...row,
                'database_schema_version': contract
                    .databaseRows['vault_metadata']!
                    .first['database_schema_version'],
              };
            })
            .toList(growable: false),
      };
      if (jsonEncode(comparableRows) != jsonEncode(contract.databaseRows)) {
        throw StateError(
          'Restored database rows do not match fixture contract',
        );
      }
      final objectStore = FileEncryptedObjectStore(
        rootDirectory: result.activeDirectory,
        random: random,
        retentionRepository: DatabaseObjectRetentionRepository(session),
      );
      final sha = Sha256().toSync();
      for (final object in contract.objects) {
        final objectId = ObjectId.parse(object.objectId);
        final restored = BytesBuilder(copy: false);
        await objectStore
            .read(objectId: objectId, fileRootKey: fileRootKey)
            .forEach(restored.add);
        final plaintext = restored.takeBytes();
        if (plaintext.length != object.plaintextSize ||
            base64Encode(plaintext) != object.plaintextBase64 ||
            _hex(sha.hashSync(plaintext).bytes) != object.plaintextSha256Hex) {
          throw StateError('Restored plaintext mismatch: ${object.objectId}');
        }
        final encrypted = File(
          '${result.activeDirectory.path}/objects/${object.objectId}.bin',
        );
        if (_hex(await sha256File(encrypted)) != object.encryptedSha256Hex) {
          throw StateError(
            'Restored encrypted hash mismatch: ${object.objectId}',
          );
        }
      }
      return PortableVaultFixtureVerification(
        vaultId: result.vaultId,
        objectCount: result.objectCount,
        databaseTableCount: rows.length,
      );
    } finally {
      await session?.close();
      databaseKey.destroy();
      fileRootKey.destroy();
      derived.destroy();
      masterKey.destroy();
      masterBytes.fillRange(0, masterBytes.length, 0);
      vaultSalt.fillRange(0, vaultSalt.length, 0);
    }
  }
}

Future<Map<String, List<Map<String, Object?>>>> capturePortableDatabaseRows(
  VaultDatabaseSession session,
) async {
  const queries = <String, String>{
    'vault_metadata':
        'SELECT id, vault_id, created_at, updated_at, '
        'database_schema_version, encryption_format_version, '
        'backup_format_version, object_format_version, hex(hkdf_salt) AS '
        'hkdf_salt_hex, active_database_key_version, '
        'active_file_root_key_version, active_backup_key_version '
        'FROM vault_metadata ORDER BY id',
    'documents':
        'SELECT id, logical_filename, document_type, mime_type, source_type, '
        'status, primary_object_id, hex(plaintext_sha256) AS '
        'plaintext_sha256_hex, plaintext_size, encrypted_size, '
        'original_created_at, imported_at, updated_at, integrity_status, '
        'is_favourite, is_archived, deleted_at FROM documents ORDER BY id',
    'document_text':
        'SELECT id, document_id, page_number, raw_text, normalized_text, '
        'ocr_engine_id, ocr_engine_version, ocr_pipeline_version, '
        'language_codes, created_at FROM document_text ORDER BY id',
    'document_classifications':
        'SELECT id, document_id, document_type, confidence, classifier_id, '
        'classifier_version, evidence_json, confirmed_by_user, created_at, '
        'updated_at FROM document_classifications ORDER BY id',
    'extracted_fields':
        'SELECT id, document_id, field_type, raw_value, normalized_value, '
        'confidence, source_page, source_block_id, extractor_id, '
        'extractor_version, confirmed_by_user, created_at, updated_at '
        'FROM extracted_fields ORDER BY id',
    'document_tags':
        'SELECT id, name, normalized_name, created_at, updated_at '
        'FROM document_tags ORDER BY id',
    'document_tag_links':
        'SELECT document_id, tag_id, created_at FROM document_tag_links '
        'ORDER BY document_id, tag_id',
    'reminders':
        'SELECT id, document_id, reminder_type, title, due_at, '
        'recurrence_rule, is_enabled, notification_id, created_at, updated_at, '
        'completed_at FROM reminders ORDER BY id',
    'object_references':
        'SELECT object_id, reference_count, hex(plaintext_sha256) AS '
        'plaintext_sha256_hex, plaintext_size, encrypted_size, '
        'object_format_version, key_version, chunk_count FROM '
        'object_references ORDER BY object_id',
    'pipeline_versions':
        'SELECT version, configuration_sha256, is_active, created_at '
        'FROM pipeline_versions ORDER BY version',
    'app_settings':
        'SELECT setting_key, setting_value, updated_at FROM app_settings '
        'ORDER BY setting_key',
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

Future<void> _seedDatabase(
  VaultDatabaseSession session,
  List<int> vaultSalt,
  EncryptedObjectWriteResult text,
  EncryptedObjectWriteResult binary,
) => session.write((database) async {
  const timestamp = 1784203200000;
  await database.customStatement(
    'INSERT INTO vault_metadata VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object>[
      'metadata-v1',
      portableFixtureVaultId,
      timestamp,
      timestamp,
      4,
      1,
      1,
      1,
      vaultSalt,
      1,
      1,
      1,
    ],
  );
  await database.customStatement(
    'UPDATE object_references SET reference_count = 1, created_at = ?, '
    'last_referenced_at = ?, last_verified_at = ?',
    <Object>[timestamp, timestamp, timestamp],
  );
  await database.customStatement(
    'INSERT INTO pipeline_versions VALUES (?, ?, ?, ?), (?, ?, ?, ?)',
    <Object>[
      1,
      'fixture-pipeline-v1',
      0,
      timestamp,
      7,
      'fixture-pipeline-v7',
      1,
      timestamp,
    ],
  );
  await _insertDocument(
    database,
    'document-text',
    'identity-note.txt',
    'NOTE',
    'text/plain',
    text,
    timestamp,
  );
  await _insertDocument(
    database,
    'document-binary',
    'travel-card.bin',
    'CARD',
    'application/octet-stream',
    binary,
    timestamp + 1,
  );
  await database.customStatement(
    'INSERT INTO document_text VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object>[
      'text-v1',
      'document-text',
      1,
      'Citizen Vault interoperability fixture',
      'citizen vault interoperability fixture',
      'fixture-ocr',
      '1.0.0',
      7,
      'en,ta,hi',
      timestamp,
    ],
  );
  await database.customStatement(
    'INSERT INTO document_classifications '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object>[
      'classification-v1',
      'document-text',
      'NOTE',
      0.99,
      'fixture-classifier',
      '1.0.0',
      '{"source":"fixture"}',
      1,
      timestamp,
      timestamp,
    ],
  );
  await database.customStatement(
    'INSERT INTO extracted_fields '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'field-v1',
      'document-text',
      'ISSUER',
      'Citizen Vault',
      'Citizen Vault',
      1.0,
      1,
      'block-v1',
      'fixture-extractor',
      '1.0.0',
      1,
      timestamp,
      timestamp,
    ],
  );
  await database.customStatement(
    'INSERT INTO document_tags VALUES (?, ?, ?, ?, ?)',
    <Object>['tag-v1', 'Important', 'important', timestamp, timestamp],
  );
  await database.customStatement(
    'INSERT INTO document_tag_links VALUES (?, ?, ?)',
    <Object>['document-text', 'tag-v1', timestamp],
  );
  await database.customStatement(
    'INSERT INTO reminders VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'reminder-v1',
      'document-binary',
      'EXPIRY',
      'Review travel card',
      timestamp + 86400000,
      null,
      1,
      7001,
      timestamp,
      timestamp,
      null,
    ],
  );
  await database.customStatement(
    'INSERT INTO app_settings VALUES (?, ?, ?)',
    <Object>['fixture.locale', 'en-IN', timestamp],
  );
  await database.rebuildFtsIndex();
});

Future<void> _insertDocument(
  CitizenVaultDatabase database,
  String id,
  String filename,
  String type,
  String mime,
  EncryptedObjectWriteResult object,
  int timestamp,
) => database.customStatement(
  'INSERT INTO documents(id, logical_filename, document_type, mime_type, '
  'source_type, status, primary_object_id, plaintext_sha256, plaintext_size, '
  'encrypted_size, original_created_at, imported_at, updated_at, verified_at, '
  'integrity_status, is_favourite, is_archived) '
  'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
  <Object>[
    id,
    filename,
    type,
    mime,
    'FIXTURE',
    'READY',
    object.objectId.value,
    object.plaintextSha256,
    object.plaintextSize,
    object.encryptedSize,
    timestamp,
    timestamp,
    timestamp,
    timestamp,
    'VERIFIED',
    if (id == 'document-text') 1 else 0,
    0,
  ],
);

final class _AllowFixtureStorage implements RestoreStoragePolicy {
  const _AllowFixtureStorage();

  @override
  Future<void> ensureCapacity(Directory parent, int requiredBytes) async {}
}

final class _FixtureProvisioner implements RestoredVaultProvisioner {
  const _FixtureProvisioner();

  @override
  Future<void> provision({
    required SecretBytes masterKey,
    required List<int> vaultHkdfSalt,
    required String recoveryPassphrase,
    required String vaultId,
    required Directory stagingDirectory,
  }) async {
    if (masterKey.length != 32 || vaultId != portableFixtureVaultId) {
      throw StateError('Invalid fixture device-envelope request');
    }
  }
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
