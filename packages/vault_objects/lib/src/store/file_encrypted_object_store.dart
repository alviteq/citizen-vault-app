import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_objects/src/cancellation/cancellation_token.dart';
import 'package:vault_objects/src/errors/object_store_failure.dart';
import 'package:vault_objects/src/format/object_format_v1.dart';
import 'package:vault_objects/src/model/object_id.dart';
import 'package:vault_objects/src/model/object_store_models.dart';
import 'package:vault_objects/src/model/vault_file_root_key.dart';
import 'package:vault_objects/src/retention/object_retention_repository.dart';
import 'package:vault_objects/src/store/encrypted_object_store.dart';

/// Injectable failure boundary used to prove cleanup and atomic publication.
abstract interface class ObjectStoreFaultInjector {
  /// Called before each bounded physical write.
  Future<void> beforeWrite(int resultingBytesWritten);

  /// Called after verification and immediately before atomic rename.
  Future<void> beforeRename();
}

/// No-op production fault injector.
final class NoObjectStoreFaults implements ObjectStoreFaultInjector {
  /// Creates the no-op injector.
  const NoObjectStoreFaults();

  @override
  Future<void> beforeRename() async {}

  @override
  Future<void> beforeWrite(int resultingBytesWritten) async {}
}

/// Immutable encrypted files stored under random opaque filenames.
final class FileEncryptedObjectStore implements EncryptedObjectStore {
  /// Creates a store rooted in an application-private directory.
  FileEncryptedObjectStore({
    required Directory rootDirectory,
    required this.random,
    ObjectRetentionRepository? retentionRepository,
    this.limits = const ObjectStoreLimits(),
    ObjectStoreFaultInjector faultInjector = const NoObjectStoreFaults(),
  }) : _objectsDirectory = Directory('${rootDirectory.path}/objects'),
       _retention = retentionRepository,
       _faults = faultInjector,
       _aesGcm = crypto.AesGcm.with256bits(),
       _sha256 = crypto.Sha256().toSync();

  final Directory _objectsDirectory;

  /// Randomness source for per-file keys, nonce prefixes, and wrap nonces.
  final CryptographicRandom random;

  final ObjectRetentionRepository? _retention;

  /// Enforced allocation and object-size limits.
  final ObjectStoreLimits limits;
  final ObjectStoreFaultInjector _faults;
  final crypto.AesGcm _aesGcm;
  final crypto.HashAlgorithm _sha256;
  final Set<String> _activeWrites = <String>{};

