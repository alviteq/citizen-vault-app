import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';

void main() {
  const parameters = RecoveryKdfParameters.productionPbkdf2Fallback();
  final random = _DeterministicRandom(
    List<int>.generate(256, (index) => index),
  );
  final cryptography = VaultCryptography(random: random);

  test('creates and recovers a random Master Vault Key', () async {
    final result = await cryptography.createVaultKeys(
      recoveryPassphrase: 'correct horse battery staple',
      kdfParameters: parameters,
      createdAt: DateTime.utc(2026, 7, 16, 12),
    );
    addTearDown(result.masterKey.destroy);

    expect(result.masterKey.length, 32);
    expect(result.vaultHkdfSalt.length, 32);
    final recovered = await cryptography.recoverMasterKey(
      recoveryPassphrase: 'correct horse battery staple',
      envelope: result.recoveryEnvelope,
    );
    addTearDown(recovered.destroy);
    expect(recovered.extractBytes(), result.masterKey.extractBytes());
  });

  test('wrong passphrase fails closed', () async {
    final fixture = await _fixture(cryptography, parameters);
    addTearDown(fixture.master.destroy);

    await expectLater(
      cryptography.recoverMasterKey(
        recoveryPassphrase: 'this is the wrong passphrase',
        envelope: fixture.envelope,
      ),
      throwsA(isA<RecoveryEnvelopeAuthenticationFailure>()),
    );
  });

  test('modified authenticated header fails before decryption', () async {
    final fixture = await _fixture(cryptography, parameters);
    addTearDown(fixture.master.destroy);
    final tampered = RecoveryEnvelope(
      formatVersion: fixture.envelope.formatVersion,
      wrappingAlgorithm: fixture.envelope.wrappingAlgorithm,
      kdfParameters: fixture.envelope.kdfParameters,
      salt: fixture.envelope.salt,
      nonce: fixture.envelope.nonce,
      ciphertext: fixture.envelope.ciphertext,
      authenticationTag: fixture.envelope.authenticationTag,
      headerDigest: fixture.envelope.headerDigest,
      createdAt: fixture.envelope.createdAt.add(const Duration(seconds: 1)),
    );

    await expectLater(
      cryptography.recoverMasterKey(
        recoveryPassphrase: 'correct horse battery staple',
        envelope: tampered,
      ),
      throwsA(isA<RecoveryEnvelopeAuthenticationFailure>()),
    );
  });

  test('modified ciphertext authentication tag is rejected', () async {
    final fixture = await _fixture(cryptography, parameters);
    addTearDown(fixture.master.destroy);
    final tag = fixture.envelope.authenticationTag..[0] ^= 1;
    final tampered = RecoveryEnvelope(
      formatVersion: fixture.envelope.formatVersion,
      wrappingAlgorithm: fixture.envelope.wrappingAlgorithm,
      kdfParameters: fixture.envelope.kdfParameters,
      salt: fixture.envelope.salt,
      nonce: fixture.envelope.nonce,
      ciphertext: fixture.envelope.ciphertext,
      authenticationTag: tag,
      headerDigest: fixture.envelope.headerDigest,
      createdAt: fixture.envelope.createdAt,
    );

    await expectLater(
      cryptography.recoverMasterKey(
        recoveryPassphrase: 'correct horse battery staple',
        envelope: tampered,
      ),
      throwsA(isA<RecoveryEnvelopeAuthenticationFailure>()),
    );
  });

  test('canonical codec round-trips and rejects trailing bytes', () async {
    final fixture = await _fixture(cryptography, parameters);
    addTearDown(fixture.master.destroy);
    final encoded = RecoveryEnvelopeCodec.encode(fixture.envelope);
    final decoded = RecoveryEnvelopeCodec.decode(encoded);

    expect(RecoveryEnvelopeCodec.encode(decoded), encoded);
    await expectLater(
      () => RecoveryEnvelopeCodec.decode(<int>[...encoded, 0]),
      throwsA(isA<UnsupportedRecoveryEnvelopeFailure>()),
    );
  });

  test('unsafe imported KDF parameters are rejected before derivation', () {
    const policy = VaultImportPolicy();
    expect(
      () => policy.validateKdf(
        const RecoveryKdfParameters(
          algorithm: RecoveryKdfAlgorithm.argon2id,
          iterations: 2,
          memoryKiB: 1024 * 1024,
          parallelism: 1,
        ),
        saltLength: 16,
      ),
      throwsA(isA<UnsafeKdfParametersFailure>()),
    );
  });
}

Future<({RecoveryEnvelope envelope, SecretBytes master})> _fixture(
  VaultCryptography cryptography,
  RecoveryKdfParameters parameters,
) async {
  final master = SecretBytes(List<int>.generate(32, (index) => index));
  final envelope = await cryptography.createRecoveryEnvelope(
    recoveryPassphrase: 'correct horse battery staple',
    masterKey: master,
    kdfParameters: parameters,
    salt: List<int>.generate(16, (index) => 0x40 + index),
    nonce: List<int>.generate(12, (index) => 0x80 + index),
    createdAt: DateTime.utc(2026, 7, 16, 12),
  );
  return (envelope: envelope, master: master);
}

final class _DeterministicRandom implements CryptographicRandom {
  _DeterministicRandom(this._bytes);

  final List<int> _bytes;
  int _offset = 0;

  @override
  Future<Uint8List> secureBytes(int length) async {
    final output = Uint8List.fromList(
      _bytes.sublist(_offset, _offset + length),
    );
    _offset += length;
    return output;
  }
}
