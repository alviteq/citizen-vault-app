// Request and verified-context fields are documented in backup format docs.
// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:vault_backup/src/archive/cvault_archive.dart';
import 'package:vault_backup/src/crypto/backup_cryptography.dart';
import 'package:vault_backup/src/errors/backup_failure.dart';
import 'package:vault_backup/src/format/backup_codecs.dart';
import 'package:vault_backup/src/model/backup_models.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';

/// Inputs for one complete verified portable backup.
final class VaultBackupRequest {
  /// Creates a request.
  const VaultBackupRequest({
    required this.generationId,
    required this.vaultId,
    required this.outputFile,
    required this.workingDirectory,
    required this.masterKey,
    required this.vaultHkdfSalt,
    required this.recoveryPassphrase,
    this.kdfParameters = const RecoveryKdfParameters.productionArgon2id(),
  });

  final BackupGenerationId generationId;
  final String vaultId;
  final File outputFile;
  final Directory workingDirectory;
  final SecretBytes masterKey;
  final List<int> vaultHkdfSalt;
  final String recoveryPassphrase;
  final RecoveryKdfParameters kdfParameters;
}

/// Fully authenticated archive context. Call [destroy] after restore/inspection.
final class UnlockedBackupArchive {
  UnlockedBackupArchive({
    required this.header,
    required this.manifest,
    required this.secrets,
    required this.entries,
  });

  final BackupPublicHeader header;
  final BackupManifest manifest;
  final UnlockedBackupSecrets secrets;
  final List<CvaultArchiveEntryInfo> entries;

  void destroy() => secrets.destroy();
}

/// Reopens and cryptographically verifies a `.cvault` without extracting it.
final class VaultBackupArchiveVerifier {
  /// Creates the verifier.
  VaultBackupArchiveVerifier({
    required CryptographicRandom random,
    this.policy = const VaultImportPolicy(),
  }) : _cryptography = BackupCryptography(random: random);

  final BackupCryptography _cryptography;
  final VaultImportPolicy policy;

  /// Authenticates header, recovery envelope, manifest, and full inventory.
  Future<UnlockedBackupArchive> unlockAndVerify({
    required File archive,
    required String recoveryPassphrase,
  }) async {
    final reader = CvaultArchiveReader(archive, policy: policy);
    final entries = await reader.inspect();
    final byName = <String, CvaultArchiveEntryInfo>{
      for (final entry in entries) entry.name: entry,
    };
    final headerInfo = byName['header.cbor'];
    final recoveryInfo = byName['recovery-envelope.cbor'];
    final manifestInfo = byName['encrypted-manifest.bin'];
    final snapshotInfo = byName['database/snapshot.bin'];
    if (headerInfo == null ||
        recoveryInfo == null ||
        manifestInfo == null ||
        snapshotInfo == null) {
      throw const BackupVerificationFailure('required_entry');
    }
    final headerBytes = await reader.readSmall(
      headerInfo,
      maximumBytes: policy.maximumPublicHeaderBytes,
    );
    final header = BackupPublicHeaderCodec.decode(
      headerBytes,
      policy: policy,
    );
    final recoveryBytes = await reader.readSmall(
      recoveryInfo,
      maximumBytes: 1024,
    );
    final recovery = BackupRecoveryEnvelopeCodec.decode(recoveryBytes);
    final secrets = await _cryptography.unlockRecoveryEnvelope(
      recoveryPassphrase: recoveryPassphrase,
      header: header,
      canonicalHeaderBytes: headerBytes,
      envelope: recovery,
    );
    try {
      final derived = await VaultKeyHierarchy().deriveAll(
        masterKey: secrets.masterKey,
        vaultSalt: secrets.vaultHkdfSalt,
      );
      try {
        final encryptedManifest = await reader.readSmall(
          manifestInfo,
          maximumBytes: policy.maximumManifestBytes + 64,
        );
        final manifestBytes = await _cryptography.decryptManifest(
          encryptedManifestBytes: encryptedManifest,
          backupKey: derived[VaultSubkeyContext.backup],
          canonicalHeaderBytes: headerBytes,
          recoveryEnvelopeBytes: recoveryBytes,
          maximumManifestBytes: policy.maximumManifestBytes,
        );
        final manifest = BackupManifestCodec.decode(
          manifestBytes,
          policy: policy,
        );
        _verifyInventory(manifest, entries, snapshotInfo, policy);
        return UnlockedBackupArchive(
          header: header,
          manifest: manifest,
          secrets: secrets,
          entries: entries,
        );
      } finally {
        derived.destroy();
      }
    } on Object {
      secrets.destroy();
      rethrow;
    }
  }

