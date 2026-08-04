import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';

void main() {
  test('vault creation fails closed when entropy is unavailable', () async {
    final cryptography = VaultCryptography(random: const _FailingRandom());
    await expectLater(
      cryptography.createVaultKeys(
        recoveryPassphrase: 'correct horse battery staple',
      ),
      throwsA(isA<EntropyUnavailableFailure>()),
    );
  });
}

final class _FailingRandom implements CryptographicRandom {
  const _FailingRandom();

  @override
  Future<Uint8List> secureBytes(int length) =>
      Future<Uint8List>.error(StateError('synthetic entropy failure'));
}
