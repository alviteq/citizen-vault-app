import 'dart:typed_data';

import 'package:vault_crypto/src/kdf/kdf_parameters.dart';

/// Supported Master Vault Key wrapping algorithms.
enum KeyWrappingAlgorithm {
  /// AES-256-GCM with a 96-bit nonce and 128-bit authentication tag.
  aes256Gcm(1);

  const KeyWrappingAlgorithm(this.wireId);

  /// Stable binary identifier.
  final int wireId;
}

/// Portable authenticated recovery envelope for the Master Vault Key.
final class RecoveryEnvelope {
  /// Creates an immutable recovery envelope.
  RecoveryEnvelope({
    required this.formatVersion,
    required this.wrappingAlgorithm,
    required this.kdfParameters,
    required List<int> salt,
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> authenticationTag,
    required List<int> headerDigest,
    required this.createdAt,
  }) : _salt = Uint8List.fromList(salt),
       _nonce = Uint8List.fromList(nonce),
       _ciphertext = Uint8List.fromList(ciphertext),
       _authenticationTag = Uint8List.fromList(authenticationTag),
       _headerDigest = Uint8List.fromList(headerDigest);

  /// Current portable envelope version.
  static const int currentFormatVersion = 1;

  /// Format version.
  final int formatVersion;

  /// Master-key wrapping algorithm.
  final KeyWrappingAlgorithm wrappingAlgorithm;

  /// Recovery KDF algorithm and parameters.
  final RecoveryKdfParameters kdfParameters;

  final Uint8List _salt;
  final Uint8List _nonce;
  final Uint8List _ciphertext;
  final Uint8List _authenticationTag;
  final Uint8List _headerDigest;

  /// UTC creation instant, serialized at whole-second precision.
  final DateTime createdAt;

  /// Defensive copy of the recovery KDF salt.
  Uint8List get salt => Uint8List.fromList(_salt);

  /// Defensive copy of the AES-GCM nonce.
  Uint8List get nonce => Uint8List.fromList(_nonce);

  /// Defensive copy of the wrapped Master Vault Key.
  Uint8List get ciphertext => Uint8List.fromList(_ciphertext);

  /// Defensive copy of the AES-GCM tag.
  Uint8List get authenticationTag => Uint8List.fromList(_authenticationTag);

  /// SHA-256 digest of canonical public header fields.
  Uint8List get headerDigest => Uint8List.fromList(_headerDigest);
}
