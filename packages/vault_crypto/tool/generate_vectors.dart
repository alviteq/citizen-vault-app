import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:vault_crypto/vault_crypto.dart';

Future<void> main() async {
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
  final derived = await VaultKeyHierarchy().deriveAll(
    masterKey: master,
    vaultSalt: List<int>.generate(32, (index) => 0x20 + index),
  );

  final aes = AesGcm.with256bits();
  final fileWrap = await aes.encrypt(
    List<int>.generate(32, (index) => index),
    secretKey: SecretKey(List<int>.generate(32, (index) => 0xa0 + index)),
    nonce: List<int>.generate(12, (index) => 0xc0 + index),
    aad: utf8.encode('citizen-vault/file-key-wrap/v1'),
  );
  final chunkNonce = Uint8List.fromList(<int>[
    ...List<int>.generate(8, (index) => 0xd0 + index),
    0,
    0,
    0,
    5,
  ]);
  final chunk = await aes.encrypt(
    utf8.encode('Citizen Vault chunk vector'),
    secretKey: SecretKey(List<int>.generate(32, (index) => index)),
    nonce: chunkNonce,
    aad: <int>[...utf8.encode('citizen-vault/chunk/v1'), 0, 0, 0, 5],
  );
  final manifest = await aes.encrypt(
    utf8.encode('CV-MANIFEST-V1\u0000fixture'),
    secretKey: SecretKey(List<int>.generate(32, (index) => 0x20 + index)),
    nonce: List<int>.generate(12, (index) => 0xe0 + index),
    aad: utf8.encode('citizen-vault/backup-header/v1'),
  );

  final output = <String, Object>{
    'format': 'citizen-vault-crypto-vectors',
    'version': 1,
    'recovery_envelope_hex': _hex(RecoveryEnvelopeCodec.encode(envelope)),
    'subkeys': <String, String>{
      for (final context in VaultSubkeyContext.values)
        context.name: _hex(derived[context].extractBytes()),
    },
    'file_key_wrap': _box(fileWrap),
    'chunk_nonce_index_5_hex': _hex(chunkNonce),
    'chunk_encryption': _box(chunk),
    'manifest_encryption': _box(manifest),
  };
  // Synthetic deterministic values only. Never use this tool with real keys.
  // ignore: avoid_print
  print(const JsonEncoder.withIndent('  ').convert(output));
  derived.destroy();
  master.destroy();
}

Map<String, String> _box(SecretBox box) => <String, String>{
  'nonce_hex': _hex(box.nonce),
  'ciphertext_hex': _hex(box.cipherText),
  'tag_hex': _hex(box.mac.bytes),
};

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

final class _UnusedRandom implements CryptographicRandom {
  @override
  Future<Uint8List> secureBytes(int length) =>
      throw UnsupportedError('Generator uses explicit deterministic inputs');
}
