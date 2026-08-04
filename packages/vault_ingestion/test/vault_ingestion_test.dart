import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:image/image.dart' as image;
import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart' hide OcrEngine;
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';
import 'package:vault_objects/vault_objects.dart';
import 'package:vault_ocr/vault_ocr.dart';

void main() {
  test('declares the milestone seven API version', () {
    expect(VaultIngestionPackage.apiVersion, '0.8.0');
  });

  group('IngestionCoordinator', () {
    late _Harness harness;

    setUp(() async {
      harness = await _Harness.create();
    });

    tearDown(() => harness.dispose());

    test('preserves a file original and waits for review', () async {
      final bytes = Uint8List.fromList(
        List<int>.generate(90000, (index) => (index * 13 + 5) & 0xFF),
      );
      final registration = await harness.coordinator.import(
        _candidate(
          filename: 'statement.pdf',
          mimeType: 'application/pdf',
          bytes: bytes,
        ),
      );

      var jobs = await harness.coordinator.listJobs();
      expect(jobs.single.status, DocumentProcessingStatus.queued);
      expect(
        await harness.coordinator.processUntilIdle(workerId: 'worker-a'),
        1,
      );
      jobs = await harness.coordinator.listJobs();
      expect(jobs.single.status, DocumentProcessingStatus.awaitingReview);
      expect(jobs.single.thumbnailObjectId, isNull);

      final restored = await _collect(
        harness.store.read(
          objectId: registration.originalObjectId,
          fileRootKey: harness.fileRootKey,
        ),
      );
      expect(restored, bytes);
      final row = await harness.session.read(
        (database) => database
            .customSelect(
              'SELECT status FROM documents WHERE id = ?',
              variables: <Variable<Object>>[
                Variable<String>(registration.documentId),
              ],
            )
            .getSingle(),
      );
      expect(row.read<String>('status'), 'NEEDS_REVIEW');
    });

    test('full original lease authenticates and deletes plaintext', () async {
      final plaintextDirectory = Directory('${harness.root.path}/temporary');
      final coordinator = harness.coordinatorWith(
        decryptedAssets: DecryptedAssetLeaseManager(
          directory: plaintextDirectory,
          random: harness.random,
          maximumBytes: const IngestionLimits().maximumFileBytes,
        ),
      );
      final bytes = Uint8List.fromList(
        List<int>.generate(64 * 1024, (index) => (index * 7 + 11) & 0xFF),
      );
      final registration = await coordinator.import(
        _candidate(
          filename: 'complete.pdf',
          mimeType: 'application/pdf',
          bytes: bytes,
        ),
      );

      final lease = await coordinator.originalLease(
        registration.documentId,
        suffix: '.pdf',
      );
      late String plaintextPath;
      final restored = await lease.usePrivatePath((path) async {
        plaintextPath = path;
        expect(File(path).existsSync(), isTrue);
        return File(path).readAsBytes();
      });
      expect(restored, bytes);

      await lease.close();
      expect(File(plaintextPath).existsSync(), isFalse);
    });

    test(
      'creates a separate thumbnail without altering the original',
      () async {
        final source = image.Image(width: 1200, height: 600)
          ..clear(image.ColorRgb8(22, 74, 92));
        final bytes = image.encodePng(source);
        final registration = await harness.coordinator.import(
          _candidate(
            filename: 'identity.png',
            mimeType: 'image/png',
            bytes: bytes,
            source: DocumentImportSource.gallery,
          ),
        );

        expect(
          await harness.coordinator.processUntilIdle(workerId: 'worker-a'),
          1,
        );
        final job = (await harness.coordinator.listJobs()).single;
        expect(job.status, DocumentProcessingStatus.awaitingReview);
        expect(job.thumbnailObjectId, isNotNull);
        expect(
          job.thumbnailObjectId,
          isNot(registration.originalObjectId.value),
        );

        final restoredOriginal = await _collect(
          harness.store.read(
            objectId: registration.originalObjectId,
            fileRootKey: harness.fileRootKey,
          ),
        );
        final thumbnail = await _collect(
          harness.store.read(
            objectId: ObjectId.parse(job.thumbnailObjectId!),
            fileRootKey: harness.fileRootKey,
          ),
        );
        final safePreview = await harness.coordinator.preview(
          registration.documentId,
        );
        expect(restoredOriginal, bytes);
        expect(safePreview, thumbnail);
        final decodedThumbnail = image.decodeJpg(thumbnail);
        expect(decodedThumbnail, isNotNull);
        expect(decodedThumbnail!.width, 384);
        expect(decodedThumbnail.height, 192);
      },
    );

    test('preview corruption is recorded and fails closed', () async {
      final source = image.Image(width: 24, height: 24)
        ..clear(image.ColorRgb8(70, 20, 90));
      final registration = await harness.coordinator.import(
        _candidate(
          filename: 'corrupt-preview.png',
          mimeType: 'image/png',
          bytes: image.encodePng(source),
        ),
      );
      await harness.coordinator.processUntilIdle(workerId: 'worker-a');
      final thumbnailId =
          (await harness.coordinator.listJobs()).single.thumbnailObjectId!;
      final file = File('${harness.root.path}/objects/$thumbnailId.bin');
      final writer = file.openSync(mode: FileMode.append);
      const offset = ObjectHeaderV1.encodedLength + 20;
      writer.setPositionSync(offset);
      final original = writer.readByteSync();
      writer
        ..setPositionSync(offset)
        ..writeByteSync(original ^ 0x80)
        ..closeSync();

      await expectLater(
        harness.coordinator.preview(registration.documentId),
        throwsA(isA<ObjectStoreFailure>()),
      );
      final integrity = await harness.session.read(
        (database) => database
            .customSelect(
              'SELECT integrity_status FROM documents WHERE id = ?',
              variables: <Variable<Object>>[
                Variable<String>(registration.documentId),
              ],
            )
            .getSingle(),
      );
      expect(integrity.read<String>('integrity_status'), 'CORRUPT');
    });

    test('rejects unsupported and length-mismatched sources', () async {
      await expectLater(
        harness.coordinator.import(
          _candidate(
            filename: 'script.exe',
            mimeType: 'application/octet-stream',
            bytes: Uint8List.fromList(<int>[1]),
          ),
        ),
        throwsA(isA<InvalidImportFailure>()),
      );
      await expectLater(
        harness.coordinator.import(
          IngestionCandidate(
            logicalFilename: 'short.pdf',
            mimeType: 'application/pdf',
            length: 4,
            source: DocumentImportSource.filePicker,
            openRead: () => Stream<List<int>>.value(<int>[1, 2]),
          ),
        ),
        throwsA(
          isA<InvalidImportFailure>().having(
            (failure) => failure.code,
            'code',
            'source_length_mismatch',
          ),
        ),
      );
    });

    test(
      'rejects an oversized declared file before opening its stream',
      () async {
        var opened = false;
        await expectLater(
          harness.coordinator.import(
            IngestionCandidate(
              logicalFilename: 'oversized.pdf',
              mimeType: 'application/pdf',
              length: 512 * 1024 * 1024 + 1,
              source: DocumentImportSource.filePicker,
              openRead: () {
                opened = true;
                return const Stream<List<int>>.empty();
              },
            ),
          ),
          throwsA(
            isA<InvalidImportFailure>().having(
              (failure) => failure.code,
              'code',
              'file_size_unsupported',
            ),
          ),
        );
        expect(opened, isFalse);
      },
    );

    test(
      'preserves HEIC originals when a safe decoder is unavailable',
      () async {
        final bytes = Uint8List.fromList(<int>[
          0,
          0,
          0,
          8,
          0x66,
          0x74,
          0x79,
          0x70,
        ]);
        await harness.coordinator.import(
          _candidate(
            filename: 'camera.heic',
            mimeType: 'image/heic',
            bytes: bytes,
            source: DocumentImportSource.gallery,
          ),
        );

        expect(
          await harness.coordinator.processUntilIdle(workerId: 'worker-a'),
          1,
        );
        final job = (await harness.coordinator.listJobs()).single;
        expect(job.status, DocumentProcessingStatus.awaitingReview);
        expect(job.thumbnailObjectId, isNull);
      },
    );

    test('expired worker leases are recovered and reclaimed', () async {
      await harness.coordinator.import(
        _candidate(
          filename: 'lease.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      );
      final first = await harness.jobs.claimNext(
        workerId: 'dead-worker',
        now: harness.clock.now,
        leaseDuration: const Duration(seconds: 5),
      );
      expect(first, isNotNull);
      harness.clock.advance(const Duration(seconds: 6));

      await harness.coordinator.recover();
      expect(
        await harness.coordinator.runNext(workerId: 'replacement'),
        isTrue,
      );
      expect(
        (await harness.coordinator.listJobs()).single.status,
        DocumentProcessingStatus.awaitingReview,
      );
    });

    test('only one worker can claim a queued job', () async {
      await harness.coordinator.import(
        _candidate(
          filename: 'exclusive.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(<int>[4, 5, 6]),
        ),
      );

      final claims = await Future.wait(<Future<IngestionJobLease?>>[
        harness.jobs.claimNext(workerId: 'worker-a', now: harness.clock.now),
        harness.jobs.claimNext(workerId: 'worker-b', now: harness.clock.now),
      ]);
      expect(claims.whereType<IngestionJobLease>(), hasLength(1));
    });

    test('resumption skips an already committed thumbnail step', () async {
      final source = image.Image(width: 16, height: 16)
        ..clear(image.ColorRgb8(10, 20, 30));
      await harness.coordinator.import(
        _candidate(
          filename: 'resume.png',
          mimeType: 'image/png',
          bytes: image.encodePng(source),
        ),
      );
      final lease = (await harness.jobs.claimNext(
        workerId: 'interrupted-worker',
        now: harness.clock.now,
        leaseDuration: const Duration(seconds: 5),
      ))!;
      final thumbnailId = await ObjectId.generate(harness.random);
      final thumbnail = await harness.store.put(
        plaintext: Stream<List<int>>.value(<int>[1, 2, 3, 4]),
        objectId: thumbnailId,
        fileRootKey: harness.fileRootKey,
      );
      await harness.jobs.completeThumbnail(
        lease: lease,
        thumbnailObjectId: thumbnailId,
        thumbnail: thumbnail,
        now: harness.clock.now,
      );
      harness.clock.advance(const Duration(seconds: 6));

      await harness.coordinator.recover();
      expect(
        await harness.coordinator.runNext(workerId: 'replacement'),
        isTrue,
      );
      final assetCount = await harness.session.read(
        (database) => database
            .customSelect(
              'SELECT count(*) AS count FROM document_assets',
            )
            .getSingle(),
      );
      expect(assetCount.read<int>('count'), 2);
      expect(
        (await harness.coordinator.listJobs()).single.status,
        DocumentProcessingStatus.awaitingReview,
      );
    });

    test(
      'unsupported image content is a permanent processing failure',
      () async {
        await harness.coordinator.import(
          _candidate(
            filename: 'broken.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          ),
        );

        expect(await harness.coordinator.runNext(workerId: 'worker-a'), isTrue);
        final job = (await harness.coordinator.listJobs()).single;
        expect(job.status, DocumentProcessingStatus.failed);
        expect(job.attemptCount, 1);
        expect(job.safeErrorCode, 'image_format_unsupported');
      },
    );

    test('transient thumbnail failures stop after bounded retries', () async {
      final failing = harness.coordinatorWith(
        thumbnails: const _FailingThumbnailGenerator(),
      );
      final source = image.Image(width: 8, height: 8)
        ..clear(image.ColorRgb8(1, 2, 3));
      await failing.import(
        _candidate(
          filename: 'retry.png',
          mimeType: 'image/png',
          bytes: image.encodePng(source),
        ),
      );

      for (var attempt = 0; attempt < 5; attempt += 1) {
        expect(await failing.runNext(workerId: 'retry-worker'), isTrue);
        final job = (await failing.listJobs()).single;
        if (attempt < 4) {
          expect(job.status, DocumentProcessingStatus.retryScheduled);
          harness.clock.now = job.availableAfter!;
        }
      }
      final failed = (await failing.listJobs()).single;
      expect(failed.status, DocumentProcessingStatus.failed);
      expect(failed.attemptCount, 5);
      expect(failed.safeErrorCode, 'temporary_thumbnail_failure');
    });

    test('startup recovery tombstones a committed orphan once', () async {
      final orphanId = await ObjectId.generate(harness.random);
      await harness.store.put(
        plaintext: Stream<List<int>>.value(<int>[7, 8, 9]),
        objectId: orphanId,
        fileRootKey: harness.fileRootKey,
      );

      await harness.coordinator.recover();
      await harness.coordinator.recover();
      final count = await harness.session.read(
        (database) => database
            .customSelect(
              'SELECT count(*) AS count FROM object_tombstones '
              'WHERE object_id = ?',
              variables: <Variable<Object>>[Variable<String>(orphanId.value)],
            )
            .getSingle(),
      );
      expect(count.read<int>('count'), 1);
    });

    test(
      'OCR, classification, extraction, review, and FTS are durable',
      () async {
        final source = image.Image(width: 320, height: 180)
          ..clear(image.ColorRgb8(255, 255, 255));
        final temporary = Directory('${harness.root.path}/temporary/ocr');
        final coordinator = harness.coordinatorWith(
          ocrEngine: const _FakePanOcrEngine(),
          decryptedAssets: DecryptedAssetLeaseManager(
            directory: temporary,
            random: harness.random,
          ),
        );
        final registration = await coordinator.import(
          _candidate(
            filename: 'pan-card.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(image.encodePng(source)),
            source: DocumentImportSource.gallery,
          ),
        );

        expect(
          await coordinator.processUntilIdle(workerId: 'ocr-worker'),
          1,
        );
        final job = (await coordinator.listJobs()).single;
        expect(job.status, DocumentProcessingStatus.awaitingReview);
        expect(
          temporary.existsSync() ? temporary.listSync() : <File>[],
          isEmpty,
        );

        final reviews = await coordinator.listReviews();
        expect(reviews, hasLength(1));
        final review = reviews.single;
        expect(review.suggestedType, DocumentType.pan);
        final number = review.fields.singleWhere(
          (field) => field.type == ExtractedFieldType.documentNumber,
        );
        expect(number.effectiveValue, 'ABCDE1234F');
        expect(review.ocrTextPreview, contains('income tax department'));

        final indexed = await coordinator.search('ABCDE1234F');
        expect(indexed.single.documentId, registration.documentId);
        expect(
          (await coordinator.search('ABCDE')).single.documentId,
          registration.documentId,
        );
        expect(
          (await coordinator.search('department income')).single.documentId,
          registration.documentId,
        );

        await coordinator.confirmReview(
          documentId: registration.documentId,
          documentType: DocumentType.pan,
          fields: <ConfirmedFieldEdit>[
            for (final field in review.fields)
              ConfirmedFieldEdit(
                fieldId: field.id,
                value: field.effectiveValue,
              ),
          ],
        );
        expect(
          (await coordinator.listJobs()).single.status,
          DocumentProcessingStatus.ready,
        );
        expect(await coordinator.listReviews(), isEmpty);

        final persisted = await harness.session.read(
          (database) => database
              .customSelect(
                '''
                SELECT d.document_type, f.confirmed_by_user,
                  (SELECT count(*) FROM document_assets a
                    WHERE a.document_id = d.id
                    AND a.asset_type = 'OCR_LAYOUT') AS layouts
                FROM documents d
                JOIN extracted_fields f ON f.document_id = d.id
                  AND f.field_type = 'DOCUMENT_NUMBER'
                WHERE d.id = ?
                ''',
                variables: <Variable<Object>>[
                  Variable<String>(registration.documentId),
                ],
              )
              .getSingle(),
        );
        expect(persisted.read<String>('document_type'), 'PAN');
        expect(persisted.read<int>('confirmed_by_user'), 1);
        expect(persisted.read<int>('layouts'), 1);
      },
    );
  });
}

IngestionCandidate _candidate({
  required String filename,
  required String mimeType,
  required Uint8List bytes,
  DocumentImportSource source = DocumentImportSource.filePicker,
}) => IngestionCandidate(
  logicalFilename: filename,
  mimeType: mimeType,
  length: bytes.length,
  source: source,
  openRead: () => Stream<List<int>>.value(bytes),
);

Future<Uint8List> _collect(Stream<List<int>> source) async {
  final output = BytesBuilder(copy: false);
  await source.forEach(output.add);
  return output.takeBytes();
}

final class _Harness {
  _Harness({
    required this.root,
    required this.session,
    required this.fileRootKey,
    required this.random,
    required this.store,
    required this.jobs,
    required this.clock,
    required this.coordinator,
  });

  static Future<_Harness> create() async {
    final root = Directory.systemTemp.createTempSync('vault_ingestion_test_');
    final master = SecretBytes(List<int>.generate(32, (index) => index));
    final derived = await VaultKeyHierarchy().deriveAll(
      masterKey: master,
      vaultSalt: List<int>.generate(32, (index) => index + 32),
    );
    final databaseKey = SecretBytes(
      derived[VaultSubkeyContext.database].extractBytes(),
    );
    final session = await EncryptedDatabaseOpener.open(
      file: File('${root.path}/vault.db'),
      databaseKey: databaseKey,
      runInBackground: false,
    );
    databaseKey.destroy();
    final fileRootBytes = derived[VaultSubkeyContext.fileRoot].extractBytes();
    final fileRootKey = VaultFileRootKey.fromBytes(
      fileRootBytes,
      keyVersion: 1,
    );
    fileRootBytes.fillRange(0, fileRootBytes.length, 0);
    derived.destroy();
    master.destroy();
    final random = _TestRandom();
    final store = FileEncryptedObjectStore(
      rootDirectory: root,
      random: random,
      retentionRepository: DatabaseObjectRetentionRepository(session),
    );
    final jobs = IngestionJobRepository(session);
    final clock = _MutableClock(DateTime.utc(2026, 7, 16, 12));
    final coordinator = IngestionCoordinator(
      jobs: jobs,
      objectStore: store,
      fileRootKey: fileRootKey,
      random: random,
      clock: () => clock.now,
    );
    return _Harness(
      root: root,
      session: session,
      fileRootKey: fileRootKey,
      random: random,
      store: store,
      jobs: jobs,
      clock: clock,
      coordinator: coordinator,
    );
  }

  final Directory root;
  final VaultDatabaseSession session;
  final VaultFileRootKey fileRootKey;
  final _TestRandom random;
  final FileEncryptedObjectStore store;
  final IngestionJobRepository jobs;
  final _MutableClock clock;
  final IngestionCoordinator coordinator;

  IngestionCoordinator coordinatorWith({
    ThumbnailGenerator thumbnails = const IsolateThumbnailGenerator(),
    OcrEngine ocrEngine = const DisabledOcrEngine(),
    DecryptedAssetLeaseManager? decryptedAssets,
  }) => IngestionCoordinator(
    jobs: jobs,
    objectStore: store,
    fileRootKey: fileRootKey,
    random: random,
    thumbnails: thumbnails,
    ocrEngine: ocrEngine,
    decryptedAssets: decryptedAssets,
    clock: () => clock.now,
  );

  Future<void> dispose() async {
    await session.close();
    fileRootKey.destroy();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

final class _FakePanOcrEngine implements OcrEngine {
  const _FakePanOcrEngine();

  @override
  String get engineId => 'fixture-pan-ocr';

  @override
  String get engineVersion => '1';

  @override
  Future<OcrCapabilities> capabilities() async => OcrCapabilities(
    supportedMimeTypes: const <String>{'image/png'},
    supportedScripts: const <String>{'Latn'},
    supportedLanguages: const <String>{'en'},
    supportsLayout: true,
    supportsTables: false,
  );

  @override
  Future<OcrResult> recognize(OcrRequest request) async {
    final exists = await request.input.usePrivatePath(
      (path) async => File(path).existsSync(),
    );
    if (!exists) {
      throw const OcrFailure('fixture_input_missing', transient: false);
    }
    const lines = <String>[
      'INCOME TAX DEPARTMENT',
      'PERMANENT ACCOUNT NUMBER',
      'ABCDE1234F',
      'Date of Birth 15/08/1990',
    ];
    final block = OcrBlock(
      id: 'p1-b1',
      text: lines.join('\n'),
      lines: <OcrLine>[
        for (var index = 0; index < lines.length; index += 1)
          OcrLine(
            id: 'p1-b1-l${index + 1}',
            text: lines[index],
            words: <OcrWord>[
              OcrWord(
                id: 'p1-b1-l${index + 1}-w1',
                text: lines[index],
              ),
            ],
          ),
      ],
    );
    return OcrResult(
      engineId: engineId,
      engineVersion: engineVersion,
      detectedLanguages: const <String>['en'],
      detectedScripts: const <String>['Latn'],
      pages: <OcrPage>[
        OcrPage(pageNumber: 1, blocks: <OcrBlock>[block]),
      ],
      warnings: const <String>[],
      rawText: lines.join('\n'),
    );
  }
}

final class _MutableClock {
  _MutableClock(this.now);

  DateTime now;

  void advance(Duration duration) => now = now.add(duration);
}

final class _TestRandom implements CryptographicRandom {
  var _next = 1;

  @override
  Future<Uint8List> secureBytes(int length) async => Uint8List.fromList(
    List<int>.generate(length, (_) => _next++ & 0xFF),
  );
}

final class _FailingThumbnailGenerator implements ThumbnailGenerator {
  const _FailingThumbnailGenerator();

  @override
  Future<GeneratedThumbnail> generate(
    Uint8List original,
    IngestionLimits limits,
  ) => throw const ThumbnailFailure(
    code: 'temporary_thumbnail_failure',
    disposition: IngestionFailureDisposition.transient,
  );
}
