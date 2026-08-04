import 'dart:typed_data';

/// Mutable owned bytes for short-lived key material.
///
/// [destroy] overwrites this Dart buffer. Dart VM copies, native buffers, and
/// compiler/runtime behavior prevent a guarantee that every historical copy is
/// erased. Callers must still minimize extraction, copies, and lifetime.
final class SecretBytes {
  /// Copies [bytes] into an owned buffer.
  SecretBytes(List<int> bytes) : _bytes = Uint8List.fromList(bytes) {
    if (_bytes.isEmpty) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must not be empty');
    }
  }

  Uint8List _bytes;
  bool _destroyed = false;

  /// Number of bytes, or zero after destruction.
  int get length => _bytes.length;

  /// Whether [destroy] has been called.
  bool get isDestroyed => _destroyed;

  /// Returns a defensive copy of the secret.
  Uint8List extractBytes() {
    _ensureAlive();
    return Uint8List.fromList(_bytes);
  }

  /// Overwrites the owned buffer and marks this value unusable.
  void destroy() {
    if (_destroyed) {
      return;
    }
    _bytes.fillRange(0, _bytes.length, 0);
    _bytes = Uint8List(0);
    _destroyed = true;
  }

  void _ensureAlive() {
    if (_destroyed) {
      throw StateError('SecretBytes has been destroyed');
    }
  }

  @override
  String toString() => 'SecretBytes(length: $length, destroyed: $_destroyed)';
}
