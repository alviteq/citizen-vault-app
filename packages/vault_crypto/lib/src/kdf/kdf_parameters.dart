/// Supported recovery key-derivation algorithms.
enum RecoveryKdfAlgorithm {
  /// Argon2id version 1.3 / 0x13.
  argon2id(1),

  /// PBKDF2 using HMAC-SHA-256. Used only as a fallback.
  pbkdf2HmacSha256(2);

  const RecoveryKdfAlgorithm(this.wireId);

  /// Stable binary identifier.
  final int wireId;

  /// Resolves a stable binary identifier.
  static RecoveryKdfAlgorithm fromWireId(int value) {
    return values.firstWhere(
      (algorithm) => algorithm.wireId == value,
      orElse: () => throw ArgumentError.value(value, 'value'),
    );
  }
}

/// Immutable parameters for a recovery KDF.
final class RecoveryKdfParameters {
  /// Creates KDF parameters.
  const RecoveryKdfParameters({
    required this.algorithm,
    required this.iterations,
    required this.memoryKiB,
    required this.parallelism,
    this.outputLength = 32,
  });

  /// Reviewed production Argon2id baseline for 4 GB devices.
  const RecoveryKdfParameters.productionArgon2id()
    : algorithm = RecoveryKdfAlgorithm.argon2id,
      iterations = 2,
      memoryKiB = 19 * 1024,
      parallelism = 1,
      outputLength = 32;

  /// Reviewed PBKDF2 fallback. Never preferred when Argon2id is available.
  const RecoveryKdfParameters.productionPbkdf2Fallback()
    : algorithm = RecoveryKdfAlgorithm.pbkdf2HmacSha256,
      iterations = 600000,
      memoryKiB = 0,
      parallelism = 1,
      outputLength = 32;

  /// Algorithm identifier.
  final RecoveryKdfAlgorithm algorithm;

  /// Iteration count.
  final int iterations;

  /// Argon2 memory in 1 KiB blocks; zero for PBKDF2.
  final int memoryKiB;

  /// Argon2 parallelism; one for PBKDF2.
  final int parallelism;

  /// Derived key size in bytes.
  final int outputLength;
}