  @override
  Future<EncryptedObjectWriteResult> put({
    required Stream<List<int>> plaintext,
    required ObjectId objectId,
    required VaultFileRootKey fileRootKey,
    int chunkSize = ObjectFormatV1.defaultChunkSize,
    CancellationToken? cancellationToken,
  }) async {
    limits.validateChunkSize(chunkSize);
    if (fileRootKey.isDestroyed) {
      throw const InvalidObjectInputFailure('file_root_key');
    }
    cancellationToken?.throwIfCancelled();
    if (!_activeWrites.add(objectId.value)) {
      throw const ObjectAlreadyExistsFailure();
    }

    _objectsDirectory.createSync(recursive: true);
    final output = _objectFile(objectId);
    RandomAccessFile? writer;
    File? partial;
    Uint8List? fileDataKey;
    try {
      if (output.existsSync()) throw const ObjectAlreadyExistsFailure();
      fileDataKey = await _randomExact(32, 'file_data_key');
      final noncePrefix = await _randomExact(8, 'chunk_nonce_prefix');
      final wrapNonce = await _randomExact(12, 'file_key_wrap_nonce');
      partial = File(
        '${output.path}.partial.${_hex(noncePrefix)}',
      );
      if (partial.existsSync()) partial.deleteSync();
      writer = await partial.open(mode: FileMode.write);
      var physicalBytesWritten = 0;
      await _write(
        writer,
        Uint8List(ObjectHeaderV1.encodedLength),
        physicalBytesWritten += ObjectHeaderV1.encodedLength,
      );

      final hashSink = _sha256.newHashSink();
      final buffer = Uint8List(chunkSize);
      var buffered = 0;
      var plaintextSize = 0;
      var chunkCount = 0;
      final secretKey = crypto.SecretKey(fileDataKey);
      final binding = ObjectFormatV1.objectBinding(
        objectId: objectId,
        keyVersion: fileRootKey.keyVersion,
        chunkSize: chunkSize,
        noncePrefix: noncePrefix,
      );

      Future<void> encryptBuffered() async {
        if (buffered == 0) return;
        cancellationToken?.throwIfCancelled();
        final cleartext = Uint8List.sublistView(buffer, 0, buffered);
        hashSink.add(cleartext);
        final nonce = ObjectFormatV1.chunkNonce(noncePrefix, chunkCount);
        final aad = ObjectFormatV1.chunkAad(
          objectBinding: binding,
          chunkIndex: chunkCount,
          plaintextLength: buffered,
        );
        final box = await _aesGcm.encrypt(
          cleartext,
          secretKey: secretKey,
          nonce: nonce,
          aad: aad,
        );
        final prefix = _chunkPrefix(
          chunkIndex: chunkCount,
          plaintextLength: buffered,
          ciphertextLength: box.cipherText.length,
        );
        physicalBytesWritten += prefix.length;
        await _write(writer!, prefix, physicalBytesWritten);
        physicalBytesWritten += box.cipherText.length;
        await _write(writer, box.cipherText, physicalBytesWritten);
        physicalBytesWritten += box.mac.bytes.length;
        await _write(writer, box.mac.bytes, physicalBytesWritten);
        plaintextSize += buffered;
        if (plaintextSize > limits.maximumPlaintextSize) {
          throw const InvalidObjectInputFailure('plaintext_size');
        }
        chunkCount += 1;
        buffered = 0;
      }

      await for (final sourceBytes in plaintext) {
        cancellationToken?.throwIfCancelled();
        var sourceOffset = 0;
        while (sourceOffset < sourceBytes.length) {
          final available = chunkSize - buffered;
          final copyLength = sourceBytes.length - sourceOffset < available
              ? sourceBytes.length - sourceOffset
              : available;
          buffer.setRange(
            buffered,
            buffered + copyLength,
            sourceBytes,
            sourceOffset,
          );
          buffered += copyLength;
          sourceOffset += copyLength;
          if (buffered == chunkSize) await encryptBuffered();
        }
      }
      await encryptBuffered();
      hashSink.close();
      final plaintextSha256 = Uint8List.fromList(
        (await hashSink.hash()).bytes,
      );

      final provisionalHeader = ObjectHeaderV1(
        objectId: objectId,
        keyVersion: fileRootKey.keyVersion,
        chunkSize: chunkSize,
        plaintextSize: plaintextSize,
        chunkCount: chunkCount,
        noncePrefix: noncePrefix,
        wrapNonce: wrapNonce,
        wrappedFileKey: Uint8List(32),
        wrappingTag: Uint8List(16),
        headerDigest: Uint8List(32),
      );
      final baseHeader = provisionalHeader.baseBytes();
      final headerDigest = Uint8List.fromList(
        (await _sha256.hash(baseHeader)).bytes,
      );
      final wrappedKey = await fileRootKey.withBytes((rootKeyBytes) {
        return _aesGcm.encrypt(
          fileDataKey!,
          secretKey: crypto.SecretKey(rootKeyBytes),
          nonce: wrapNonce,
          aad: ObjectFormatV1.keyWrapAad(
            baseHeader: baseHeader,
            headerDigest: headerDigest,
          ),
        );
      });
      final header = ObjectHeaderV1(
        objectId: objectId,
        keyVersion: fileRootKey.keyVersion,
        chunkSize: chunkSize,
        plaintextSize: plaintextSize,
        chunkCount: chunkCount,
        noncePrefix: noncePrefix,
        wrapNonce: wrapNonce,
        wrappedFileKey: wrappedKey.cipherText,
        wrappingTag: wrappedKey.mac.bytes,
        headerDigest: headerDigest,
      );
      await writer.setPosition(0);
      await _faults.beforeWrite(physicalBytesWritten);
      await writer.writeFrom(header.encode());
      await writer.flush();
      await writer.close();
      writer = null;

      final verificationHash = _sha256.newHashSink();
      var verifiedBytes = 0;
      await for (final bytes in _readFile(
        partial,
        objectId,
        fileRootKey,
        cancellationToken: cancellationToken,
      )) {
        verificationHash.add(bytes);
        verifiedBytes += bytes.length;
      }
      verificationHash.close();
      if (verifiedBytes != plaintextSize ||
          !_constantTimeEquals(
            (await verificationHash.hash()).bytes,
            plaintextSha256,
          )) {
        throw const CorruptObjectFailure();
      }

      cancellationToken?.throwIfCancelled();
      await _faults.beforeRename();
      if (output.existsSync()) throw const ObjectAlreadyExistsFailure();
      partial.renameSync(output.path);
      final result = EncryptedObjectWriteResult(
        objectId: objectId,
        plaintextSha256: plaintextSha256,
        plaintextSize: plaintextSize,
        encryptedSize: output.lengthSync(),
        chunkCount: chunkCount,
        objectFormatVersion: ObjectFormatV1.version,
        keyVersion: fileRootKey.keyVersion,
      );
      try {
        await _retention?.registerCommitted(result);
      } on Object {
        if (output.existsSync()) output.deleteSync();
        rethrow;
      }
      return result;
    } on ObjectStoreFailure {
      rethrow;
    } on Object catch (error) {
      throw ObjectWriteFailure(cause: error);
    } finally {
      if (writer != null) {
        try {
          await writer.close();
        } on Object {
          // Preserve the original failure.
        }
      }
      fileDataKey?.fillRange(0, fileDataKey.length, 0);
      if (partial != null && partial.existsSync()) {
        partial.deleteSync();
      }
      _activeWrites.remove(objectId.value);
    }
  }

