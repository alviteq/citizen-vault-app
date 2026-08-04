import 'dart:typed_data';

import 'package:vault_crypto/vault_crypto.dart';

export 'src/interoperability/portable_vault_fixture.dart';

/// Deterministic byte stream for cryptographic vector tests only.
final class DeterministicCryptographicRandom implements CryptographicRandom {
  /// Creates a provider that consumes [bytes] without cycling.
  DeterministicCryptographicRandom(List<int> bytes)
    : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  int _offset = 0;

  @override
  Future<Uint8List> secureBytes(int length) async {
    if (length < 1 || _offset + length > _bytes.length) {
      throw StateError('Deterministic entropy exhausted');
    }
    final result = Uint8List.fromList(
      _bytes.sublist(_offset, _offset + length),
    );
    _offset += length;
    return result;
  }
}

/// Random provider that deterministically simulates OS entropy failure.
final class FailingCryptographicRandom implements CryptographicRandom {
  /// Creates the failing provider.
  const FailingCryptographicRandom([this.error = const _EntropyError()]);

  /// Error thrown by every request.
  final Object error;

  @override
  Future<Uint8List> secureBytes(int length) => Future<Uint8List>.error(error);
}

final class _EntropyError implements Exception {
  const _EntropyError();
}

/// Package metadata for shared deterministic test support.
abstract final class VaultTestSupportPackage {
  /// Public API version.
  static const String apiVersion = '0.6.0';
}