  static void _verifyInventory(
    BackupManifest manifest,
    List<CvaultArchiveEntryInfo> entries,
    CvaultArchiveEntryInfo snapshot,
    VaultImportPolicy policy,
  ) {
    if (manifest.backupFormatVersion != BackupPublicHeader.currentVersion ||
        manifest.databaseSchemaVersion > 7 ||
        manifest.minimumReaderVersion > BackupManifest.currentVersion ||
        manifest.objectFormatVersion != 1 ||
        manifest.encryptionFormatVersion != 1 ||
        manifest.requiredAlgorithmVersions.length != 1 ||
        manifest.requiredAlgorithmVersions.single != 1 ||
        snapshot.length != manifest.snapshotSize ||
        !_equal(snapshot.sha256, manifest.snapshotSha256)) {
      throw const BackupVerificationFailure('manifest_compatibility');
    }
    final expected = <String>{
      'header.cbor',
      'recovery-envelope.cbor',
      'encrypted-manifest.bin',
      'database/snapshot.bin',
      for (final object in manifest.objects) 'objects/${object.objectId}.bin',
    };
    final actual = entries.map((entry) => entry.name).toSet();
    if (expected.length != actual.length || !expected.containsAll(actual)) {
      throw const BackupVerificationFailure('archive_inventory');
    }
    final byName = <String, CvaultArchiveEntryInfo>{
      for (final entry in entries) entry.name: entry,
    };
    var largestObject = 0;
    var declaredBytes = manifest.snapshotSize;
    for (final object in manifest.objects) {
      final entry = byName['objects/${object.objectId}.bin'];
      if (entry == null ||
          entry.length != object.encryptedSize ||
          !_equal(entry.sha256, object.encryptedSha256)) {
        throw const BackupVerificationFailure('object_inventory');
      }
      if (entry.length > largestObject) largestObject = entry.length;
      declaredBytes += entry.length;
    }
    policy.validateArchiveDeclarations(
      manifestBytes: 1,
      entries: entries.length,
      largestObjectBytes: largestObject,
      declaredPlaintextBytes: declaredBytes,
      chunkBytes: 1,
      longestPathBytes: entries
          .map((entry) => entry.name.length)
          .fold(0, (left, right) => left > right ? left : right),
      nestingDepth: 2,
      decompressionRatio: 1,
    );
  }
}

/// Creates verified `.cvault` archives after a consistent SQLCipher snapshot.
final class VaultBackupService {
  /// Creates the service for an unlocked vault.
  VaultBackupService({
    required VaultDatabaseSession session,
    required DatabaseSnapshotService snapshots,
    required Directory objectRootDirectory,
    required CryptographicRandom random,
  }) : _databaseSession = session,
       _snapshotService = snapshots,
       _objectsDirectory = Directory('${objectRootDirectory.path}/objects'),
       _random = random,
       _cryptography = BackupCryptography(random: random),
       _verifier = VaultBackupArchiveVerifier(random: random);

  final VaultDatabaseSession _databaseSession;
  final DatabaseSnapshotService _snapshotService;
  final Directory _objectsDirectory;
  final CryptographicRandom _random;
  final BackupCryptography _cryptography;
  final VaultBackupArchiveVerifier _verifier;

