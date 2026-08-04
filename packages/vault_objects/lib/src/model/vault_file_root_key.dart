import 'dart:typed_data';

import 'package:vault_crypto/vault_crypto.dart';

/// Owned versioned 256-bit key used only to wrap per-file data keys.
final class VaultFileRootKey {
  /// Copies [bytes] into an owned key.
  VaultFileRootKey.fromBytes(List<int> bytes, {required this.keyVersion})
    : _bytes = SecretBytes(bytes) {
    if (_bytes.length != 32) {
      _bytes.destroy();
      throw ArgumentError.value(bytes.length, 'bytes', 'must be 32');
    }
    if (keyVersion < 1) {
      _bytes.destroy();
      throw ArgumentError.value(keyVersion, 'keyVersion', 'must be positive');
    }
  }

  final SecretBytes _bytes;

  /// Rotation version persisted in each authenticated object header.
  final int keyVersion;

  /// Whether the owned key has been destroyed.
  bool get isDestroyed => _bytes.isDestroyed;

  /// Supplies a temporary defensive key copy to an operation.
  Future<T> withBytes<T>(Future<T> Function(Uint8List bytes) action) async {
    final bytes = _bytes.extractBytes();
    try {
      return await action(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  /// Best-effort overwrites this owned key.
  void destroy() => _bytes.destroy();
}
