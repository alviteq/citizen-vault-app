import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:vault_database/src/database/citizen_vault_database.dart';
import 'package:vault_database/src/errors/database_failure.dart';

/// Results from SQLCipher, SQLite, foreign-key, and FTS verification.
final class DatabaseIntegrityResult {
  /// Creates a result.
  const DatabaseIntegrityResult({
    required this.sqliteOk,
    required this.cipherOk,
    required this.foreignKeysOk,
    required this.ftsOk,
  });

  /// SQLite logical integrity.
  final bool sqliteOk;

  /// SQLCipher page authentication integrity.
  final bool cipherOk;

  /// Foreign-key consistency.
  final bool foreignKeysOk;

  /// Derived FTS consistency.
  final bool ftsOk;

  /// Whether every check passed.
  bool get isValid => sqliteOk && cipherOk && foreignKeysOk && ftsOk;
}

/// Runs fail-closed database integrity checks.
abstract final class DatabaseIntegrityService {
  /// Checks an open Drift database.
  static Future<DatabaseIntegrityResult> verify(
    CitizenVaultDatabase database,
  ) async {
    final sqliteOk = await _singleValueIsOk(
      database,
      'PRAGMA integrity_check;',
    );
    final cipherRows = await database
        .customSelect('PRAGMA cipher_integrity_check;')
        .get();
    final foreignKeyRows = await database
        .customSelect(
          'PRAGMA foreign_key_check;',
        )
        .get();
    final ftsOk = await database.verifyFtsIndex();
    final result = DatabaseIntegrityResult(
      sqliteOk: sqliteOk,
      cipherOk: cipherRows.isEmpty,
      foreignKeysOk: foreignKeyRows.isEmpty,
      ftsOk: ftsOk,
    );
    if (!result.isValid) {
      throw DatabaseIntegrityFailure(_failedCheck(result));
    }
    return result;
  }

  /// Checks a raw SQLCipher connection, used for independent snapshots.
  static void verifyRaw(sqlite.Database database) {
    final sqliteRows = database.select('PRAGMA integrity_check;');
    if (sqliteRows.length != 1 || sqliteRows.first.values.first != 'ok') {
      throw const DatabaseIntegrityFailure('sqlite');
    }
    if (database.select('PRAGMA cipher_integrity_check;').isNotEmpty) {
      throw const DatabaseIntegrityFailure('cipher');
    }
    if (database.select('PRAGMA foreign_key_check;').isNotEmpty) {
      throw const DatabaseIntegrityFailure('foreign_keys');
    }
  }

  static Future<bool> _singleValueIsOk(
    GeneratedDatabase database,
    String statement,
  ) async {
    final row = await database.customSelect(statement).getSingle();
    return row.data.values.single == 'ok';
  }

  static String _failedCheck(DatabaseIntegrityResult result) {
    if (!result.sqliteOk) return 'sqlite';
    if (!result.cipherOk) return 'cipher';
    if (!result.foreignKeysOk) return 'foreign_keys';
    return 'fts';
  }
}
