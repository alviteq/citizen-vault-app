import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vault_crypto/vault_crypto.dart';

/// Canonical public information required before recovery-key derivation.
@immutable
final class BackupPublicHeader {
  /// Creates a version-one header.
  BackupPublicHeader({
    required this.kdfParameters,
    required List<int> kdfSalt,
  }) : kdfSalt = Uint8List.fromList(kdfSalt);

  static const int currentVersion = 1;
  static const String formatIdentifier = 'citizen-vault-backup';
  static const String recoveryEnvelopeEntry = 'recovery-envelope.cbor';
  static const String encryptedManifestEntry = 'encrypted-manifest.bin';
  static const int aes256GcmAlgorithm = 1;
  static const int cvaultContainerAlgorithm = 1;

  final RecoveryKdfParameters kdfParameters;
  final Uint8List kdfSalt;
}

/// Backup recovery envelope wrapping Master Vault Key plus HKDF salt.
@immutable
final class BackupRecoveryEnvelope {
  /// Creates the envelope.
  BackupRecoveryEnvelope({
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> authenticationTag,
  }) : nonce = Uint8List.fromList(nonce),
       ciphertext = Uint8List.fromList(ciphertext),
       authenticationTag = Uint8List.fromList(authenticationTag);

  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List authenticationTag;
}

/// One immutable encrypted object declared by the manifest.
@immutable
final class BackupManifestObject {
  /// Creates an object inventory entry.
  BackupManifestObject({
    required this.objectId,
    required this.encryptedSize,
    required List<int> encryptedSha256,
  }) : encryptedSha256 = Uint8List.fromList(encryptedSha256);

  final String objectId;
  final int encryptedSize;
  final Uint8List encryptedSha256;
}

/// Confidential canonical backup inventory.
@immutable
final class BackupManifest {
  /// Creates a manifest.
  BackupManifest({
    required this.generationId,
    required this.vaultId,
    required this.createdAt,
    required this.databaseSchemaVersion,
    required this.encryptionFormatVersion,
    required this.objectFormatVersion,
    required this.backupFormatVersion,
    required this.minimumReaderVersion,
    required this.snapshotSize,
    required List<int> snapshotSha256,
    required List<BackupManifestObject> objects,
    required List<int> requiredAlgorithmVersions,
    required List<int> pipelineVersions,
  }) : snapshotSha256 = Uint8List.fromList(snapshotSha256),
       objects = List<BackupManifestObject>.unmodifiable(objects),
       requiredAlgorithmVersions = List<int>.unmodifiable(
         requiredAlgorithmVersions,
       ),
       pipelineVersions = List<int>.unmodifiable(pipelineVersions);

  static const int currentVersion = 1;
  static const int minimumSupportedReader = 1;

  final String generationId;
  final String vaultId;
  final DateTime createdAt;
  final int databaseSchemaVersion;
  final int encryptionFormatVersion;
  final int objectFormatVersion;
  final int backupFormatVersion;
  final int minimumReaderVersion;
  final int snapshotSize;
  final Uint8List snapshotSha256;
  final List<BackupManifestObject> objects;
  final List<int> requiredAlgorithmVersions;
  final List<int> pipelineVersions;
}

/// Completed `.cvault` archive information.
final class VaultBackupResult {
  /// Creates a result.
  const VaultBackupResult({
    required this.generationId,
    required this.archive,
    required this.archiveBytes,
    required this.objectCount,
    required this.elapsed,
  });

  final String generationId;
  final File archive;
  final int archiveBytes;
  final int objectCount;
  final Duration elapsed;
}

/// Successfully staged and activated restored vault.
final class VaultRestoreResult {
  /// Creates a result.
  const VaultRestoreResult({
    required this.vaultId,
    required this.activeDirectory,
    required this.previousDirectory,
    required this.objectCount,
  });

  final String vaultId;
  final Directory activeDirectory;
  final Directory? previousDirectory;
  final int objectCount;
}

// Wire fields are exhaustively documented in docs/backup_format/README.md.
// ignore_for_file: public_member_api_docs