  @override
  Stream<List<int>> read({
    required ObjectId objectId,
    required VaultFileRootKey fileRootKey,
    ByteRange? range,
    CancellationToken? cancellationToken,
  }) => _readFile(
    _objectFile(objectId),
    objectId,
    fileRootKey,
    range: range,
    cancellationToken: cancellationToken,
  );

  @override
  Future<void> verify({
    required ObjectId objectId,
    required VaultFileRootKey fileRootKey,
    CancellationToken? cancellationToken,
  }) async {
    try {
      final file = _objectFile(objectId);
      if (!file.existsSync()) throw const ObjectMissingFailure();
      final header = await _readHeader(file);
      final hashSink = _sha256.newHashSink();
      var plaintextSize = 0;
      await for (final bytes in _readFile(
        file,
        objectId,
        fileRootKey,
        cancellationToken: cancellationToken,
      )) {
        hashSink.add(bytes);
        plaintextSize += bytes.length;
      }
      hashSink.close();
      final digest = (await hashSink.hash()).bytes;
      final persisted = await _retention?.integrityFor(objectId);
      if (persisted != null &&
          (!_constantTimeEquals(digest, persisted.plaintextSha256) ||
              plaintextSize != persisted.plaintextSize ||
              file.lengthSync() != persisted.encryptedSize ||
              header.chunkCount != persisted.chunkCount ||
              persisted.objectFormatVersion != ObjectFormatV1.version ||
              header.keyVersion != persisted.keyVersion)) {
        throw const CorruptObjectFailure();
      }
      await _retention?.recordVerification(
        objectId,
        ObjectVerificationStatus.verified,
      );
    } on ObjectMissingFailure {
      await _safeRecord(objectId, ObjectVerificationStatus.missing);
      rethrow;
    } on UnsupportedObjectFormatFailure {
      await _safeRecord(objectId, ObjectVerificationStatus.unsupportedFormat);
      rethrow;
    } on ObjectStoreFailure {
      await _safeRecord(objectId, ObjectVerificationStatus.corrupted);
      rethrow;
    }
  }

  @override
  Future<bool> exists(ObjectId objectId) async =>
      _objectFile(objectId).existsSync();

