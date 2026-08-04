// Canonical fields are documented in docs/backup_format/README.md.
// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

import 'package:vault_backup/src/errors/backup_failure.dart';
import 'package:vault_backup/src/format/canonical_cbor.dart';
import 'package:vault_backup/src/model/backup_models.dart';
import 'package:vault_crypto/vault_crypto.dart';

/// Canonical CBOR codec for the strictly bounded public header.
abstract final class BackupPublicHeaderCodec {
  /// Encodes a version-one fixed-order CBOR array.
  static Uint8List encode(BackupPublicHeader header) {
    final writer = CanonicalCborWriter()
      ..array(13)
      ..text(BackupPublicHeader.formatIdentifier)
      ..uint(BackupPublicHeader.currentVersion)
      ..uint(header.kdfParameters.algorithm.wireId)
      ..uint(header.kdfParameters.iterations)
      ..uint(header.kdfParameters.memoryKiB)
      ..uint(header.kdfParameters.parallelism)
      ..uint(header.kdfParameters.outputLength)
      ..byteString(header.kdfSalt)
      ..text(BackupPublicHeader.recoveryEnvelopeEntry)
      ..text(BackupPublicHeader.encryptedManifestEntry)
      ..uint(BackupPublicHeader.aes256GcmAlgorithm)
      ..uint(BackupPublicHeader.aes256GcmAlgorithm)
      ..uint(BackupPublicHeader.cvaultContainerAlgorithm);
    return writer.takeBytes();
  }

  /// Decodes, validates bounds, and rejects non-canonical encodings.
  static BackupPublicHeader decode(
    List<int> bytes, {
    VaultImportPolicy policy = const VaultImportPolicy(),
  }) {
    policy.validatePublicHeaderLength(bytes.length);
    try {
      final reader = CanonicalCborReader(bytes);
      if (reader.array(maximumLength: 13) != 13 ||
          reader.text(maximumBytes: 64) !=
              BackupPublicHeader.formatIdentifier) {
        throw const InvalidBackupFormatFailure('header_shape');
      }
      final version = reader.uint(maximum: 0xFFFF);
      if (version != BackupPublicHeader.currentVersion) {
        throw const UnsupportedBackupVersionFailure();
      }
      final parameters = RecoveryKdfParameters(
        algorithm: RecoveryKdfAlgorithm.fromWireId(
          reader.uint(maximum: 0xFF),
        ),
        iterations: reader.uint(maximum: 5000000),
        memoryKiB: reader.uint(maximum: 256 * 1024),
        parallelism: reader.uint(maximum: 32),
        outputLength: reader.uint(maximum: 64),
      );
      final salt = reader.byteString(maximumLength: 64);
      policy.validateKdf(parameters, saltLength: salt.length);
      if (reader.text(maximumBytes: 64) !=
              BackupPublicHeader.recoveryEnvelopeEntry ||
          reader.text(maximumBytes: 64) !=
              BackupPublicHeader.encryptedManifestEntry ||
          reader.uint(maximum: 0xFF) != BackupPublicHeader.aes256GcmAlgorithm ||
          reader.uint(maximum: 0xFF) != BackupPublicHeader.aes256GcmAlgorithm ||
          reader.uint(maximum: 0xFF) !=
              BackupPublicHeader.cvaultContainerAlgorithm ||
          !reader.isDone) {
        throw const InvalidBackupFormatFailure('header_algorithms');
      }
      final header = BackupPublicHeader(
        kdfParameters: parameters,
        kdfSalt: salt,
      );
      if (!_equal(encode(header), bytes)) {
        throw const InvalidBackupFormatFailure('header_non_canonical');
      }
      return header;
    } on BackupFailure {
      rethrow;
    } on VaultCryptoFailure {
      rethrow;
    } on Object catch (error) {
      throw InvalidBackupFormatFailure('header_parse', cause: error);
    }
  }
}

/// Canonical CBOR codec for the backup recovery envelope.
abstract final class BackupRecoveryEnvelopeCodec {
  static Uint8List encode(BackupRecoveryEnvelope envelope) {
    final writer = CanonicalCborWriter()
      ..array(4)
      ..uint(1)
      ..byteString(envelope.nonce)
      ..byteString(envelope.ciphertext)
      ..byteString(envelope.authenticationTag);
    return writer.takeBytes();
  }