  /// Creates, reopens, verifies, and atomically publishes one archive.
  Future<VaultBackupResult> create(VaultBackupRequest request) async {
    if (!request.outputFile.path.endsWith('.cvault') ||
        request.outputFile.existsSync() ||
        request.vaultHkdfSalt.length != 32 ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(request.vaultId)) {
      throw const BackupCreationFailure();
    }
    request.outputFile.parent.createSync(recursive: true);
    request.workingDirectory.createSync(recursive: true);
    final partial = File('${request.outputFile.path}.partial');
    final snapshot = File(
      '${request.workingDirectory.path}/${request.generationId.value}.snapshot',
    );
    if (partial.existsSync()) partial.deleteSync();
    if (snapshot.existsSync()) snapshot.deleteSync();
    final stopwatch = Stopwatch()..start();
    var published = false;
    try {
      final snapshotResult = await _snapshotService.createSnapshot(
        generationId: request.generationId,
        outputPath: snapshot.path,
      );
      await _setGenerationStatus(
        request.generationId.value,
        'SNAPSHOT_CREATED',
      );
      final snapshotDigest = await sha256File(snapshot);
      final objectIds = await _inventory(request.generationId.value);
      final objects = <BackupManifestObject>[];
      for (final objectId in objectIds) {
        final file = File('${_objectsDirectory.path}/$objectId.bin');
        if (!file.existsSync()) {
          throw const BackupCreationFailure();
        }
        objects.add(
          BackupManifestObject(
            objectId: objectId,
            encryptedSize: file.lengthSync(),
            encryptedSha256: await sha256File(file),
          ),
        );
      }
      objects.sort((left, right) => left.objectId.compareTo(right.objectId));
      final pipelineVersions = await _pipelineVersions();
      final databaseSchemaVersion = await _databaseSession.read(
        (database) async => database.schemaVersion,
      );
      final salt = await _randomExact(16);
      final header = BackupPublicHeader(
        kdfParameters: request.kdfParameters,
        kdfSalt: salt,
      );
      final headerBytes = BackupPublicHeaderCodec.encode(header);
      final recovery = await _cryptography.createRecoveryEnvelope(
        recoveryPassphrase: request.recoveryPassphrase,
        header: header,
        canonicalHeaderBytes: headerBytes,
        masterKey: request.masterKey,
        vaultHkdfSalt: request.vaultHkdfSalt,
      );
      final recoveryBytes = BackupRecoveryEnvelopeCodec.encode(recovery);
      final manifest = BackupManifest(
        generationId: request.generationId.value,
        vaultId: request.vaultId,
        createdAt: DateTime.now().toUtc(),
        databaseSchemaVersion: databaseSchemaVersion,
        encryptionFormatVersion: 1,
        objectFormatVersion: 1,
        backupFormatVersion: 1,
        minimumReaderVersion: 1,
        snapshotSize: snapshotResult.encryptedBytes,
        snapshotSha256: snapshotDigest,
        objects: objects,
        requiredAlgorithmVersions: const <int>[1],
        pipelineVersions: pipelineVersions,
      );
      final manifestBytes = BackupManifestCodec.encode(manifest);
      final derived = await VaultKeyHierarchy().deriveAll(
        masterKey: request.masterKey,
        vaultSalt: request.vaultHkdfSalt,
      );
      final Uint8List encryptedManifest;
      try {
        encryptedManifest = await _cryptography.encryptManifest(
          canonicalManifestBytes: manifestBytes,
          backupKey: derived[VaultSubkeyContext.backup],
          canonicalHeaderBytes: headerBytes,
          recoveryEnvelopeBytes: recoveryBytes,
        );
      } finally {
        derived.destroy();
      }
      await _setGenerationStatus(request.generationId.value, 'STREAMING');
      final entries = <CvaultEntrySource>[
        await CvaultEntrySource.bytes('header.cbor', headerBytes),
        await CvaultEntrySource.bytes(
          'recovery-envelope.cbor',
          recoveryBytes,
        ),
        await CvaultEntrySource.bytes(
          'encrypted-manifest.bin',
          encryptedManifest,
        ),
        await _fileEntry('database/snapshot.bin', snapshot, snapshotDigest),
        for (final object in objects)
          await _fileEntry(
            'objects/${object.objectId}.bin',
            File('${_objectsDirectory.path}/${object.objectId}.bin'),
            object.encryptedSha256,
          ),
      ];
      await CvaultArchiveWriter.write(partial, entries);
      await _setGenerationStatus(request.generationId.value, 'VERIFYING');
      final unlocked = await _verifier.unlockAndVerify(
        archive: partial,
        recoveryPassphrase: request.recoveryPassphrase,
      );
      unlocked.destroy();
      partial.renameSync(request.outputFile.path);
      published = true;
      await _databaseSession.write((database) async {
        await database.customStatement(
          '''
          UPDATE backup_generations
          SET status = 'COMPLETED', completed_at = ?, verified_at = ?,
              archive_path_token = ?
          WHERE id = ?
          ''',
          <Object>[
            DateTime.now().toUtc().millisecondsSinceEpoch,
            DateTime.now().toUtc().millisecondsSinceEpoch,
            'archive:${request.generationId.value}',
            request.generationId.value,
          ],
        );
      });
      stopwatch.stop();
      return VaultBackupResult(
        generationId: request.generationId.value,
        archive: request.outputFile,
        archiveBytes: request.outputFile.lengthSync(),
        objectCount: objects.length,
        elapsed: stopwatch.elapsed,
      );
    } on BackupFailure {
      if (published && request.outputFile.existsSync()) {
        request.outputFile.deleteSync();
      }
      await _markFailed(request.generationId.value);
      rethrow;
    } on Object catch (error) {
      if (published && request.outputFile.existsSync()) {
        request.outputFile.deleteSync();
      }
      await _markFailed(request.generationId.value);
      throw BackupCreationFailure(cause: error);
    } finally {
      if (partial.existsSync()) partial.deleteSync();
      if (snapshot.existsSync()) snapshot.deleteSync();
    }
  }

