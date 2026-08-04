import 'dart:io';

import 'package:vault_backup/src/archive/cvault_archive.dart';
import 'package:vault_backup/src/errors/backup_failure.dart';
import 'package:vault_backup/src/model/backup_models.dart';
import 'package:vault_backup/src/service/vault_backup_service.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_objects/vault_objects.dart';

/// Platform capacity gate required before extracting a staged vault.
// The interface is an injectable platform security boundary.
// ignore: one_member_abstracts
abstract interface class RestoreStoragePolicy {
  /// Throws when [requiredBytes] cannot be safely staged under [parent].
  Future<void> ensureCapacity(Directory parent, int requiredBytes);
}

/// Provisions portable metadata only after restored content verifies.
// The interface is an injectable native security boundary.
// ignore: one_member_abstracts
abstract interface class RestoredVaultProvisioner {
  /// Writes recovery metadata into [stagingDirectory] before activation.
  Future<void> provision({
    required SecretBytes masterKey,
    required List<int> vaultHkdfSalt,
    required String recoveryPassphrase,
    required String vaultId,
    required Directory stagingDirectory,
  });
}

/// Future canonical logical export boundary for long-term schema portability.
abstract interface class CanonicalLogicalExportService {
  /// Streams encrypted canonical logical records for a verified database.
  Stream<List<int>> export(VaultDatabaseSession session);

  /// Imports canonical logical records into a new staged database.
  Future<void> import(
    Stream<List<int>> encryptedRecords,
    VaultDatabaseSession stagedSession,
  );
}

/// Restores a verified archive into staging before atomically switching active.
final class BackupRestoreService {
  /// Creates the restore service with required platform policy boundaries.
  const BackupRestoreService({
    required VaultBackupArchiveVerifier archiveVerifier,
    required RestoreStoragePolicy capacityPolicy,
    required RestoredVaultProvisioner provisioner,
    required CryptographicRandom randomSource,
  }) : _verifier = archiveVerifier,
       _storagePolicy = capacityPolicy,
       _vaultProvisioner = provisioner,
       _random = randomSource;

  final VaultBackupArchiveVerifier _verifier;
  final RestoreStoragePolicy _storagePolicy;
  final RestoredVaultProvisioner _vaultProvisioner;
  final CryptographicRandom _random;

