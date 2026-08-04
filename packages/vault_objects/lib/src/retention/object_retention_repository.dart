import 'package:drift/drift.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_objects/src/model/object_id.dart';
import 'package:vault_objects/src/model/object_store_models.dart';

/// Persisted metadata required to compare a decrypted object's plaintext hash.
final class PersistedObjectIntegrity {
  /// Creates metadata.
  PersistedObjectIntegrity({
    required List<int> plaintextSha256,
    required this.plaintextSize,
    required this.encryptedSize,
    required this.chunkCount,
    required this.objectFormatVersion,
    required this.keyVersion,
  }) : plaintextSha256 = Uint8List.fromList(plaintextSha256);

  /// Expected plaintext SHA-256.
  final Uint8List plaintextSha256;

  /// Expected plaintext bytes.
  final int plaintextSize;

  /// Expected encrypted file bytes.
  final int encryptedSize;

  /// Expected chunk count.
  final int chunkCount;

  /// Expected format version.
  final int objectFormatVersion;

  /// Expected File Root Key version.
  final int keyVersion;
}

/// Database boundary for object commit, verification, and safe retention.
abstract interface class ObjectRetentionRepository {
  /// Records metadata only after encrypted publication succeeds.
  Future<void> registerCommitted(EncryptedObjectWriteResult result);

  /// Returns expected integrity metadata when this object is registered.
  Future<PersistedObjectIntegrity?> integrityFor(ObjectId objectId);

  /// Records a verification state without leaking paths or content.
  Future<void> recordVerification(
    ObjectId objectId,
    ObjectVerificationStatus status,
  );

  /// Creates or refreshes a tombstone whose retention starts now.
  Future<void> markForDeletion(ObjectId objectId);

  /// Runs [deleteFile] inside the final database eligibility transaction.
  Future<bool> deleteIfEligible(
    ObjectId objectId,
    Future<void> Function() deleteFile,
  );
}

/// SQLCipher-backed object reference and tombstone repository.
final class DatabaseObjectRetentionRepository
    implements ObjectRetentionRepository {
  /// Creates the repository for an unlocked database session.
  const DatabaseObjectRetentionRepository(
    this._session, {
    this.retentionPeriod = const Duration(days: 30),
  });

  final VaultDatabaseSession _session;

  /// Minimum time between tombstoning and physical deletion.
  final Duration retentionPeriod;

  @override
  Future<void> registerCommitted(EncryptedObjectWriteResult result) =>
      _session.write((database) async {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await database.customStatement(
          '''
          INSERT INTO object_references(
            object_id, reference_count, plaintext_sha256, plaintext_size,
            encrypted_size, object_format_version, key_version, chunk_count,
            verification_status, last_verified_at, created_at,
            last_referenced_at
          ) VALUES (?, 0, ?, ?, ?, ?, ?, ?, 'VERIFIED', ?, ?, ?)
          ''',
          <Object>[
            result.objectId.value,
            result.plaintextSha256,
            result.plaintextSize,
            result.encryptedSize,
            result.objectFormatVersion,
            result.keyVersion,
            result.chunkCount,
            now,
            now,
            now,
          ],
        );
      });

  @override
  Future<PersistedObjectIntegrity?> integrityFor(ObjectId objectId) =>
      _session.read((database) async {
        final rows = await database
            .customSelect(
              '''
          SELECT plaintext_sha256, plaintext_size, encrypted_size,
                 chunk_count, object_format_version, key_version
          FROM object_references WHERE object_id = ?
          ''',
              variables: <Variable<Object>>[Variable<String>(objectId.value)],
            )
            .get();
        if (rows.isEmpty) return null;
        final row = rows.single;
        return PersistedObjectIntegrity(
          plaintextSha256: row.read<Uint8List>('plaintext_sha256'),
          plaintextSize: row.read<int>('plaintext_size'),
          encryptedSize: row.read<int>('encrypted_size'),
          chunkCount: row.read<int>('chunk_count'),
          objectFormatVersion: row.read<int>('object_format_version'),
          keyVersion: row.read<int>('key_version'),
        );
      });

  @override
  Future<void> recordVerification(
    ObjectId objectId,
    ObjectVerificationStatus status,
  ) => _session.write((database) async {
    await database.customStatement(
      '''
      UPDATE object_references
      SET verification_status = ?, last_verified_at = ?
      WHERE object_id = ?
      ''',
      <Object>[
        _statusValue(status),
        DateTime.now().toUtc().millisecondsSinceEpoch,
        objectId.value,
      ],
    );
  });

  @override
  Future<void> markForDeletion(ObjectId objectId) =>
      _session.write((database) async {
        final now = DateTime.now().toUtc();
        final eligible = now.add(retentionPeriod).millisecondsSinceEpoch;
        await database.customStatement(
          '''
          INSERT INTO object_tombstones(
            object_id, reason, tombstoned_at, eligible_for_deletion_at
          )
          SELECT object_id, 'UNREFERENCED', ?, ? FROM object_references
          WHERE object_id = ?
          ON CONFLICT(object_id) DO UPDATE SET
            reason = excluded.reason,
            tombstoned_at = excluded.tombstoned_at,
            eligible_for_deletion_at = excluded.eligible_for_deletion_at,
            deleted_at = NULL
          ''',
          <Object>[now.millisecondsSinceEpoch, eligible, objectId.value],
        );
      });

  @override
  Future<bool> deleteIfEligible(
    ObjectId objectId,
    Future<void> Function() deleteFile,
  ) => _session.write(
    (database) => database.transaction(() async {
      final row = await database
          .customSelect(
            '''
        SELECT
          COALESCE((SELECT reference_count FROM object_references
                    WHERE object_id = ?), 0) AS references_count,
          (SELECT count(*) FROM documents
             WHERE primary_object_id = ? AND deleted_at IS NULL) AS documents,
          (SELECT count(*) FROM document_assets
             WHERE object_id = ? AND deleted_at IS NULL) AS assets,
          (SELECT count(*) FROM backup_generation_objects
             WHERE object_id = ?) AS backups,
          (SELECT count(*) FROM object_tombstones
             WHERE object_id = ? AND deleted_at IS NULL
               AND eligible_for_deletion_at <= ?) AS eligible
        ''',
            variables: <Variable<Object>>[
              Variable<String>(objectId.value),
              Variable<String>(objectId.value),
              Variable<String>(objectId.value),
              Variable<String>(objectId.value),
              Variable<String>(objectId.value),
              Variable<int>(DateTime.now().toUtc().millisecondsSinceEpoch),
            ],
          )
          .getSingle();
      final eligible =
          row.read<int>('references_count') == 0 &&
          row.read<int>('documents') == 0 &&
          row.read<int>('assets') == 0 &&
          row.read<int>('backups') == 0 &&
          row.read<int>('eligible') == 1;
      if (!eligible) return false;

      await deleteFile();
      await database.customStatement(
        'DELETE FROM object_tombstones WHERE object_id = ?',
        <Object>[objectId.value],
      );
      await database.customStatement(
        'DELETE FROM object_references WHERE object_id = ?',
        <Object>[objectId.value],
      );
      return true;
    }),
  );

  static String _statusValue(
    ObjectVerificationStatus status,
  ) => switch (status) {
    ObjectVerificationStatus.unverified => 'UNVERIFIED',
    ObjectVerificationStatus.verified => 'VERIFIED',
    ObjectVerificationStatus.corrupted => 'CORRUPTED',
    ObjectVerificationStatus.missing => 'MISSING',
    ObjectVerificationStatus.unsupportedFormat => 'UNSUPPORTED_FORMAT',
  };
}
