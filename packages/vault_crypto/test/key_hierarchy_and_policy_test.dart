import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';

void main() {
  test('fixed contexts derive distinct 256-bit keys', () async {
    final master = SecretBytes(List<int>.generate(32, (index) => index));
    final hierarchy = VaultKeyHierarchy();
    final keys = await hierarchy.deriveAll(
      masterKey: master,
      vaultSalt: List<int>.generate(32, (index) => 32 + index),
    );
    addTearDown(master.destroy);
    addTearDown(keys.destroy);

    final encoded = <String>{
      for (final context in VaultSubkeyContext.values)
        _hex(keys[context].extractBytes()),
    };
    expect(encoded, hasLength(VaultSubkeyContext.values.length));
    expect(
      keys[VaultSubkeyContext.database].extractBytes(),
      hasLength(32),
    );
  });

  test('secret bytes are defensive and unusable after destruction', () {
    final secret = SecretBytes(<int>[1, 2, 3]);
    final copy = secret.extractBytes()..[0] = 9;
    expect(copy, <int>[9, 2, 3]);
    expect(secret.extractBytes(), <int>[1, 2, 3]);
    secret.destroy();
    expect(secret.isDestroyed, isTrue);
    expect(secret.toString(), isNot(contains('1, 2, 3')));
    expect(secret.extractBytes, throwsStateError);
  });

  test('passphrase policy uses length and common-password checks', () {
    expect(RecoveryCredentialPolicy.assess('short').accepted, isFalse);
    expect(
      RecoveryCredentialPolicy.assess('password123').reason,
      'common_password',
    );
    expect(
      RecoveryCredentialPolicy.assess('a long memorable local phrase').accepted,
      isTrue,
    );
  });

  test('recovery code uses the unbiased 32-symbol alphabet', () async {
    final code = await RecoveryCodeGenerator(
      _FixedRandom(Uint8List.fromList(List<int>.generate(32, (i) => i))),
    ).generate();
    expect(code, 'ABCD-EFGH-JKLM-NPQR-STUV-WXYZ-2345-6789');
  });
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

final class _FixedRandom implements CryptographicRandom {
  const _FixedRandom(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> secureBytes(int length) async => Uint8List.fromList(bytes);
}
