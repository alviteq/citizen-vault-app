import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:vault_database/src/database/encrypted_database_opener.dart';
import 'package:vault_database/src/errors/database_failure.dart';
import 'package:vault_database/src/integrity/database_integrity_service.dart';

/// Validated backup-generation identifier.
final class BackupGenerationId {
  /// Creates an identifier.
  BackupGenerationId(this.value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'value', 'invalid generation id');
    }
  }

  /// Stable logical value.
  final String value;
}

/// Completed encrypted snapshot metadata.
final class DatabaseSnapshotResult {
  /// Creates a result.
  const DatabaseSnapshotResult({
    required this.generationId,
    required this.outputPath,
    required this.encryptedBytes,
    required this.elapsed,
  });

  /// Backup generation.
  final BackupGenerationId generationId;

  /// Caller-selected runtime output path. It is never persisted in the vault.
  final String outputPath;

  /// Resulting encrypted file length.
  final int encryptedBytes;

  /// Time spent behind the database write barrier.
  final Duration elapsed;
}

/// Consistent encrypted online-backup interface.
abstract interface class DatabaseSnapshotService {
  /// Creates, verifies, and atomically publishes an encrypted snapshot.
  Future<DatabaseSnapshotResult> createSnapshot({
    required BackupGenerationId generationId,
    required String outputPath,
  });

  /// Independently opens and verifies a snapshot with the active database key.
  Future<void> verifySnapshot(String snapshotPath);
}

/// SQLite online-backup implementation coordinated by an application barrier.
final class SqlCipherDatabaseSnapshotService
    implements DatabaseSnapshotService {
  /// Creates the service for an unlocked session.
  const SqlCipherDatabaseSnapshotService(this._session);

  final VaultDatabaseSession _session;

  @override
  Future<DatabaseSnapshotResult> createSnapshot({
    required BackupGenerationId generationId,
    required String outputPath,
  }) async {
    final output = File(outputPath);
    if (output.existsSync()) {
      throw const DatabaseSnapshotFailure();
    }
    output.parent.createSync(recursive: true);
    final partial = File('$outputPath.partial');
    if (partial.existsSync()) {
      partial.deleteSync();
    }
    final stopwatch = Stopwatch()..start();
    final lease = await _session.writeBarrier.acquireSnapshot();
    try {
      await _session.writeDuringSnapshot(lease, (database) async {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await database.customStatement(
          '''
          INSERT INTO backup_generations(
            id, status, snapshot_path_token, object_count, created_at
          ) VALUES (?, ?, ?, 0, ?)
          ''',
          <Object>[
            generationId.value,
            'CREATING',
            'snapshot:${generationId.value}',
            now,
          ],
        );
        await database.customStatement(
          '''
          INSERT INTO backup_generation_objects(
            generation_id, object_id, plaintext_sha256, encrypted_size
          ) SELECT ?, object_id, plaintext_sha256, encrypted_size
          FROM object_references WHERE reference_count > 0
          ''',
          <Object>[generationId.value],
        );
        await database.customStatement(
          '''
          UPDATE backup_generations SET object_count = (
            SELECT count(*) FROM backup_generation_objects
            WHERE generation_id = ?
          ) WHERE id = ?
          ''',
          <Object>[generationId.value, generationId.value],
        );
      });

      await _session.withDatabaseKey((key) async {
        final source = sqlite.sqlite3.open(
          _session.file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        sqlite.Database? destination;
        try {
          EncryptedDatabaseOpener.configureRawSqlCipher(
            source,
            key,
            useWal: false,
            readOnly: true,
          );
          destination = sqlite.sqlite3.open(partial.path);
          EncryptedDatabaseOpener.configureRawSqlCipher(
            destination,
            key,
            useWal: false,
          );
          await for (final _ in source.backup(destination, nPage: 128)) {
            // The backup stream yields progress while copying bounded pages.
          }
        } finally {
          destination?.close();
          source.close();
        }
      });

      await _verifyFile(partial);
      partial.renameSync(output.path);
      final completedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _session.writeDuringSnapshot(lease, (database) async {
        await database.customStatement(
          'UPDATE backup_generations SET status = ?, completed_at = ?, '
          'verified_at = ? WHERE id = ?',
          <Object>[
            'VERIFIED',
            completedAt,
            completedAt,
            generationId.value,
          ],
        );
      });
      stopwatch.stop();
      return DatabaseSnapshotResult(
        generationId: generationId,
        outputPath: output.path,
        encryptedBytes: output.lengthSync(),
        elapsed: stopwatch.elapsed,
      );
    } on Object catch (error) {
      if (partial.existsSync()) {
        partial.deleteSync();
      }
      try {
        await _session.writeDuringSnapshot(lease, (database) async {
          await database.customStatement(
            'UPDATE backup_generations SET status = ?, error_code = ? '
            'WHERE id = ?',
            <Object>['FAILED', 'SNAPSHOT_FAILED', generationId.value],
          );
        });
      } on Object {
        // Preserve the original snapshot failure.
      }
      if (error is VaultDatabaseFailure) {
        rethrow;
      }
      throw DatabaseSnapshotFailure(cause: error);
    } finally {
      if (lease.isActive) {
        lease.release();
      }
    }
  }

  @override
  Future<void> verifySnapshot(String snapshotPath) =>
      _verifyFile(File(snapshotPath));

  Future<void> _verifyFile(File file) async {
    if (!file.existsSync() || file.lengthSync() < 4096) {
      throw const DatabaseSnapshotFailure();
    }
    await _session.withDatabaseKey((key) async {
      final database = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        EncryptedDatabaseOpener.configureRawSqlCipher(
          database,
          key,
          useWal: false,
          readOnly: true,
        );
        DatabaseIntegrityService.verifyRaw(database);
      } finally {
        database.close();
      }
    });
  }

  /// Filename only, useful for diagnostics without exposing sandbox paths.
  static String safeOutputName(String outputPath) => p.basename(outputPath);
}