  @override
  Future<void> markForDeletion(ObjectId objectId) async {
    if (!await exists(objectId)) throw const ObjectMissingFailure();
    final retention = _retention;
    if (retention == null) throw const ObjectRetentionFailure();
    await retention.markForDeletion(objectId);
  }

  @override
  Future<void> deleteWhenUnreferenced(ObjectId objectId) async {
    final retention = _retention;
    if (retention == null) throw const ObjectRetentionFailure();
    final deleted = await retention.deleteIfEligible(objectId, () async {
      final file = _objectFile(objectId);
      if (file.existsSync()) file.deleteSync();
    });
    if (!deleted) throw const ObjectRetentionFailure();
  }

  @override
  Future<int> cleanupInterruptedWrites() async {
    if (!_objectsDirectory.existsSync()) return 0;
    final partialName = RegExp(
      r'^[0-9A-HJKMNP-TV-Z]{26}\.bin\.partial\.[0-9a-f]{16}$',
    );
    var removed = 0;
    await for (final entity in _objectsDirectory.list(followLinks: false)) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && partialName.hasMatch(name)) {
        entity.deleteSync();
        removed += 1;
      }
    }
    return removed;
  }

  Stream<List<int>> _readFile(
    File file,
    ObjectId expectedObjectId,
    VaultFileRootKey fileRootKey, {
    ByteRange? range,
    CancellationToken? cancellationToken,
  }) async* {
    cancellationToken?.throwIfCancelled();
    if (fileRootKey.isDestroyed) {
      throw const InvalidObjectInputFailure('file_root_key');
    }
    if (!file.existsSync()) throw const ObjectMissingFailure();
    final reader = await file.open();
    Uint8List? fileDataKey;
    try {
      final headerBytes = await _readExact(
        reader,
        ObjectHeaderV1.encodedLength,
      );
      final header = ObjectHeaderV1.decode(headerBytes, limits);
      if (header.objectId != expectedObjectId ||
          header.keyVersion != fileRootKey.keyVersion) {
        throw const ObjectAuthenticationFailure();
      }
      range?.validate(header.plaintextSize);
      final baseHeader = header.baseBytes();
      final digest = (await _sha256.hash(baseHeader)).bytes;
      if (!_constantTimeEquals(digest, header.headerDigest)) {
        throw const ObjectAuthenticationFailure();
      }
      try {
        fileDataKey = await fileRootKey.withBytes((rootKeyBytes) async {
          final bytes = await _aesGcm.decrypt(
            crypto.SecretBox(
              header.wrappedFileKey,
              nonce: header.wrapNonce,
              mac: crypto.Mac(header.wrappingTag),
            ),
            secretKey: crypto.SecretKey(rootKeyBytes),
            aad: ObjectFormatV1.keyWrapAad(
              baseHeader: baseHeader,
              headerDigest: header.headerDigest,
            ),
          );
          if (bytes.length != 32) {
            throw const ObjectAuthenticationFailure();
          }
          return Uint8List.fromList(bytes);
        });
      } on crypto.SecretBoxAuthenticationError catch (error) {
        throw ObjectAuthenticationFailure(cause: error);
      }

      final binding = ObjectFormatV1.objectBinding(
        objectId: header.objectId,
        keyVersion: header.keyVersion,
        chunkSize: header.chunkSize,
        noncePrefix: header.noncePrefix,
      );
      final secretKey = crypto.SecretKey(fileDataKey!);
      var plaintextOffset = 0;
      for (var index = 0; index < header.chunkCount; index += 1) {
        cancellationToken?.throwIfCancelled();
        final prefix = await _readExact(reader, 16, chunkIndex: index);
        if (!_constantTimeEquals(
          prefix.sublist(0, 4),
          ObjectFormatV1.chunkMagic,
        )) {
          throw CorruptObjectFailure(chunkIndex: index);
        }
        final storedIndex = _readU32(prefix, 4);
        final plaintextLength = _readU32(prefix, 8);
        final ciphertextLength = _readU32(prefix, 12);
        final isLast = index == header.chunkCount - 1;
        if (storedIndex != index ||
            plaintextLength < 1 ||
            plaintextLength > header.chunkSize ||
            ciphertextLength != plaintextLength ||
            (!isLast && plaintextLength != header.chunkSize)) {
          throw CorruptObjectFailure(chunkIndex: index);
        }
        final ciphertext = await _readExact(
          reader,
          ciphertextLength,
          chunkIndex: index,
        );
        final tag = await _readExact(
          reader,
          ObjectFormatV1.authenticationTagLength,
          chunkIndex: index,
        );
        final List<int> cleartext;
        try {
          cleartext = await _aesGcm.decrypt(
            crypto.SecretBox(
              ciphertext,
              nonce: ObjectFormatV1.chunkNonce(header.noncePrefix, index),
              mac: crypto.Mac(tag),
            ),
            secretKey: secretKey,
            aad: ObjectFormatV1.chunkAad(
              objectBinding: binding,
              chunkIndex: index,
              plaintextLength: plaintextLength,
            ),
          );
        } on crypto.SecretBoxAuthenticationError catch (error) {
          throw CorruptObjectFailure(chunkIndex: index, cause: error);
        }
        cancellationToken?.throwIfCancelled();
        final chunkStart = plaintextOffset;
        final chunkEnd = chunkStart + cleartext.length;
        plaintextOffset = chunkEnd;
        if (range == null) {
          yield cleartext;
        } else {
          final selectedStart = range.start > chunkStart
              ? range.start
              : chunkStart;
          final selectedEnd = range.endExclusive < chunkEnd
              ? range.endExclusive
              : chunkEnd;
          if (selectedStart < selectedEnd) {
            yield Uint8List.fromList(
              cleartext.sublist(
                selectedStart - chunkStart,
                selectedEnd - chunkStart,
              ),
            );
          }
        }
      }
      if (plaintextOffset != header.plaintextSize ||
          await reader.position() != await reader.length()) {
        throw const CorruptObjectFailure();
      }
    } on ObjectStoreFailure {
      rethrow;
    } on Object catch (error) {
      throw CorruptObjectFailure(cause: error);
    } finally {
      fileDataKey?.fillRange(0, fileDataKey.length, 0);
      await reader.close();
    }
  }

  Future<ObjectHeaderV1> _readHeader(File file) async {
    final reader = await file.open();
    try {
      return ObjectHeaderV1.decode(
        await _readExact(reader, ObjectHeaderV1.encodedLength),
        limits,
      );
    } finally {
      await reader.close();
    }
  }

  Future<Uint8List> _randomExact(int length, String field) async {
    final value = await random.secureBytes(length);
    if (value.length != length) throw InvalidObjectInputFailure(field);
    return Uint8List.fromList(value);
  }

  Future<void> _write(
    RandomAccessFile file,
    List<int> bytes,
    int resultingBytesWritten,
  ) async {
    await _faults.beforeWrite(resultingBytesWritten);
    await file.writeFrom(bytes);
  }

  Future<void> _safeRecord(
    ObjectId objectId,
    ObjectVerificationStatus status,
  ) async {
    try {
      await _retention?.recordVerification(objectId, status);
    } on Object {
      // Preserve the verification failure.
    }
  }

  File _objectFile(ObjectId objectId) =>
      File('${_objectsDirectory.path}/${objectId.value}.bin');

  static Uint8List _chunkPrefix({
    required int chunkIndex,
    required int plaintextLength,
    required int ciphertextLength,
  }) => Uint8List.fromList(<int>[
    ...ObjectFormatV1.chunkMagic,
    ..._u32(chunkIndex),
    ..._u32(plaintextLength),
    ..._u32(ciphertextLength),
  ]);

  static List<int> _u32(int value) => <int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];

  static int _readU32(List<int> bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  static Future<Uint8List> _readExact(
    RandomAccessFile file,
    int length, {
    int? chunkIndex,
  }) async {
    final output = Uint8List(length);
    var offset = 0;
    while (offset < length) {
      final bytes = await file.read(length - offset);
      if (bytes.isEmpty) throw CorruptObjectFailure(chunkIndex: chunkIndex);
      output.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }
    return output;
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index += 1) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