  static BackupRecoveryEnvelope decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > 1024) {
      throw const InvalidBackupFormatFailure('recovery_envelope_size');
    }
    final reader = CanonicalCborReader(bytes);
    if (reader.array(maximumLength: 4) != 4 || reader.uint(maximum: 1) != 1) {
      throw const UnsupportedBackupVersionFailure();
    }
    final envelope = BackupRecoveryEnvelope(
      nonce: reader.byteString(maximumLength: 12),
      ciphertext: reader.byteString(maximumLength: 64),
      authenticationTag: reader.byteString(maximumLength: 16),
    );
    if (!reader.isDone ||
        envelope.nonce.length != 12 ||
        envelope.ciphertext.length != 64 ||
        envelope.authenticationTag.length != 16 ||
        !_equal(encode(envelope), bytes)) {
      throw const InvalidBackupFormatFailure('recovery_envelope_shape');
    }
    return envelope;
  }
}

/// Canonical confidential manifest codec.
abstract final class BackupManifestCodec {
  static const String _identifier = 'citizen-vault-manifest';

  static Uint8List encode(BackupManifest manifest) {
    _validateOrdering(manifest);
    final writer = CanonicalCborWriter()
      ..array(15)
      ..text(_identifier)
      ..uint(BackupManifest.currentVersion)
      ..text(manifest.generationId)
      ..text(manifest.vaultId)
      ..uint(manifest.createdAt.toUtc().millisecondsSinceEpoch ~/ 1000)
      ..uint(manifest.databaseSchemaVersion)
      ..uint(manifest.encryptionFormatVersion)
      ..uint(manifest.objectFormatVersion)
      ..uint(manifest.backupFormatVersion)
      ..uint(manifest.minimumReaderVersion)
      ..uint(manifest.snapshotSize)
      ..byteString(manifest.snapshotSha256)
      ..array(manifest.objects.length);
    for (final object in manifest.objects) {
      writer
        ..array(3)
        ..text(object.objectId)
        ..uint(object.encryptedSize)
        ..byteString(object.encryptedSha256);
    }
    writer.array(manifest.requiredAlgorithmVersions.length);
    manifest.requiredAlgorithmVersions.forEach(writer.uint);
    writer.array(manifest.pipelineVersions.length);
    manifest.pipelineVersions.forEach(writer.uint);
    return writer.takeBytes();
  }

