/// Base class for safe backup and restore failures.
sealed class BackupFailure implements Exception {
  const BackupFailure(this.code, {this.cause});

  /// Stable machine-readable code.
  final String code;

  /// Internal-only cause; never include it in user-facing output.
  final Object? cause;

  @override
  String toString() => 'BackupFailure($code)';
}

/// A header, manifest, envelope, or archive structure is malformed.
final class InvalidBackupFormatFailure extends BackupFailure {
  /// Creates the failure with a safe reason identifier.
  const InvalidBackupFormatFailure(this.reason, {super.cause})
    : super('backup_format_invalid');

  final String reason;
}

/// The recovery credential or an authenticated backup component failed.
final class BackupAuthenticationFailure extends BackupFailure {
  /// Creates the generic authentication failure.
  const BackupAuthenticationFailure({super.cause})
    : super('backup_authentication_failed');
}

/// A supported reader cannot process the declared future version.
final class UnsupportedBackupVersionFailure extends BackupFailure {
  /// Creates the failure.
  const UnsupportedBackupVersionFailure() : super('backup_version_unsupported');
}

/// Archive creation failed before atomic publication.
final class BackupCreationFailure extends BackupFailure {
  /// Creates the failure.
  const BackupCreationFailure({super.cause}) : super('backup_creation_failed');
}

/// Archive inventory or digest verification failed.
final class BackupVerificationFailure extends BackupFailure {
  /// Creates the failure with a safe reason identifier.
  const BackupVerificationFailure(this.reason, {super.cause})
    : super('backup_verification_failed');

  final String reason;
}

/// Restore storage capacity is insufficient or unavailable.
final class InsufficientRestoreStorageFailure extends BackupFailure {
  /// Creates the failure.
  const InsufficientRestoreStorageFailure()
    : super('restore_storage_insufficient');
}

/// Staged restore failed without replacing the active vault.
final class BackupRestoreFailure extends BackupFailure {
  /// Creates the failure.
  const BackupRestoreFailure({super.cause}) : super('backup_restore_failed');
}

// Stable failure codes are documented at their declaring types.
// ignore_for_file: public_member_api_docs
