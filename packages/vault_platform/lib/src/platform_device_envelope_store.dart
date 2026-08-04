import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vault_crypto/vault_crypto.dart';

/// Android Keystore / iOS Keychain implementation of [DeviceEnvelopeStore].
final class PlatformDeviceEnvelopeStore implements DeviceEnvelopeStore {
  /// Creates the adapter.
  const PlatformDeviceEnvelopeStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('citizen_vault/security');

  final MethodChannel _channel;

  static final RegExp _aliasPattern = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

  @override
  Future<DeviceEnvelope> wrap({
    required String keyAlias,
    required SecretBytes masterKey,
    required bool invalidatedByBiometricEnrollment,
    required Duration authenticationValidity,
  }) async {
    _validateAlias(keyAlias);
    if (masterKey.length != 32) {
      throw ArgumentError.value(masterKey.length, 'masterKey', 'must be 32');
    }
    final seconds = authenticationValidity.inSeconds;
    if (seconds < 1 || seconds > 3600) {
      throw RangeError.range(seconds, 1, 3600, 'authenticationValidity');
    }
    final masterBytes = masterKey.extractBytes();
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'wrapDeviceKey',
        <String, Object>{
          'keyAlias': keyAlias,
          'masterKey': masterBytes,
          'invalidatedByBiometricEnrollment': invalidatedByBiometricEnrollment,
          'authenticationValiditySeconds': seconds,
        },
      );
      if (result == null) {
        throw const PlatformSecurityUnavailableFailure();
      }
      return DeviceEnvelope(
        keyAlias: keyAlias,
        nonce: _bytes(result, 'nonce'),
        ciphertext: _bytes(result, 'ciphertext'),
        authenticationTag: _bytes(result, 'authenticationTag'),
        requiresAuthentication:
            result['requiresAuthentication'] is bool
                ? result['requiresAuthentication']! as bool
                : true,
        invalidatedByBiometricEnrollment: invalidatedByBiometricEnrollment,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          _integer(result, 'createdAtEpochMilliseconds'),
          isUtc: true,
        ),
        hardwareBacked: _boolean(result, 'hardwareBacked'),
      );
    } on PlatformException catch (error) {
      throw _mapPlatformFailure(error);
    } finally {
      masterBytes.fillRange(0, masterBytes.length, 0);
    }
  }

  @override
  Future<SecretBytes> unwrap(DeviceEnvelope envelope) async {
    _validateAlias(envelope.keyAlias);
    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'unwrapDeviceKey',
        <String, Object>{
          'keyAlias': envelope.keyAlias,
          'nonce': envelope.nonce,
          'ciphertext': envelope.ciphertext,
          'authenticationTag': envelope.authenticationTag,
        },
      );
      if (bytes == null || bytes.length != 32) {
        throw const DeviceEnvelopeAuthenticationFailure();
      }
      return SecretBytes(bytes);
    } on PlatformException catch (error) {
      throw _mapPlatformFailure(error);
    }
  }

  @override
  Future<void> delete(String keyAlias) async {
    _validateAlias(keyAlias);
    try {
      await _channel.invokeMethod<void>(
        'deleteDeviceKey',
        <String, Object>{'keyAlias': keyAlias},
      );
    } on PlatformException catch (error) {
      throw _mapPlatformFailure(error);
    }
  }

  static Uint8List _bytes(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is Uint8List) {
      return value;
    }
    if (value is String) {
      try {
        return base64Decode(value);
      } on FormatException {
        throw const PlatformSecurityUnavailableFailure();
      }
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    throw const PlatformSecurityUnavailableFailure();
  }

  static int _integer(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    throw const PlatformSecurityUnavailableFailure();
  }

  static bool _boolean(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is bool) {
      return value;
    }
    throw const PlatformSecurityUnavailableFailure();
  }

  static void _validateAlias(String alias) {
    if (!_aliasPattern.hasMatch(alias)) {
      throw ArgumentError.value(alias, 'keyAlias', 'invalid alias');
    }
  }

  static VaultCryptoFailure _mapPlatformFailure(PlatformException error) {
    return switch (error.code) {
      'PLATFORM_KEY_INVALIDATED' ||
      'KEY_NOT_FOUND' => PlatformKeyInvalidatedFailure(cause: error),
      'AUTH_REQUIRED' => DeviceAuthenticationRequiredFailure(cause: error),
      'AUTHENTICATION_FAILED' => DeviceEnvelopeAuthenticationFailure(
        cause: error,
      ),
      _ => PlatformSecurityUnavailableFailure(cause: error),
    };
  }
}
