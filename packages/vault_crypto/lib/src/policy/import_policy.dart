import 'package:vault_crypto/src/errors/crypto_failure.dart';
import 'package:vault_crypto/src/kdf/kdf_parameters.dart';

/// Upper and lower bounds applied before processing untrusted imports.
final class VaultImportPolicy {
  /// Creates the production import policy.
  const VaultImportPolicy({
    this.maximumPublicHeaderBytes = 64 * 1024,
    this.maximumManifestBytes = 64 * 1024 * 1024,
    this.maximumArgon2MemoryKiB = 256 * 1024,
    this.maximumArgon2Iterations = 10,
    this.maximumArgon2Parallelism = 4,
    this.maximumPbkdf2Iterations = 5000000,
    this.maximumArchiveEntries = 1000000,
    this.maximumObjectBytes = 64 * 1024 * 1024 * 1024,
    this.maximumDeclaredPlaintextBytes = 4 * 1024 * 1024 * 1024 * 1024,
    this.maximumChunkBytes = 8 * 1024 * 1024,
    this.maximumPathBytes = 512,
    this.maximumNestingDepth = 4,
    this.maximumDecompressionRatio = 100,
  });

  /// Largest accepted public header.
  final int maximumPublicHeaderBytes;

  /// Largest decrypted manifest.
  final int maximumManifestBytes;

  /// Largest imported Argon2 memory request in KiB.
  final int maximumArgon2MemoryKiB;

  /// Largest imported Argon2 iteration count.
  final int maximumArgon2Iterations;

  /// Largest imported Argon2 parallelism.
  final int maximumArgon2Parallelism;

  /// Largest imported PBKDF2 iteration count.
  final int maximumPbkdf2Iterations;

  /// Maximum archive entry count.
  final int maximumArchiveEntries;

  /// Maximum encrypted object size.
  final int maximumObjectBytes;

  /// Maximum total declared plaintext size.
  final int maximumDeclaredPlaintextBytes;

  /// Maximum authenticated object chunk size.
  final int maximumChunkBytes;

  /// Maximum UTF-8 path length.
  final int maximumPathBytes;

  /// Maximum archive path nesting.
  final int maximumNestingDepth;

  /// Maximum decompressed/compressed size ratio.
  final int maximumDecompressionRatio;

  /// Validates KDF parameters before allocation or derivation.
  void validateKdf(
    RecoveryKdfParameters parameters, {
    required int saltLength,
  }) {
    if (saltLength < 16 || saltLength > 64) {
      throw const UnsafeKdfParametersFailure('salt_length');
    }
    if (parameters.outputLength != 32) {
      throw const UnsafeKdfParametersFailure('output_length');
    }
    switch (parameters.algorithm) {
      case RecoveryKdfAlgorithm.argon2id:
        if (parameters.memoryKiB < 19 * 1024 ||
            parameters.memoryKiB > maximumArgon2MemoryKiB) {
          throw const UnsafeKdfParametersFailure('argon2_memory');
        }
        if (parameters.iterations < 2 ||
            parameters.iterations > maximumArgon2Iterations) {
          throw const UnsafeKdfParametersFailure('argon2_iterations');
        }
        if (parameters.parallelism < 1 ||
            parameters.parallelism > maximumArgon2Parallelism) {
          throw const UnsafeKdfParametersFailure('argon2_parallelism');
        }
      case RecoveryKdfAlgorithm.pbkdf2HmacSha256:
        if (parameters.memoryKiB != 0 || parameters.parallelism != 1) {
          throw const UnsafeKdfParametersFailure('pbkdf2_shape');
        }
        if (parameters.iterations < 600000 ||
            parameters.iterations > maximumPbkdf2Iterations) {
          throw const UnsafeKdfParametersFailure('pbkdf2_iterations');
        }
    }
  }

  /// Rejects an oversized public header before parsing nested fields.
  void validatePublicHeaderLength(int length) {
    if (length < 1 || length > maximumPublicHeaderBytes) {
      throw const UnsupportedRecoveryEnvelopeFailure('header_size');
    }
  }

  /// Validates archive-level declarations before extraction.
  void validateArchiveDeclarations({
    required int manifestBytes,
    required int entries,
    required int largestObjectBytes,
    required int declaredPlaintextBytes,
    required int chunkBytes,
    required int longestPathBytes,
    required int nestingDepth,
    required int decompressionRatio,
  }) {
    final checks = <(bool, String)>[
      (manifestBytes <= maximumManifestBytes, 'manifest_size'),
      (entries <= maximumArchiveEntries, 'archive_entries'),
      (largestObjectBytes <= maximumObjectBytes, 'object_size'),
      (
        declaredPlaintextBytes <= maximumDeclaredPlaintextBytes,
        'declared_plaintext_size',
      ),
      (chunkBytes > 0 && chunkBytes <= maximumChunkBytes, 'chunk_size'),
      (longestPathBytes <= maximumPathBytes, 'path_length'),
      (nestingDepth <= maximumNestingDepth, 'nesting_depth'),
      (
        decompressionRatio <= maximumDecompressionRatio,
        'decompression_ratio',
      ),
    ];
    for (final (allowed, parameter) in checks) {
      if (!allowed) {
        throw UnsafeKdfParametersFailure(parameter);
      }
    }
  }
}
