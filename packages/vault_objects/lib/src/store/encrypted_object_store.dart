import 'package:vault_objects/src/cancellation/cancellation_token.dart';
import 'package:vault_objects/src/format/object_format_v1.dart';
import 'package:vault_objects/src/model/object_id.dart';
import 'package:vault_objects/src/model/object_store_models.dart';
import 'package:vault_objects/src/model/vault_file_root_key.dart';

/// Streaming encrypted object-store contract.
abstract interface class EncryptedObjectStore {
  /// Encrypts, verifies, and atomically publishes one immutable object.
  Future<EncryptedObjectWriteResult> put({
    required Stream<List<int>> plaintext,
    required ObjectId objectId,
    required VaultFileRootKey fileRootKey,
    int chunkSize = ObjectFormatV1.defaultChunkSize,
    CancellationToken? cancellationToken,
  });

  /// Authenticates chunks before yielding plaintext or a selected range.
  Stream<List<int>> read({
    required ObjectId objectId,
    required VaultFileRootKey fileRootKey,
    ByteRange? range,
    CancellationToken? cancellationToken,
  });

  /// Authenticates the complete file and checks persisted plaintext metadata.
  Future<void> verify({
    required ObjectId objectId,
    required VaultFileRootKey fileRootKey,
    CancellationToken? cancellationToken,
  });

  /// Whether the encrypted object file exists.
  Future<bool> exists(ObjectId objectId);

  /// Creates or refreshes a retention tombstone.
  Future<void> markForDeletion(ObjectId objectId);

  /// Deletes only when database references and retention permit it.
  Future<void> deleteWhenUnreferenced(ObjectId objectId);

  /// Removes recognized partial files left by hard process termination.
  Future<int> cleanupInterruptedWrites();
}