  Future<List<String>> _inventory(String generationId) =>
      _databaseSession.read((database) async {
        final rows = await database
            .customSelect(
              'SELECT object_id FROM backup_generation_objects '
              'WHERE generation_id = ? ORDER BY object_id',
              variables: <Variable<Object>>[Variable<String>(generationId)],
            )
            .get();
        return rows.map((row) => row.read<String>('object_id')).toList();
      });

  Future<List<int>> _pipelineVersions() =>
      _databaseSession.read((database) async {
        final rows = await database
            .customSelect(
              'SELECT version FROM pipeline_versions ORDER BY version',
            )
            .get();
        return rows.map((row) => row.read<int>('version')).toList();
      });

  Future<void> _setGenerationStatus(String generationId, String status) =>
      _databaseSession.write((database) async {
        await database.customStatement(
          'UPDATE backup_generations SET status = ? WHERE id = ?',
          <Object>[status, generationId],
        );
      });

  Future<void> _markFailed(String generationId) async {
    try {
      await _databaseSession.write((database) async {
        await database.customStatement(
          "UPDATE backup_generations SET status = 'FAILED', "
          "error_code = 'BACKUP_FAILED' WHERE id = ?",
          <Object>[generationId],
        );
      });
    } on Object {
      // Preserve the original failure.
    }
  }

  Future<Uint8List> _randomExact(int length) async {
    final bytes = await _random.secureBytes(length);
    if (bytes.length != length) throw const BackupCreationFailure();
    return Uint8List.fromList(bytes);
  }

  static Future<CvaultEntrySource> _fileEntry(
    String name,
    File file,
    List<int> digest,
  ) async => CvaultEntrySource(
    name: name,
    length: file.lengthSync(),
    sha256: Uint8List.fromList(digest),
    open: file.openRead,
  );
}

bool _equal(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
