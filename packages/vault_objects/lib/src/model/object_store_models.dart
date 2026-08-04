import 'dart:typed_data';

import 'package:vault_objects/src/errors/object_store_failure.dart';
import 'package:vault_objects/src/model/object_id.dart';

/// Half-open plaintext byte range `[start, endExclusive)`.
final class ByteRange {
  /// Creates a validated range.
  const ByteRange({required this.start, required this.endExclusive});

  /// First requested plaintext offset.
  final int start;

  /// First plaintext offset not requested.
  final int endExclusive;

  /// Validates this range against the authenticated object size.
  void validate(int plaintextSize) {
    if (start < 0 || endExclusive <= start || endExclusive > plaintextSize) {
      throw const InvalidObjectInputFailure('byte_range');
    }
  }
}

/// Persisted verification state for one encrypted object.
enum ObjectVerificationStatus {
  /// The object has not been checked after creation/import.
  unverified,

  /// Every chunk and the plaintext hash were verified.
  verified,

  /// Authentication or structural verification failed.
  corrupted,

  /// The expected encrypted file is absent.
  missing,

  /// The file uses a future format.
  unsupportedFormat,
}

/// Metadata returned only after an object is verified and atomically published.
final class EncryptedObjectWriteResult {
  /// Creates the result.
  EncryptedObjectWriteResult({
    required this.objectId,
    required List<int> plaintextSha256,
    required this.plaintextSize,
    required this.encryptedSize,
    required this.chunkCount,
    required this.objectFormatVersion,
    required this.keyVersion,
  }) : plaintextSha256 = Uint8List.fromList(plaintextSha256);

  /// Logical object identifier.
  final ObjectId objectId;

  /// SHA-256 of the complete plaintext stream.
  final Uint8List plaintextSha256;

  /// Total plaintext bytes.
  final int plaintextSize;

  /// Total encrypted file bytes.
  final int encryptedSize;

  /// Number of independently authenticated chunks.
  final int chunkCount;

  /// Serialized format version.
  final int objectFormatVersion;

  /// File Root Key version that wraps the File Data Key.
  final int keyVersion;
}

/// Full verification result for one object.
final class EncryptedObjectVerificationResult {
  /// Creates the result.
  EncryptedObjectVerificationResult({
    required this.objectId,
    required List<int> plaintextSha256,
    required this.plaintextSize,
    required this.encryptedSize,
    required this.chunkCount,
    required this.objectFormatVersion,
    required this.keyVersion,
  }) : plaintextSha256 = Uint8List.fromList(plaintextSha256);

  /// Verified logical identifier.
  final ObjectId objectId;

  /// Recomputed plaintext SHA-256.
  final Uint8List plaintextSha256;

  /// Authenticated plaintext bytes.
  final int plaintextSize;

  /// Serialized file bytes.
  final int encryptedSize;

  /// Authenticated chunks.
  final int chunkCount;

  /// Serialized format version.
  final int objectFormatVersion;

  /// Header key version.
  final int keyVersion;
}
