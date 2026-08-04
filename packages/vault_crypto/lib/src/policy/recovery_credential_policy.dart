import 'dart:convert';

import 'package:vault_crypto/src/errors/crypto_failure.dart';
import 'package:vault_crypto/src/random/cryptographic_random.dart';

/// Result of local recovery credential validation.
final class RecoveryCredentialAssessment {
  /// Creates an assessment.
  const RecoveryCredentialAssessment({
    required this.accepted,
    required this.score,
    required this.reason,
  });

  /// Whether onboarding may continue.
  final bool accepted;

  /// Coarse local score from zero to four.
  final int score;

  /// Stable safe reason code.
  final String reason;
}

/// Length-based recovery policy without arbitrary character-class rules.
abstract final class RecoveryCredentialPolicy {
  /// Minimum user-chosen passphrase length.
  static const int minimumCharacters = 12;

  /// Maximum UTF-8 bytes accepted to bound KDF input handling.
  static const int maximumUtf8Bytes = 1024;

  static const Set<String> _commonPasswords = <String>{
    'password',
    'password123',
    '123456789012',
    'qwertyuiop12',
    'letmein123456',
  };

  /// Assesses a passphrase locally without logging or retaining it.
  static RecoveryCredentialAssessment assess(String passphrase) {
    final byteLength = utf8.encode(passphrase).length;
    if (byteLength > maximumUtf8Bytes) {
      return const RecoveryCredentialAssessment(
        accepted: false,
        score: 0,
        reason: 'too_long',
      );
    }
    if (_commonPasswords.contains(passphrase.toLowerCase())) {
      return const RecoveryCredentialAssessment(
        accepted: false,
        score: 0,
        reason: 'common_password',
      );
    }
    if (passphrase.runes.length < minimumCharacters) {
      return const RecoveryCredentialAssessment(
        accepted: false,
        score: 0,
        reason: 'too_short',
      );
    }
    final length = passphrase.runes.length;
    final score = switch (length) {
      >= 32 => 4,
      >= 24 => 3,
      >= 16 => 2,
      _ => 1,
    };
    return RecoveryCredentialAssessment(
      accepted: true,
      score: score,
      reason: 'accepted',
    );
  }
}

/// Generates a high-entropy, human-transcribable recovery code.
final class RecoveryCodeGenerator {
  /// Creates a generator using an OS-backed random source.
  const RecoveryCodeGenerator(this._random);

  final CryptographicRandom _random;

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generates 32 unbiased symbols grouped for transcription.
  Future<String> generate() async {
    final List<int> bytes;
    try {
      bytes = await _random.secureBytes(32);
      if (bytes.length != 32) {
        throw const EntropyUnavailableFailure();
      }
    } on VaultCryptoFailure {
      rethrow;
    } on Object catch (error) {
      throw EntropyUnavailableFailure(cause: error);
    }
    final symbols = StringBuffer();
    for (var index = 0; index < bytes.length; index += 1) {
      if (index > 0 && index.isEven && index % 4 == 0) {
        symbols.write('-');
      }
      symbols.write(_alphabet[bytes[index] & 31]);
    }
    return symbols.toString();
  }
}
