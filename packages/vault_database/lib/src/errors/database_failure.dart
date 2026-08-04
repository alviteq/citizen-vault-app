/// Base class for expected encrypted database failures.
sealed class VaultDatabaseFailure implements Exception {
  /// Creates a safe failure with an optional internal cause.
  const VaultDatabaseFailure(this.code, {this.cause});

  /// Stable machine-readable code.
  final String code;

  /// Internal cause. Never expose this directly to users or logs.
  final Object? cause;

  @override
  String toString() => 'VaultDatabaseFailure($code)';
}

/// SQLCipher or the database file could not be opened safely.
final class DatabaseOpenFailure extends VaultDatabaseFailure {
  /// Creates the failure.
  const DatabaseOpenFailure({super.cause}) : super('database_open_failed');
}

/// The linked SQLite library does not provide SQLCipher.
final class SqlCipherUnavailableFailure extends VaultDatabaseFailure {
  /// Creates the failure.
  const SqlCipherUnavailableFailure({super.cause})
    : super('sqlcipher_unavailable');
}

/// A schema migration failed and was rolled back.
final class DatabaseMigrationFailure extends VaultDatabaseFailure {
  /// Creates the failure.
  const DatabaseMigrationFailure({super.cause})
    : super('database_migration_failed');
}

/// SQLite, SQLCipher, FTS, or foreign-key integrity failed.
final class DatabaseIntegrityFailure extends VaultDatabaseFailure {
  /// Creates the failure with a safe [check] identifier.
  const DatabaseIntegrityFailure(this.check, {super.cause})
    : super('database_integrity_failed');

  /// Failed check identifier.
  final String check;
}

/// A consistent encrypted snapshot could not be created or verified.
final class DatabaseSnapshotFailure extends VaultDatabaseFailure {
  /// Creates the failure.
  const DatabaseSnapshotFailure({super.cause})
    : super('database_snapshot_failed');
}
