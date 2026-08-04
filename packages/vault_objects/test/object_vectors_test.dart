import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';
import 'package:vault_objects/vault_objects.dart';

void main() {
  test('object format version one remains byte-stable', () async {
    final fixture =
        jsonDecode(
              File('test/fixtures/object_vectors_v1.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final objectId = ObjectId.parse(fixture['object_id']! as String);
    final fileKey = _decode(fixture['file_data_key_hex']! as String);
    final rootKey = _decode(fixture['file_root_key_hex']! as String);
    final noncePrefix = List<int>.generate(8, (index) => 0xD0 + index);
    final wrapNonce = List<int>.generate(12, (index) => 0xC0 + index);
    final binding = ObjectFormatV1.objectBinding(
      objectId: objectId,
      keyVersion: 3,
      chunkSize: 64 * 1024,
      noncePrefix: noncePrefix,
    );
    expect(_hex(binding), fixture['object_binding_hex']);

    final nonce = ObjectFormatV1.chunkNonce(noncePrefix, 5);
    final plaintext = _decode(fixture['chunk_plaintext_hex']! as String);
    final chunkAad = ObjectFormatV1.chunkAad(
      objectBinding: binding,
      chunkIndex: 5,
      plaintextLength: plaintext.length,
    );
    expect(_hex(nonce), fixture['chunk_nonce_index_5_hex']);
    expect(_hex(chunkAad), fixture['chunk_aad_hex']);
    final aes = AesGcm.with256bits();
    final chunk = await aes.encrypt(
      plaintext,
      secretKey: SecretKey(fileKey),
      nonce: nonce,
      aad: chunkAad,
    );
    expect(_hex(chunk.cipherText), fixture['chunk_ciphertext_hex']);
    expect(_hex(chunk.mac.bytes), fixture['chunk_tag_hex']);

    final provisional = ObjectHeaderV1(
      objectId: objectId,
      keyVersion: 3,
      chunkSize: 64 * 1024,
      plaintextSize: plaintext.length,
      chunkCount: 1,
      noncePrefix: noncePrefix,
      wrapNonce: wrapNonce,
      wrappedFileKey: List<int>.filled(32, 0),
      wrappingTag: List<int>.filled(16, 0),
      headerDigest: List<int>.filled(32, 0),
    );
    final baseHeader = provisional.baseBytes();
    final digest = Sha256().toSync().hashSync(baseHeader).bytes;
    final wrapAad = ObjectFormatV1.keyWrapAad(
      baseHeader: baseHeader,
      headerDigest: digest,
    );
    expect(_hex(baseHeader), fixture['header_base_hex']);
    expect(_hex(digest), fixture['header_digest_hex']);
    expect(_hex(wrapAad), fixture['key_wrap_aad_hex']);
    final wrapped = await aes.encrypt(
      fileKey,
      secretKey: SecretKey(rootKey),
      nonce: wrapNonce,
      aad: wrapAad,
    );
    expect(_hex(wrapped.cipherText), fixture['wrapped_file_key_hex']);
    expect(_hex(wrapped.mac.bytes), fixture['wrapped_file_key_tag_hex']);
    final header = ObjectHeaderV1(
      objectId: objectId,
      keyVersion: 3,
      chunkSize: 64 * 1024,
      plaintextSize: plaintext.length,
      chunkCount: 1,
      noncePrefix: noncePrefix,
      wrapNonce: wrapNonce,
      wrappedFileKey: wrapped.cipherText,
      wrappingTag: wrapped.mac.bytes,
      headerDigest: digest,
    );
    expect(_hex(header.encode()), fixture['header_hex']);
  });
}

List<int> _decode(String value) => <int>[
  for (var offset = 0; offset < value.length; offset += 2)
    int.parse(value.substring(offset, offset + 2), radix: 16),
];

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
