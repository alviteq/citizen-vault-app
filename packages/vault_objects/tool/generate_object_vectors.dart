// Synthetic deterministic cryptographic fixture generator prints JSON.
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:vault_objects/vault_objects.dart';

Future<void> main() async {
  final aes = AesGcm.with256bits();
  final sha = Sha256().toSync();
  final objectId = ObjectId.parse('00000000000000000000000001');
  final rootKey = List<int>.generate(32, (index) => 0xA0 + index);
  final fileKey = List<int>.generate(32, (index) => index);
  final noncePrefix = List<int>.generate(8, (index) => 0xD0 + index);
  final wrapNonce = List<int>.generate(12, (index) => 0xC0 + index);
  final plaintext = utf8.encode('Citizen Vault chunk vector');
  const chunkIndex = 5;
  final binding = ObjectFormatV1.objectBinding(
    objectId: objectId,
    keyVersion: 3,
    chunkSize: 64 * 1024,
    noncePrefix: noncePrefix,
  );
  final chunkNonce = ObjectFormatV1.chunkNonce(noncePrefix, chunkIndex);
  final chunkAad = ObjectFormatV1.chunkAad(
    objectBinding: binding,
    chunkIndex: chunkIndex,
    plaintextLength: plaintext.length,
  );
  final encryptedChunk = await aes.encrypt(
    plaintext,
    secretKey: SecretKey(fileKey),
    nonce: chunkNonce,
    aad: chunkAad,
  );
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
  final headerDigest = sha.hashSync(baseHeader).bytes;
  final wrapAad = ObjectFormatV1.keyWrapAad(
    baseHeader: baseHeader,
    headerDigest: headerDigest,
  );
  final wrappedKey = await aes.encrypt(
    fileKey,
    secretKey: SecretKey(rootKey),
    nonce: wrapNonce,
    aad: wrapAad,
  );
  final header = ObjectHeaderV1(
    objectId: objectId,
    keyVersion: 3,
    chunkSize: 64 * 1024,
    plaintextSize: plaintext.length,
    chunkCount: 1,
    noncePrefix: noncePrefix,
    wrapNonce: wrapNonce,
    wrappedFileKey: wrappedKey.cipherText,
    wrappingTag: wrappedKey.mac.bytes,
    headerDigest: headerDigest,
  );

  print(
    const JsonEncoder.withIndent('  ').convert(<String, Object>{
      'format': 'citizen-vault-object-vectors',
      'version': 1,
      'object_id': objectId.value,
      'file_root_key_hex': _hex(rootKey),
      'file_data_key_hex': _hex(fileKey),
      'object_binding_hex': _hex(binding),
      'chunk_nonce_index_5_hex': _hex(chunkNonce),
      'chunk_aad_hex': _hex(chunkAad),
      'chunk_plaintext_hex': _hex(plaintext),
      'chunk_ciphertext_hex': _hex(encryptedChunk.cipherText),
      'chunk_tag_hex': _hex(encryptedChunk.mac.bytes),
      'header_base_hex': _hex(baseHeader),
      'header_digest_hex': _hex(headerDigest),
      'key_wrap_aad_hex': _hex(wrapAad),
      'wrapped_file_key_hex': _hex(wrappedKey.cipherText),
      'wrapped_file_key_tag_hex': _hex(wrappedKey.mac.bytes),
      'header_hex': _hex(header.encode()),
      'plaintext_sha256_hex': _hex(sha.hashSync(plaintext).bytes),
    }),
  );
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
