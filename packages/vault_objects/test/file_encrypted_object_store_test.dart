import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_objects/vault_objects.dart';

void main() {
  const chunkSize = 64 * 1024;
  final objectId = ObjectId.parse('00000000000000000000000001');

  group('FileEncryptedObjectStore', () {
    late Directory directory;
    late VaultFileRootKey rootKey;
    late _DeterministicRandom random;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('vault_objects_test_');
      rootKey = VaultFileRootKey.fromBytes(
        List<int>.generate(32, (index) => 0x80 + index),
        keyVersion: 3,
      );
      random = _DeterministicRandom();
    });

    tearDown(() {
      rootKey.destroy();
      directory.deleteSync(recursive: true);
    });

    for (final testCase in <(String, int)>[
      ('empty file', 0),
      ('one-byte file', 1),
      ('smaller than one chunk', chunkSize - 1),
      ('exact chunk size', chunkSize),
      ('multiple chunks', chunkSize * 3 + 17),
    ]) {
      test('round-trips ${testCase.$1}', () async {
        final plaintext = _patternBytes(testCase.$2);
        final store = _store(directory, random);
        final result = await store.put(
          plaintext: _segmentedStream(plaintext, 7919),
          objectId: objectId,
          fileRootKey: rootKey,
          chunkSize: chunkSize,
        );

        expect(result.plaintextSize, plaintext.length);
        expect(
          result.chunkCount,
          plaintext.isEmpty
              ? 0
              : (plaintext.length + chunkSize - 1) ~/ chunkSize,
        );
        expect(await store.exists(objectId), isTrue);
        expect(
          await _collect(store.read(objectId: objectId, fileRootKey: rootKey)),
          plaintext,
        );
        await store.verify(objectId: objectId, fileRootKey: rootKey);
        expect(_partialFiles(directory), isEmpty);
      });
    }

    test(
      'startup cleanup removes only recognized interrupted writes',
      () async {
        final objects = Directory('${directory.path}/objects')..createSync();
        final partial = File(
          '${objects.path}/${objectId.value}.bin.partial.0011223344556677',
        )..writeAsBytesSync(<int>[1, 2, 3]);
        final unrelated = File('${objects.path}/keep.partial.note')
          ..writeAsBytesSync(<int>[4]);
        final store = _store(directory, random);

        expect(await store.cleanupInterruptedWrites(), 1);
        expect(partial.existsSync(), isFalse);
        expect(unrelated.existsSync(), isTrue);
        expect(await store.cleanupInterruptedWrites(), 0);
      },
    );

    test('supports authenticated ranges crossing chunk boundaries', () async {
      final plaintext = _patternBytes(chunkSize * 2 + 100);
      final store = _store(directory, random);
      await store.put(
        plaintext: Stream<List<int>>.value(plaintext),
        objectId: objectId,
        fileRootKey: rootKey,
        chunkSize: chunkSize,
      );
      const range = ByteRange(
        start: chunkSize - 23,
        endExclusive: chunkSize + 41,
      );
      expect(
        await _collect(
          store.read(
            objectId: objectId,
            fileRootKey: rootKey,
            range: range,
          ),
        ),
        plaintext.sublist(range.start, range.endExclusive),
      );
    });

    test(
      '64 MiB stream remains bounded and meets the performance budget',
      () async {
        const sourceSegmentSize = 8191;
        const totalBytes = 64 * 1024 * 1024 + 7;
        var emitted = 0;
        var largestSourceSegment = 0;
        Stream<List<int>> generated() async* {
          while (emitted < totalBytes) {
            final length = totalBytes - emitted < sourceSegmentSize
                ? totalBytes - emitted
                : sourceSegmentSize;
            if (length > largestSourceSegment) largestSourceSegment = length;
            yield Uint8List.fromList(
              List<int>.generate(length, (index) => (emitted + index) & 0xFF),
            );
            emitted += length;
          }
        }

        final store = _store(directory, random);
        final stopwatch = Stopwatch()..start();
        final result = await store.put(
          plaintext: generated(),
          objectId: objectId,
          fileRootKey: rootKey,
          chunkSize: chunkSize,
        );
        await store.verify(objectId: objectId, fileRootKey: rootKey);
        stopwatch.stop();
        expect(result.plaintextSize, totalBytes);
        expect(emitted, totalBytes);
        expect(largestSourceSegment, lessThanOrEqualTo(sourceSegmentSize));
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 90)));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('rejects a wrong File Root Key', () async {
      final store = _store(directory, random);
      await _putTwoChunks(store, objectId, rootKey, chunkSize);
      final wrongKey = VaultFileRootKey.fromBytes(
        List<int>.filled(32, 0x55),
        keyVersion: rootKey.keyVersion,
      );
      addTearDown(wrongKey.destroy);

      await expectLater(
        _collect(store.read(objectId: objectId, fileRootKey: wrongKey)),
        throwsA(isA<ObjectAuthenticationFailure>()),
      );
    });

    test('rejects an invalid wrapped File Data Key', () async {
      final store = _store(directory, random);
      await _putTwoChunks(store, objectId, rootKey, chunkSize);
      await _flipByte(_objectFile(directory, objectId), 79);

      await expectLater(
        _collect(store.read(objectId: objectId, fileRootKey: rootKey)),
        throwsA(isA<ObjectAuthenticationFailure>()),
      );
    });

    test('reports the exact modified chunk internally', () async {
      final store = _store(directory, random);
      await _putTwoChunks(store, objectId, rootKey, chunkSize);
      const secondCiphertext =
          ObjectHeaderV1.encodedLength + (16 + chunkSize + 16) + 16;
      await _flipByte(_objectFile(directory, objectId), secondCiphertext);

      try {
        await _collect(store.read(objectId: objectId, fileRootKey: rootKey));
        fail('Expected authentication failure');
      } on CorruptObjectFailure catch (error) {
        expect(error.chunkIndex, 1);
        expect(error.toString(), isNot(contains('1')));
      }
    });

    test('rejects a missing final chunk', () async {
      final store = _store(directory, random);
      await _putTwoChunks(store, objectId, rootKey, chunkSize);
      final file = _objectFile(directory, objectId);
      final truncatedLength = file.lengthSync() - 32;
      file.openSync(mode: FileMode.append)
        ..truncateSync(truncatedLength)
        ..closeSync();

      await expectLater(
        _collect(store.read(objectId: objectId, fileRootKey: rootKey)),
        throwsA(isA<CorruptObjectFailure>()),
      );
    });

    test('rejects reordered chunks', () async {
      final store = _store(directory, random);
      await _putTwoChunks(store, objectId, rootKey, chunkSize);
      const recordLength = 16 + chunkSize + 16;
      await _swapRecords(
        _objectFile(directory, objectId),
        ObjectHeaderV1.encodedLength,
        recordLength,
      );

      await expectLater(
        _collect(store.read(objectId: objectId, fileRootKey: rootKey)),
        throwsA(isA<CorruptObjectFailure>()),
      );
    });

    test('rejects duplicated chunks', () async {
      final store = _store(directory, random);
      await _putTwoChunks(store, objectId, rootKey, chunkSize);
      final file = _objectFile(directory, objectId);
      const recordLength = 16 + chunkSize + 16;
      final writer = file.openSync(mode: FileMode.append);
      final first = (writer..setPositionSync(ObjectHeaderV1.encodedLength))
          .readSync(recordLength);
      writer
        ..setPositionSync(ObjectHeaderV1.encodedLength + recordLength)
        ..writeFromSync(first)
        ..flushSync()
        ..closeSync();

      await expectLater(
        _collect(store.read(objectId: objectId, fileRootKey: rootKey)),
        throwsA(isA<CorruptObjectFailure>()),
      );
    });

    test(
      'cancellation interrupts write and removes temporary output',
      () async {
        final cancellation = CancellationToken();
        Stream<List<int>> cancellingSource() async* {
          yield _patternBytes(chunkSize);
          cancellation.cancel();
          yield _patternBytes(chunkSize);
        }

        final store = _store(directory, random);
        await expectLater(
          store.put(
            plaintext: cancellingSource(),
            objectId: objectId,
            fileRootKey: rootKey,
            chunkSize: chunkSize,
            cancellationToken: cancellation,
          ),
          throwsA(isA<ObjectOperationCancelledFailure>()),
        );
        expect(await store.exists(objectId), isFalse);
        expect(_partialFiles(directory), isEmpty);
      },
    );

    test(
      'cancellation interrupts decryption after an authenticated chunk',
      () async {
        final store = _store(directory, random);
        await _putTwoChunks(store, objectId, rootKey, chunkSize);
        final cancellation = CancellationToken();
        final iterator = StreamIterator<List<int>>(
          store.read(
            objectId: objectId,
            fileRootKey: rootKey,
            cancellationToken: cancellation,
          ),
        );
        expect(await iterator.moveNext(), isTrue);
        cancellation.cancel();
        await expectLater(
          iterator.moveNext(),
          throwsA(isA<ObjectOperationCancelledFailure>()),
        );
        await iterator.cancel();
      },
    );

    test('simulated storage exhaustion removes partial output', () async {
      final store = _store(
        directory,
        random,
        faults: const _FailingFaults(failWriteAfter: 1000),
      );
      await expectLater(
        store.put(
          plaintext: Stream<List<int>>.value(_patternBytes(chunkSize * 2)),
          objectId: objectId,
          fileRootKey: rootKey,
          chunkSize: chunkSize,
        ),
        throwsA(isA<ObjectWriteFailure>()),
      );
      expect(await store.exists(objectId), isFalse);
      expect(_partialFiles(directory), isEmpty);
    });

    test('rename interruption never exposes an incomplete object', () async {
      final store = _store(
        directory,
        random,
        faults: const _FailingFaults(failBeforeRename: true),
      );
      await expectLater(
        store.put(
          plaintext: Stream<List<int>>.value(_patternBytes(100)),
          objectId: objectId,
          fileRootKey: rootKey,
          chunkSize: chunkSize,
        ),
        throwsA(isA<ObjectWriteFailure>()),
      );
      expect(await store.exists(objectId), isFalse);
      expect(_partialFiles(directory), isEmpty);
    });

    test('never overwrites an immutable object', () async {
      final store = _store(directory, random);
      await store.put(
        plaintext: Stream<List<int>>.value(<int>[1]),
        objectId: objectId,
        fileRootKey: rootKey,
        chunkSize: chunkSize,
      );
      await expectLater(
        store.put(
          plaintext: Stream<List<int>>.value(<int>[2]),
          objectId: objectId,
          fileRootKey: rootKey,
          chunkSize: chunkSize,
        ),
        throwsA(isA<ObjectAlreadyExistsFailure>()),
      );
      expect(
        await _collect(store.read(objectId: objectId, fileRootKey: rootKey)),
        <int>[1],
      );
    });
  });

  group('database retention integration', () {
    late Directory directory;
    late SecretBytes databaseKey;
    late VaultDatabaseSession databaseSession;
    late VaultFileRootKey rootKey;

    setUp(() async {
      directory = Directory.systemTemp.createTempSync('vault_retention_test_');
      databaseKey = SecretBytes(List<int>.generate(32, (index) => index + 1));
      databaseSession = await EncryptedDatabaseOpener.open(
        file: File('${directory.path}/vault.db'),
        databaseKey: databaseKey,
        runInBackground: false,
      );
      rootKey = VaultFileRootKey.fromBytes(
        List<int>.generate(32, (index) => 0x40 + index),
        keyVersion: 1,
      );
    });

    tearDown(() async {
      rootKey.destroy();
      await databaseSession.close();
      databaseKey.destroy();
      directory.deleteSync(recursive: true);
    });

    test(
      'registers only committed files and deletes after retention',
      () async {
        final repository = DatabaseObjectRetentionRepository(
          databaseSession,
          retentionPeriod: Duration.zero,
        );
        final store = FileEncryptedObjectStore(
          rootDirectory: directory,
          random: _DeterministicRandom(),
          retentionRepository: repository,
        );
        final result = await store.put(
          plaintext: Stream<List<int>>.value(_patternBytes(1234)),
          objectId: objectId,
          fileRootKey: rootKey,
          chunkSize: chunkSize,
        );

        final persisted = await repository.integrityFor(objectId);
        expect(persisted, isNotNull);
        expect(persisted!.plaintextSha256, result.plaintextSha256);
        expect(persisted.chunkCount, result.chunkCount);
        await store.markForDeletion(objectId);
        await store.deleteWhenUnreferenced(objectId);
        expect(await store.exists(objectId), isFalse);
        expect(await repository.integrityFor(objectId), isNull);
      },
    );

    test('active document reference blocks physical deletion', () async {
      final repository = DatabaseObjectRetentionRepository(
        databaseSession,
        retentionPeriod: Duration.zero,
      );
      final store = FileEncryptedObjectStore(
        rootDirectory: directory,
        random: _DeterministicRandom(),
        retentionRepository: repository,
      );
      final result = await store.put(
        plaintext: Stream<List<int>>.value(_patternBytes(32)),
        objectId: objectId,
        fileRootKey: rootKey,
        chunkSize: chunkSize,
      );
      await databaseSession.write((database) async {
        await database.customStatement(
          '''
          INSERT INTO documents(
            id, logical_filename, mime_type, source_type, status,
            primary_object_id, plaintext_sha256, plaintext_size,
            encrypted_size, imported_at, updated_at, integrity_status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          <Object>[
            'document-1',
            'fixture.bin',
            'application/octet-stream',
            'TEST',
            'READY',
            objectId.value,
            result.plaintextSha256,
            result.plaintextSize,
            result.encryptedSize,
            1,
            1,
            'VERIFIED',
          ],
        );
      });
      await store.markForDeletion(objectId);

      await expectLater(
        store.deleteWhenUnreferenced(objectId),
        throwsA(isA<ObjectRetentionFailure>()),
      );
      expect(await store.exists(objectId), isTrue);
    });

    test('backup inventory blocks physical deletion', () async {
      final repository = DatabaseObjectRetentionRepository(
        databaseSession,
        retentionPeriod: Duration.zero,
      );
      final store = FileEncryptedObjectStore(
        rootDirectory: directory,
        random: _DeterministicRandom(),
        retentionRepository: repository,
      );
      final result = await store.put(
        plaintext: Stream<List<int>>.value(_patternBytes(64)),
        objectId: objectId,
        fileRootKey: rootKey,
        chunkSize: chunkSize,
      );
      await databaseSession.write((database) async {
        await database.customStatement(
          'INSERT INTO backup_generations(id, status, created_at) '
          'VALUES (?, ?, ?)',
          <Object>['generation-1', 'VERIFIED', 1],
        );
        await database.customStatement(
          '''
          INSERT INTO backup_generation_objects(
            generation_id, object_id, plaintext_sha256, encrypted_size
          ) VALUES (?, ?, ?, ?)
          ''',
          <Object>[
            'generation-1',
            objectId.value,
            result.plaintextSha256,
            result.encryptedSize,
          ],
        );
      });
      await store.markForDeletion(objectId);

      await expectLater(
        store.deleteWhenUnreferenced(objectId),
        throwsA(isA<ObjectRetentionFailure>()),
      );
      expect(await store.exists(objectId), isTrue);
    });

    test('failed verification records corrupted integrity state', () async {
      final repository = DatabaseObjectRetentionRepository(
        databaseSession,
        retentionPeriod: Duration.zero,
      );
      final store = FileEncryptedObjectStore(
        rootDirectory: directory,
        random: _DeterministicRandom(),
        retentionRepository: repository,
      );
      await store.put(
        plaintext: Stream<List<int>>.value(_patternBytes(64)),
        objectId: objectId,
        fileRootKey: rootKey,
        chunkSize: chunkSize,
      );
      await _flipByte(
        _objectFile(directory, objectId),
        ObjectHeaderV1.encodedLength + 16,
      );

      await expectLater(
        store.verify(objectId: objectId, fileRootKey: rootKey),
        throwsA(isA<CorruptObjectFailure>()),
      );
      final status = await databaseSession.read(
        (database) => database
            .customSelect(
              'SELECT verification_status FROM object_references '
              'WHERE object_id = ?',
              variables: <Variable<Object>>[
                Variable<String>(objectId.value),
              ],
            )
            .getSingle(),
      );
      expect(status.read<String>('verification_status'), 'CORRUPTED');
    });
  });
}

FileEncryptedObjectStore _store(
  Directory directory,
  CryptographicRandom random, {
  ObjectStoreFaultInjector faults = const NoObjectStoreFaults(),
}) => FileEncryptedObjectStore(
  rootDirectory: directory,
  random: random,
  faultInjector: faults,
);

Future<void> _putTwoChunks(
  FileEncryptedObjectStore store,
  ObjectId objectId,
  VaultFileRootKey rootKey,
  int chunkSize,
) => store.put(
  plaintext: Stream<List<int>>.value(_patternBytes(chunkSize * 2)),
  objectId: objectId,
  fileRootKey: rootKey,
  chunkSize: chunkSize,
);

Uint8List _patternBytes(int length) => Uint8List.fromList(
  List<int>.generate(length, (index) => (index * 31 + 7) & 0xFF),
);

Stream<List<int>> _segmentedStream(Uint8List bytes, int segmentSize) async* {
  for (var offset = 0; offset < bytes.length; offset += segmentSize) {
    final end = offset + segmentSize < bytes.length
        ? offset + segmentSize
        : bytes.length;
    yield Uint8List.sublistView(bytes, offset, end);
  }
}

Future<Uint8List> _collect(Stream<List<int>> stream) async {
  final output = BytesBuilder(copy: false);
  await stream.forEach(output.add);
  return output.takeBytes();
}

File _objectFile(Directory root, ObjectId objectId) =>
    File('${root.path}/objects/${objectId.value}.bin');

List<FileSystemEntity> _partialFiles(Directory root) {
  final objects = Directory('${root.path}/objects');
  if (!objects.existsSync()) return const <FileSystemEntity>[];
  return objects
      .listSync()
      .where((entity) => entity.path.contains('.partial.'))
      .toList();
}

Future<void> _flipByte(File file, int offset) async {
  final writer = await file.open(mode: FileMode.append);
  try {
    await writer.setPosition(offset);
    final original = await writer.readByte();
    await writer.setPosition(offset);
    await writer.writeByte(original ^ 0x01);
    await writer.flush();
  } finally {
    await writer.close();
  }
}

Future<void> _swapRecords(File file, int firstOffset, int recordLength) async {
  final writer = await file.open(mode: FileMode.append);
  try {
    await writer.setPosition(firstOffset);
    final first = await writer.read(recordLength);
    final second = await writer.read(recordLength);
    await writer.setPosition(firstOffset);
    await writer.writeFrom(second);
    await writer.writeFrom(first);
    await writer.flush();
  } finally {
    await writer.close();
  }
}

final class _DeterministicRandom implements CryptographicRandom {
  int _next = 0;

  @override
  Future<Uint8List> secureBytes(int length) async => Uint8List.fromList(
    List<int>.generate(length, (_) => _next++ & 0xFF),
  );
}

final class _FailingFaults implements ObjectStoreFaultInjector {
  const _FailingFaults({this.failWriteAfter, this.failBeforeRename = false});

  final int? failWriteAfter;
  final bool failBeforeRename;

  @override
  Future<void> beforeRename() async {
    if (failBeforeRename) throw const FileSystemException('simulated rename');
  }

  @override
  Future<void> beforeWrite(int resultingBytesWritten) async {
    if (failWriteAfter case final limit? when resultingBytesWritten > limit) {
      throw const FileSystemException('simulated storage full');
    }
  }
}
