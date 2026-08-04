import 'dart:typed_data';

/// Source of cryptographically secure random bytes.
// The interface is intentionally injectable despite containing one operation.
// ignore: one_member_abstracts
abstract interface class CryptographicRandom {
  /// Returns exactly [length] bytes from an OS-backed CSPRNG.
  Future<Uint8List> secureBytes(int length);
}