  static BackupManifest decode(
    List<int> bytes, {
    VaultImportPolicy policy = const VaultImportPolicy(),
  }) {
    if (bytes.isEmpty || bytes.length > policy.maximumManifestBytes) {
      throw const InvalidBackupFormatFailure('manifest_size');
    }
    final reader = CanonicalCborReader(bytes);
    if (reader.array(maximumLength: 15) != 15 ||
        reader.text(maximumBytes: 64) != _identifier) {
      throw const InvalidBackupFormatFailure('manifest_shape');
    }
    final version = reader.uint(maximum: 0xFFFF);
    if (version != BackupManifest.currentVersion) {
      throw const UnsupportedBackupVersionFailure();
    }
    final generationId = reader.text(maximumBytes: 128);
    final vaultId = reader.text(maximumBytes: 128);
    final identifierPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (!identifierPattern.hasMatch(generationId) ||
        !identifierPattern.hasMatch(vaultId)) {
      throw const InvalidBackupFormatFailure('manifest_identifier');
    }
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      reader.uint(maximum: 253402300799) * 1000,
      isUtc: true,
    );
    final databaseSchemaVersion = reader.uint(maximum: 0xFFFF);
    final encryptionFormatVersion = reader.uint(maximum: 0xFFFF);
    final objectFormatVersion = reader.uint(maximum: 0xFFFF);
    final backupFormatVersion = reader.uint(maximum: 0xFFFF);
    final minimumReaderVersion = reader.uint(maximum: 0xFFFF);
    final snapshotSize = reader.uint(
      maximum: policy.maximumDeclaredPlaintextBytes,
    );
    final snapshotDigest = reader.byteString(maximumLength: 32);
    if (snapshotDigest.length != 32) {
      throw const InvalidBackupFormatFailure('snapshot_digest');
    }
    final objectCount = reader.array(
      maximumLength: policy.maximumArchiveEntries,
    );
    final objects = <BackupManifestObject>[];
    for (var index = 0; index < objectCount; index += 1) {
      if (reader.array(maximumLength: 3) != 3) {
        throw const InvalidBackupFormatFailure('object_shape');
      }
      final id = reader.text(maximumBytes: 64);
      if (!RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(id)) {
        throw const InvalidBackupFormatFailure('object_id');
      }
      final size = reader.uint(maximum: policy.maximumObjectBytes);
      final digest = reader.byteString(maximumLength: 32);
      if (digest.length != 32) {
        throw const InvalidBackupFormatFailure('object_digest');
      }
      objects.add(
        BackupManifestObject(
          objectId: id,
          encryptedSize: size,
          encryptedSha256: digest,
        ),
      );
    }
    final requiredCount = reader.array(maximumLength: 32);
    final required = <int>[
      for (var index = 0; index < requiredCount; index += 1)
        reader.uint(maximum: 0xFFFF),
    ];
    final pipelineCount = reader.array(maximumLength: 10000);
    final pipelines = <int>[
      for (var index = 0; index < pipelineCount; index += 1)
        reader.uint(maximum: 0x7FFFFFFF),
    ];
    if (!reader.isDone) {
      throw const InvalidBackupFormatFailure('manifest_trailing');
    }
    final manifest = BackupManifest(
      generationId: generationId,
      vaultId: vaultId,
      createdAt: createdAt,
      databaseSchemaVersion: databaseSchemaVersion,
      encryptionFormatVersion: encryptionFormatVersion,
      objectFormatVersion: objectFormatVersion,
      backupFormatVersion: backupFormatVersion,
      minimumReaderVersion: minimumReaderVersion,
      snapshotSize: snapshotSize,
      snapshotSha256: snapshotDigest,
      objects: objects,
      requiredAlgorithmVersions: required,
      pipelineVersions: pipelines,
    );
    _validateOrdering(manifest);
    if (!_equal(encode(manifest), bytes)) {
      throw const InvalidBackupFormatFailure('manifest_non_canonical');
    }
    return manifest;
  }

  static void _validateOrdering(BackupManifest manifest) {
    if (manifest.minimumReaderVersion > BackupManifest.currentVersion) {
      throw const UnsupportedBackupVersionFailure();
    }
    final objectIds = manifest.objects
        .map((object) => object.objectId)
        .toList();
    final sortedObjectIds = List<String>.from(objectIds)..sort();
    if (!_listEqual(objectIds, sortedObjectIds) ||
        objectIds.toSet().length != objectIds.length) {
      throw const InvalidBackupFormatFailure('object_order');
    }
    if (!_isStrictlyIncreasing(manifest.requiredAlgorithmVersions) ||
        !_isStrictlyIncreasing(manifest.pipelineVersions)) {
      throw const InvalidBackupFormatFailure('version_order');
    }
  }
}

/// Binary AES-GCM envelope for the encrypted manifest bytes.
abstract final class EncryptedManifestCodec {
  static const List<int> _magic = <int>[0x43, 0x56, 0x4D, 0x31]; // CVM1

  static Uint8List encode({
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> tag,
  }) {
    if (nonce.length != 12 ||
        tag.length != 16 ||
        ciphertext.length > 0xFFFFFFFF) {
      throw const InvalidBackupFormatFailure('encrypted_manifest_shape');
    }
    final output = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(<int>[0, 1])
      ..add(nonce)
      ..add(_u32(ciphertext.length))
      ..add(ciphertext)
      ..add(tag);
    return output.takeBytes();
  }

  static ({Uint8List nonce, Uint8List ciphertext, Uint8List tag}) decode(
    List<int> bytes, {
    required int maximumCiphertextBytes,
  }) {
    const fixed = 4 + 2 + 12 + 4 + 16;
    if (bytes.length < fixed || !_equal(bytes.sublist(0, 4), _magic)) {
      throw const InvalidBackupFormatFailure('encrypted_manifest_magic');
    }
    if (bytes[4] != 0 || bytes[5] != 1) {
      throw const UnsupportedBackupVersionFailure();
    }
    final length = _readU32(bytes, 18);
    if (length > maximumCiphertextBytes || bytes.length != fixed + length) {
      throw const InvalidBackupFormatFailure('encrypted_manifest_length');
    }
    return (
      nonce: Uint8List.fromList(bytes.sublist(6, 18)),
      ciphertext: Uint8List.fromList(bytes.sublist(22, 22 + length)),
      tag: Uint8List.fromList(bytes.sublist(22 + length)),
    );
  }
}

List<int> _u32(int value) => <int>[
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

int _readU32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

bool _equal(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

bool _listEqual<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _isStrictlyIncreasing(List<int> values) {
  for (var index = 1; index < values.length; index += 1) {
    if (values[index] <= values[index - 1]) return false;
  }
  return true;
}
