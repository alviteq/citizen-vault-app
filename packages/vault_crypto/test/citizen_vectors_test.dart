import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';

void main() {
  test('Citizen Vault deterministic vectors remain byte-stable', () async {
    final fixture =
        jsonDecode(
              File('test/fixtures/crypto_vectors_v1.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final vault = VaultCryptography(random: _UnusedRandom());
    final master = SecretBytes(List<int>.generate(32, (index) => index));
    final envelope = await vault.createRecoveryEnvelope(
      recoveryPassphrase: 'correct horse battery staple',
      masterKey: master,
      kdfParameters: const RecoveryKdfParameters.productionPbkdf2Fallback(),
      salt: List<int>.generate(16, (index) => 0x40 + index),
      nonce: List<int>.generate(12, (index) => 0x80 + index),
      createdAt: DateTime.utc(2026, 7, 16, 12),
    );
    final keys = await VaultKeyHierarchy().deriveAll(
      masterKey: master,
      vaultSalt: List<int>.generate(32, (index) => 0x20 + index),
    );
    addTearDown(master.destroy);
    addTearDown(keys.destroy);

    expect(
      _hex(RecoveryEnvelopeCodec.encode(envelope)),
      fixture['recovery_envelope_hex'],
    );
    final expectedSubkeys = fixture['subkeys']! as Map<String, Object?>;
    for (final context in VaultSubkeyContext.values) {
      expect(_hex(keys[context].extractBytes()), expectedSubkeys[context.name]);
    }

    final aes = AesGcm.with256bits();
    final fileWrap = await aes.encrypt(
      List<int>.generate(32, (index) => index),
      secretKey: SecretKey(List<int>.generate(32, (index) => 0xa0 + index)),
      nonce: List<int>.generate(12, (index) => 0xc0 + index),
      aad: utf8.encode('citizen-vault/file-key-wrap/v1'),
    );
    _expectBox(fileWrap, fixture['file_key_wrap']! as Map<String, Object?>);

    final chunkNonce = <int>[
      ...List<int>.generate(8, (index) => 0xd0 + index),
      0,
      0,
      0,
      5,
    ];
    expect(_hex(chunkNonce), fixture['chunk_nonce_index_5_hex']);
    final chunk = await aes.encrypt(
      utf8.encode('Citizen Vault chunk vector'),
      secretKey: SecretKey(List<int>.generate(32, (index) => index)),
      nonce: chunkNonce,
      aad: <int>[...utf8.encode('citizen-vault/chunk/v1'), 0, 0, 0, 5],
    );
    _expectBox(chunk, fixture['chunk_encryption']! as Map<String, Object?>);

    final manifest = await aes.encrypt(
      utf8.encode('CV-MANIFEST-V1\u0000fixture'),
      secretKey: SecretKey(List<int>.generate(32, (index) => 0x20 + index)),
      nonce: List<int>.generate(12, (index) => 0xe0 + index),
      aad: utf8.encode('citizen-vault/backup-header/v1'),
    );
    _expectBox(
      manifest,
      fixture['manifest_encryption']! as Map<String, Object?>,
    );
  });
}

void _expectBox(SecretBox box, Map<String, Object?> expected) {
  expect(_hex(box.nonce), expected['nonce_hex']);
  expect(_hex(box.cipherText), expected['ciphertext_hex']);
  expect(_hex(box.mac.bytes), expected['tag_hex']);
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

final class _UnusedRandom implements CryptographicRandom {
  @override
  Future<Uint8List> secureBytes(int length) =>
      throw UnsupportedError('Explicit deterministic inputs are used');
}