  /// Performs a no-network staged restore and returns the activated directory.
  Future<VaultRestoreResult> restore({
    required File archive,
    required String recoveryPassphrase,
    required Directory vaultsParent,
    String activeDirectoryName = 'active_vault',
  }) async {
    if (!archive.existsSync()) {
      throw const InvalidBackupFormatFailure('archive_missing');
    }
    await _storagePolicy.ensureCapacity(
      vaultsParent,
      archive.lengthSync() * 2,
    );
    final unlocked = await _verifier.unlockAndVerify(
      archive: archive,
      recoveryPassphrase: recoveryPassphrase,
    );
    Directory? staging;
    VaultDatabaseSession? restoredDatabase;
    VaultFileRootKey? fileRootKey;
    VaultDerivedKeys? derived;
    try {
      final manifest = unlocked.manifest;
      final requiredBytes = unlocked.entries.fold<int>(
        0,
        (total, entry) => total + entry.length,
      );
      await _storagePolicy.ensureCapacity(vaultsParent, requiredBytes * 2);
      vaultsParent.createSync(recursive: true);
      final stagedVault = Directory(
        '${vaultsParent.path}/.restore-${manifest.generationId}.partial',
      );
      staging = stagedVault;
      if (stagedVault.existsSync()) stagedVault.deleteSync(recursive: true);
      stagedVault.createSync(recursive: true);
      final destinations = <String, File>{
        'database/snapshot.bin': File('${stagedVault.path}/vault.db'),
        for (final object in manifest.objects)
          'objects/${object.objectId}.bin': File(
            '${stagedVault.path}/objects/${object.objectId}.bin',
          ),
      };
      await CvaultArchiveReader(archive).extract(destinations);
      derived = await VaultKeyHierarchy().deriveAll(
        masterKey: unlocked.secrets.masterKey,
        vaultSalt: unlocked.secrets.vaultHkdfSalt,
      );
      final databaseKey = SecretBytes(
        derived[VaultSubkeyContext.database].extractBytes(),
      );
      try {
        restoredDatabase = await EncryptedDatabaseOpener.open(
          file: destinations['database/snapshot.bin']!,
          databaseKey: databaseKey,
          runInBackground: false,
        );
      } finally {
        databaseKey.destroy();
      }
      await restoredDatabase.write(
        (database) => database.rebuildFtsIndex(),
      );
      await restoredDatabase.read(DatabaseIntegrityService.verify);
      await _verifyDatabaseInventory(restoredDatabase, manifest);

      final fileRootBytes = derived[VaultSubkeyContext.fileRoot].extractBytes();
      try {
        fileRootKey = VaultFileRootKey.fromBytes(
          fileRootBytes,
          keyVersion: 1,
        );
      } finally {
        fileRootBytes.fillRange(0, fileRootBytes.length, 0);
      }
      final objectStore = FileEncryptedObjectStore(
        rootDirectory: stagedVault,
        random: _random,
        retentionRepository: DatabaseObjectRetentionRepository(
          restoredDatabase,
        ),
      );
      for (final object in manifest.objects) {
        await objectStore.verify(
          objectId: ObjectId.parse(object.objectId),
          fileRootKey: fileRootKey,
        );
      }
      await _vaultProvisioner.provision(
        masterKey: unlocked.secrets.masterKey,
        vaultHkdfSalt: unlocked.secrets.vaultHkdfSalt,
        recoveryPassphrase: recoveryPassphrase,
        vaultId: manifest.vaultId,
        stagingDirectory: stagedVault,
      );
      await restoredDatabase.close();
      restoredDatabase = null;

      final active = Directory('${vaultsParent.path}/$activeDirectoryName');
      Directory? previous;
      if (active.existsSync()) {
        previous = Directory(
          '${vaultsParent.path}/$activeDirectoryName.previous.'
          '${DateTime.now().toUtc().millisecondsSinceEpoch}',
        );
        active.renameSync(previous.path);
      }
      try {
        stagedVault.renameSync(active.path);
      } on Object {
        if (previous != null && previous.existsSync() && !active.existsSync()) {
          previous.renameSync(active.path);
        }
        rethrow;
      }
      return VaultRestoreResult(
        vaultId: manifest.vaultId,
        activeDirectory: active,
        previousDirectory: previous,
        objectCount: manifest.objects.length,
      );
    } on BackupFailure {
      rethrow;
    } on Object catch (error) {
      throw BackupRestoreFailure(cause: error);
    } finally {
      fileRootKey?.destroy();
      derived?.destroy();
      await restoredDatabase?.close();
      unlocked.destroy();
      if (staging != null && staging.existsSync()) {
        staging.deleteSync(recursive: true);
      }
    }
  }

  static Future<void> _verifyDatabaseInventory(
    VaultDatabaseSession session,
    BackupManifest manifest,
  ) async {
    final ids = await session.read((database) async {
      final rows = await database
          .customSelect(
            'SELECT object_id FROM object_references '
            'WHERE reference_count > 0 ORDER BY object_id',
          )
          .get();
      return rows.map((row) => row.read<String>('object_id')).toList();
    });
    final expected = manifest.objects.map((object) => object.objectId).toList();
    if (!_listEqual(ids, expected)) {
      throw const BackupVerificationFailure('database_object_inventory');
    }
    final pipelineVersions = await session.read((database) async {
      final rows = await database
          .customSelect(
            'SELECT version FROM pipeline_versions ORDER BY version',
          )
          .get();
      return rows.map((row) => row.read<int>('version')).toList();
    });
    if (!_listEqual(pipelineVersions, manifest.pipelineVersions)) {
      throw const BackupVerificationFailure('database_pipeline_inventory');
    }
  }
}

bool _listEqual<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
