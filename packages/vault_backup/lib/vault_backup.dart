/// Portable encrypted backup and staged restore for Citizen Vault.
library;

export 'src/archive/cvault_archive.dart';
export 'src/crypto/backup_cryptography.dart';
export 'src/errors/backup_failure.dart';
export 'src/format/backup_codecs.dart';
export 'src/model/backup_models.dart';
export 'src/restore/backup_restore_service.dart';
export 'src/service/vault_backup_service.dart';

/// Package metadata for portable backup and restore.
abstract final class VaultBackupPackage {
  /// Public API version introduced by Milestone 4.
  static const String apiVersion = '0.5.0';
}
