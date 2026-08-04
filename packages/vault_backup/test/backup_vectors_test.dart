import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_backup/vault_backup.dart';
import 'package:vault_crypto/vault_crypto.dart';

void main() {
  test('backup format version one remains byte-stable', () async {
    final fixture =
        jsonDecode(
              File('test/fixtures/backup_vectors_v1.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final random = _VectorRandom();
    final cryptography = BackupCryptography(random: random);
    final master = SecretBytes(List<int>.generate(32, (index) => index));
    final vaultSalt = List<int>.generate(32, (index) => 0x20 + index);
    final header = BackupPublicHeader(
      kdfParameters: const RecoveryKdfParameters.productionPbkdf2Fallback(),
      kdfSalt: List<int>.generate(16, (index) => 0x40 + index),
    );
    final headerBytes = BackupPublicHeaderCodec.encode(header);
    expect(_hex(headerBytes), fixture['header_cbor_hex']);
    expect(
      BackupPublicHeaderCodec.encode(
        BackupPublicHeaderCodec.decode(headerBytes),
      ),
      headerBytes,
    );

    final recovery = await cryptography.createRecoveryEnvelope(
      recoveryPassphrase: 'correct horse battery staple citizen vault',
      header: header,
      canonicalHeaderBytes: headerBytes,
      masterKey: master,
      vaultHkdfSalt: vaultSalt,
    );
    final recoveryBytes = BackupRecoveryEnvelopeCodec.encode(recovery);
    expect(_hex(recoveryBytes), fixture['recovery_envelope_cbor_hex']);

    final manifest = BackupManifest(
      generationId: 'vector-generation',
      vaultId: 'vector-vault',
      createdAt: DateTime.utc(2026, 7, 16, 12),
      databaseSchemaVersion: 3,
      encryptionFormatVersion: 1,
      objectFormatVersion: 1,
      backupFormatVersion: 1,
      minimumReaderVersion: 1,
      snapshotSize: 4096,
      snapshotSha256: List<int>.generate(32, (index) => 0x60 + index),
      objects: const <BackupManifestObject>[],
      requiredAlgorithmVersions: const <int>[1],
      pipelineVersions: const <int>[1, 2],
    );
    final manifestBytes = BackupManifestCodec.encode(manifest);
    expect(_hex(manifestBytes), fixture['manifest_cbor_hex']);
    expect(
      BackupManifestCodec.encode(BackupManifestCodec.decode(manifestBytes)),
      manifestBytes,
    );

    final derived = await VaultKeyHierarchy().deriveAll(
      masterKey: master,
      vaultSalt: vaultSalt,
    );
    try {
      final encryptedManifest = await cryptography.encryptManifest(
        canonicalManifestBytes: manifestBytes,
        backupKey: derived[VaultSubkeyContext.backup],
        canonicalHeaderBytes: headerBytes,
        recoveryEnvelopeBytes: recoveryBytes,
      );
      expect(_hex(encryptedManifest), fixture['encrypted_manifest_hex']);
    } finally {
      derived.destroy();
      master.destroy();
    }
  });
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

final class _VectorRandom implements CryptographicRandom {
  var _next = 1;

  @override
  Future<Uint8List> secureBytes(int length) async => Uint8List.fromList(
    List<int>.generate(length, (_) => _next++ & 0xFF),
  );
}
