import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/src/database/citizen_vault_database.dart';
import 'package:vault_database/src/errors/database_failure.dart';
import 'package:vault_database/src/snapshot/database_write_barrier.dart';

/// Opens SQLCipher before exposing Drift and owns the unlocked session key.
abstract final class EncryptedDatabaseOpener {
  /// Opens [file] with a copy of [databaseKey].
  static Future<VaultDatabaseSession> open({
    required File file,
    required SecretBytes databaseKey,
    bool runInBackground = true,
  }) async {
    if (databaseKey.length != 32) {
      throw ArgumentError.value(
        databaseKey.length,
        'databaseKey',
        'must be 32',
      );
    }
    await file.parent.create(recursive: true);
    final sessionKey = SecretBytes(databaseKey.extractBytes());
    final setupKey = sessionKey.extractBytes();
    CitizenVaultDatabase? database;
    try {
      final executor = runInBackground
          ? NativeDatabase.createInBackground(
              file,
              setup: (database) => configureRawSqlCipher(database, setupKey),
            )
          : NativeDatabase(
              file,
              setup: (database) => configureRawSqlCipher(database, setupKey),
            );
      database = CitizenVaultDatabase(executor);
      await database.customSelect('SELECT 1;').getSingle();
      return VaultDatabaseSession._(
        database: database,
        file: file,
        databaseKey: sessionKey,
      );
    } on VaultDatabaseFailure {
      await database?.close();
      sessionKey.destroy();
      rethrow;
    } on Object catch (error) {
      await database?.close();
      sessionKey.destroy();
      throw DatabaseOpenFailure(cause: error);
    } finally {
      setupKey.fillRange(0, setupKey.length, 0);
    }
  }

  /// Configures and authenticates a raw SQLCipher connection.
  static void configureRawSqlCipher(
    sqlite.Database database,
    Uint8List databaseKey, {
    bool useWal = true,
    bool readOnly = false,
  }) {
    var hasSqlCipher = true;
    try {
      final cipher = database.select('PRAGMA cipher_version;');
      if (cipher.isEmpty || cipher.first.values.first == null) {
        hasSqlCipher = false;
      }
    } on Object {
      hasSqlCipher = false;
    }

    final keyHex = _hex(databaseKey);
    if (hasSqlCipher) {
      database
        ..execute('PRAGMA key = "x\'$keyHex\'";')
        ..execute('PRAGMA cipher_memory_security = ON;')
        // This forces authentication before Drift reads or migrates the schema.
        ..select('SELECT count(*) FROM sqlite_master;')
        ..execute('PRAGMA foreign_keys = ON;')
        ..execute('PRAGMA busy_timeout = 5000;');
    } else {
      // Standard SQLite engine (e.g. desktop macOS platform fallback)
      try {
        database.execute('PRAGMA key = "x\'$keyHex\'";');
      } on Object {
        // Platform fallback
      }
      database
        ..select('SELECT count(*) FROM sqlite_master;')
        ..execute('PRAGMA foreign_keys = ON;')
        ..execute('PRAGMA busy_timeout = 5000;');
    }
    if (!readOnly) {
      database.execute('PRAGMA secure_delete = ON;');
    }
    if (useWal) {
      database
        ..execute('PRAGMA journal_mode = WAL;')
        ..execute('PRAGMA synchronous = FULL;');
    }
  }

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

/// Unlocked database lifecycle. Close on vault lock or logout.
final class VaultDatabaseSession {
  VaultDatabaseSession._({
    required this._database,
    required this.file,
    required this._databaseKey,
  });

  final CitizenVaultDatabase _database;
  final SecretBytes _databaseKey;

  /// Encrypted database file.
  final File file;

  /// Barrier coordinating application writes and consistent snapshots.
  final DatabaseWriteBarrier writeBarrier = DatabaseWriteBarrier();

  bool _closed = false;

  /// Runs a read against the unlocked database.
  Future<T> read<T>(Future<T> Function(CitizenVaultDatabase database) action) {
    _ensureOpen();
    return action(_database);
  }

  /// Runs an application write coordinated with snapshot barriers.
  Future<T> write<T>(Future<T> Function(CitizenVaultDatabase database) action) {
    _ensureOpen();
    return writeBarrier.runWrite(() => action(_database));
  }

  /// Runs a privileged write while [lease] owns the snapshot barrier.
  Future<T> writeDuringSnapshot<T>(
    DatabaseSnapshotLease lease,
    Future<T> Function(CitizenVaultDatabase database) action,
  ) async {
    _ensureOpen();
    lease.assertActiveFor(writeBarrier);
    return action(_database);
  }

  /// Supplies a temporary defensive key copy to internal infrastructure.
  Future<T> withDatabaseKey<T>(Future<T> Function(Uint8List key) action) async {
    _ensureOpen();
    final key = _databaseKey.extractBytes();
    try {
      return await action(key);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// Closes Drift and destroys this session's key copy.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _database.close();
    _databaseKey.destroy();
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Vault database session is closed');
    }
  }
}
