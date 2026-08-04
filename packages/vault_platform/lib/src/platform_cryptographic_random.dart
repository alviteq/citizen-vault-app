import 'dart:math';

import 'package:flutter/services.dart';
import 'package:vault_crypto/vault_crypto.dart';

/// OS CSPRNG adapter backed by MethodChannel with secure fallback.
final class PlatformCryptographicRandom implements CryptographicRandom {
  /// Creates the adapter.
  const PlatformCryptographicRandom({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('citizen_vault/security');

  final MethodChannel _channel;

  @override
  Future<Uint8List> secureBytes(int length) async {
    if (length < 1 || length > 1024 * 1024) {
      throw RangeError.range(length, 1, 1024 * 1024, 'length');
    }
    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'secureRandom',
        <String, Object>{'length': length},
      );
      if (bytes != null && bytes.length == length) {
        return Uint8List.fromList(bytes);
      }
    } on Object {
      // Fallback on platforms without citizen_vault/security native channel
    }

    try {
      final rng = Random.secure();
      return Uint8List.fromList(
        List<int>.generate(length, (_) => rng.nextInt(256)),
      );
    } on Object catch (error) {
      throw EntropyUnavailableFailure(cause: error);
    }
  }
}
