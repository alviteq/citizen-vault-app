import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  test('Argon2id matches RFC 9106 section 5.3', () async {
    final output =
        await Argon2id(
          parallelism: 4,
          memory: 32,
          iterations: 3,
          hashLength: 32,
        ).deriveKey(
          secretKey: SecretKey(List<int>.filled(32, 0x01)),
          nonce: List<int>.filled(16, 0x02),
          optionalSecret: List<int>.filled(8, 0x03),
          associatedData: List<int>.filled(12, 0x04),
        );

    expect(
      _hex(await output.extractBytes()),
      '0d640df58d78766c08c037a34a8b53c9'
      'd01ef0452d75b65eb52520e96b01e659',
    );
  });

  test('HKDF-SHA-256 matches RFC 5869 test case 1', () async {
    final output =
        await Hkdf(
          hmac: Hmac.sha256(),
          outputLength: 42,
        ).deriveKey(
          secretKey: SecretKey(List<int>.filled(22, 0x0b)),
          nonce: _fromHex('000102030405060708090a0b0c'),
          info: _fromHex('f0f1f2f3f4f5f6f7f8f9'),
        );

    expect(
      _hex(await output.extractBytes()),
      '3cb25f25faacd57a90434f64d0362f2a'
      '2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
      '34007208d5b887185865',
    );
  });

  test(
    'PBKDF2-HMAC-SHA-256 matches the published one-iteration vector',
    () async {
      final output = await Pbkdf2.hmacSha256(
        iterations: 1,
        bits: 256,
      ).deriveKeyFromPassword(password: 'password', nonce: 'salt'.codeUnits);

      expect(
        _hex(await output.extractBytes()),
        '120fb6cffcf8b32c43e7225256c4f837'
        'a86548c92ccc35480805987cb70be17b',
      );
    },
  );

  test('AES-256-GCM matches the NIST zero-key vector', () async {
    final box = await AesGcm.with256bits().encrypt(
      List<int>.filled(16, 0),
      secretKey: SecretKey(List<int>.filled(32, 0)),
      nonce: List<int>.filled(12, 0),
    );

    expect(_hex(box.cipherText), 'cea7403d4d606b6e074ec5d3baf39d18');
    expect(_hex(box.mac.bytes), 'd0d1c8a799996bf0265b98b5d48ab919');
  });
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

List<int> _fromHex(String value) => <int>[
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];
