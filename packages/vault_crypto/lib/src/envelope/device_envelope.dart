import 'dart:typed_data';

import 'package:vault_crypto/src/secret/secret_bytes.dart';

/// Device-local envelope produced by Android Keystore or iOS Keychain.
final class DeviceEnvelope {
  /// Creates an immutable device envelope.
  DeviceEnvelope({
    required this.keyAlias,
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> authenticationTag,
    required this.requiresAuthentication,
    required this.invalidatedByBiometricEnrollment,
    required this.createdAt,
    required this.hardwareBacked,
  }) : _nonce = Uint8List.fromList(nonce),
       _ciphertext = Uint8List.fromList(ciphertext),
       _authenticationTag = Uint8List.fromList(authenticationTag);

  /// Stable application alias, not a filesystem path.
  final String keyAlias;

  final Uint8List _nonce;
  final Uint8List _ciphertext;
  final Uint8List _authenticationTag;

  /// Whether local device authentication is required.
  final bool requiresAuthentication;

  /// Whether biometric enrollment changes invalidate the key.
  final bool invalidatedByBiometricEnrollment;

  /// Creation time.
  final DateTime createdAt;

  /// Whether the platform reported hardware-backed protection.
  final bool hardwareBacked;

  /// Defensive copy of the native cipher nonce.
  Uint8List get nonce => Uint8List.fromList(_nonce);

  /// Defensive copy of the wrapped Master Vault Key.
  Uint8List get ciphertext => Uint8List.fromList(_ciphertext);

  /// Defensive copy of the authentication tag.
  Uint8List get authenticationTag => Uint8List.fromList(_authenticationTag);
}

/// Native device-key envelope operations.
abstract interface class DeviceEnvelopeStore {
  /// Provisions a new device key and wraps [masterKey]. Existing aliases fail.
  Future<DeviceEnvelope> wrap({
    required String keyAlias,
    required SecretBytes masterKey,
    required bool invalidatedByBiometricEnrollment,
    required Duration authenticationValidity,
  });

  /// Unwraps a device envelope after platform authentication.
  Future<SecretBytes> unwrap(DeviceEnvelope envelope);

  /// Deletes a device key. This does not affect recovery access.
  Future<void> delete(String keyAlias);
}
