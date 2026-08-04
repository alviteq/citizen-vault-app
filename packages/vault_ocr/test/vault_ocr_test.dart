import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ocr/vault_ocr.dart';

void main() {
  test('declares the milestone seven API version', () {
    expect(VaultOcrPackage.apiVersion, '0.8.0');
  });

  test('layout codec preserves pages, blocks, lines, words and polygons', () {
    final original = _panResult();
    final encoded = OcrResultCodec.encode(original);
    final decoded = OcrResultCodec.decode(encoded);

    expect(decoded.engineId, original.engineId);
    expect(decoded.rawText, original.rawText);
    expect(decoded.pages.single.blocks.single.lines, hasLength(3));
    expect(
      decoded
          .pages
          .single
          .blocks
          .single
          .lines
          .first
          .words
          .single
          .polygon!
          .points,
      hasLength(4),
    );
    expect(decoded.locate('ABCDE1234F')?.page, 1);
  });

  test('layout codec rejects malformed and oversized input', () {
    expect(
      () => OcrResultCodec.decode(<int>[1, 2, 3]),
      throwsA(
        isA<OcrFailure>().having(
          (failure) => failure.code,
          'code',
          'ocr_layout_invalid',
        ),
      ),
    );
    expect(
      () => OcrResultCodec.decode(
        Uint8List(OcrResultCodec.maximumBytes + 1),
      ),
      throwsA(isA<OcrFailure>()),
    );
  });

  test(
    'classifier reports reproducible PAN evidence without authority claim',
    () {
      final suggestion = const DeterministicDocumentClassifier().classify(
        _panResult(),
      );

      expect(suggestion.type, DocumentType.pan);
      expect(suggestion.confidence, greaterThan(0.5));
      expect(suggestion.evidence, contains('format_1'));
      expect(suggestion.classifierId, 'citizen-vault-rules');
    },
  );

  test('deterministic extractors normalize document number and date', () async {
    final result = _panResult();
    final candidates = await DeterministicExtractionPipeline().extract(
      ExtractionContext(documentType: DocumentType.pan, ocr: result),
    );

    expect(
      candidates,
      contains(
        isA<ExtractedFieldCandidate>()
            .having(
              (candidate) => candidate.type,
              'type',
              ExtractedFieldType.documentNumber,
            )
            .having(
              (candidate) => candidate.normalizedValue,
              'normalized',
              'ABCDE1234F',
            ),
      ),
    );
    expect(
      candidates,
      contains(
        isA<ExtractedFieldCandidate>()
            .having(
              (candidate) => candidate.type,
              'type',
              ExtractedFieldType.date,
            )
            .having(
              (candidate) => candidate.normalizedValue,
              'normalized',
              '1990-08-15',
            ),
      ),
    );
  });

  test(
    'voter information is classified and its labelled fields extract',
    () async {
      const text = '''
Voter Information
First Name Harika
Last Name SrikakoLapu
Relative's First Name Taraka Durga Prasad
Age 22
Gender Female
EPIC No WQN2814184
State Andhra Pradesh
Parliamentary Constituency Number-Parliamentary Constituency Name 8-Rajahmundry
Assembly Constituency Number-Assembly Constituency Name 51-Rajahmundry Rural
Polling Station Smt Kasturiba Gandhi Z.P.P. Girls High School
Part Number-Part Name 131-Smt Kasturiba Gandhi Zilla Praja Parishad Girls High School
Part Serial Number 459
Polling Date No elections scheduled currently
''';
      final result = OcrResult(
        engineId: 'test',
        engineVersion: '1',
        detectedLanguages: const <String>['en'],
        detectedScripts: const <String>['Latn'],
        pages: const <OcrPage>[],
        warnings: const <String>[],
        rawText: text,
      );

      final suggestion = const DeterministicDocumentClassifier().classify(
        result,
      );
      expect(suggestion.type, DocumentType.voterId);

      final candidates = await DeterministicExtractionPipeline().extract(
        ExtractionContext(documentType: DocumentType.voterId, ocr: result),
      );
      expect(
        candidates
            .singleWhere(
              (candidate) =>
                  candidate.type == ExtractedFieldType.documentNumber,
            )
            .normalizedValue,
        'WQN2814184',
      );
      expect(
        candidates
            .singleWhere(
              (candidate) => candidate.type == ExtractedFieldType.firstName,
            )
            .normalizedValue,
        'Harika',
      );
      expect(
        candidates
            .singleWhere(
              (candidate) =>
                  candidate.type == ExtractedFieldType.assemblyConstituency,
            )
            .normalizedValue,
        '51-Rajahmundry Rural',
      );
      expect(
        candidates
            .singleWhere(
              (candidate) => candidate.type == ExtractedFieldType.serialNumber,
            )
            .normalizedValue,
        '459',
      );
    },
  );

  test('column-oriented voter OCR maps values using stable anchors', () async {
    const text = '''
Voter Information
First Name
Last Name
Relative's First Name
Relative's Last Name
Age
Gender
EPIC No
State
Parliamentary Constituency
Assembly Constituency
Polling Station
Part Number-Part Name
Part Serial Number
Polling Date
Harika
Foayed
SrikakoLapu
BseSosy
Taraka Durga Prasad
ESSE SoS BSS
Srikakolapu
Bsr Ss
22
Female
WQN2814184
Andhra Pradesh
8-Rajahmundry
51-Rajahmundry Rural
Smt.Kasturiba Gandhi
Z.P.P. Girls High School
Main Road, Dowlaiswaram
131-Smt.Kasturiba Gandhi Zilla Praja Parishad Girls High School
459
No elections scheduled currently
''';
    final result = OcrResult(
      engineId: 'test',
      engineVersion: '1',
      detectedLanguages: const <String>['en'],
      detectedScripts: const <String>['Latn'],
      pages: const <OcrPage>[],
      warnings: const <String>[],
      rawText: text,
    );
    final candidates = await DeterministicExtractionPipeline().extract(
      ExtractionContext(documentType: DocumentType.voterId, ocr: result),
    );
    final values = <ExtractedFieldType, String>{
      for (final candidate in candidates)
        candidate.type: candidate.normalizedValue,
    };

    expect(values[ExtractedFieldType.firstName], 'Harika');
    expect(values[ExtractedFieldType.lastName], 'SrikakoLapu');
    expect(
      values[ExtractedFieldType.relativeName],
      'Taraka Durga Prasad Srikakolapu',
    );
    expect(values[ExtractedFieldType.documentNumber], 'WQN2814184');
    expect(
      values[ExtractedFieldType.assemblyConstituency],
      '51-Rajahmundry Rural',
    );
    expect(values[ExtractedFieldType.serialNumber], '459');
  });

  test('common labelled details extract across document categories', () async {
    const text = '''
Patient Name: Harika Srikakolapu
Nationality: Indian
Place of Birth: Rajahmundry
Consumer Number: 1234567890
Billing Period: June 2026
Grand Total: INR 1,250.00
''';
    final result = OcrResult(
      engineId: 'test',
      engineVersion: '1',
      detectedLanguages: const ['en'],
      detectedScripts: const ['Latn'],
      pages: const [],
      warnings: const [],
      rawText: text,
    );
    final candidates = await DeterministicExtractionPipeline().extract(
      ExtractionContext(documentType: DocumentType.medicalReport, ocr: result),
    );
    final values = {
      for (final candidate in candidates)
        candidate.type: candidate.normalizedValue,
    };
    expect(values[ExtractedFieldType.patientName], 'Harika Srikakolapu');
    expect(values[ExtractedFieldType.nationality], 'Indian');
    expect(values[ExtractedFieldType.placeOfBirth], 'Rajahmundry');
    expect(values[ExtractedFieldType.consumerNumber], '1234567890');
    expect(values[ExtractedFieldType.billingPeriod], 'June 2026');
    expect(values[ExtractedFieldType.totalAmount], 'INR 1,250.00');
  });

  test(
    'decrypted input lease is opaque, bounded, and deleted in finally',
    () async {
      final root = Directory.systemTemp.createTempSync('vault_ocr_lease_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final manager = DecryptedAssetLeaseManager(
        directory: root,
        random: _FixedRandom(),
        maximumBytes: 8,
      );
      final lease = await manager.create(
        plaintext: Stream<List<int>>.value(<int>[1, 2, 3, 4]),
        suffix: '.jpg',
      );
      String? path;
      try {
        final bytes = await lease.usePrivatePath((privatePath) async {
          path = privatePath;
          return File(privatePath).readAsBytesSync();
        });
        expect(bytes, <int>[1, 2, 3, 4]);
        expect(path, contains(RegExp(r'ocr-[0-9a-f]{32}\.jpg$')));
      } finally {
        await lease.close();
      }
      expect(File(path!).existsSync(), isFalse);

      await expectLater(
        manager.create(
          plaintext: Stream<List<int>>.value(List<int>.filled(9, 1)),
          suffix: '.png',
        ),
        throwsA(
          isA<OcrFailure>().having(
            (failure) => failure.code,
            'code',
            'ocr_input_too_large',
          ),
        ),
      );
      expect(root.listSync(), isEmpty);
    },
  );
}

OcrResult _panResult() {
  const lines = <String>[
    'INCOME TAX DEPARTMENT',
    'ABCDE1234F',
    'Date of Birth 15/08/1990',
  ];
  final ocrLines = <OcrLine>[
    for (var index = 0; index < lines.length; index += 1)
      OcrLine(
        id: 'p1-b1-l${index + 1}',
        text: lines[index],
        words: <OcrWord>[
          OcrWord(
            id: 'p1-b1-l${index + 1}-w1',
            text: lines[index],
            polygon: OcrPolygon(const <OcrPoint>[
              OcrPoint(0, 0),
              OcrPoint(100, 0),
              OcrPoint(100, 20),
              OcrPoint(0, 20),
            ]),
          ),
        ],
      ),
  ];
  return OcrResult(
    engineId: 'fixture-ocr',
    engineVersion: '1',
    detectedLanguages: const <String>['en'],
    detectedScripts: const <String>['Latn'],
    pages: <OcrPage>[
      OcrPage(
        pageNumber: 1,
        width: 200,
        height: 300,
        blocks: <OcrBlock>[
          OcrBlock(
            id: 'p1-b1',
            text: lines.join('\n'),
            lines: ocrLines,
          ),
        ],
      ),
    ],
    warnings: const <String>[],
    rawText: lines.join('\n'),
  );
}

final class _FixedRandom implements CryptographicRandom {
  var _next = 0;

  @override
  Future<Uint8List> secureBytes(int length) async => Uint8List.fromList(
    List<int>.generate(length, (_) => _next++ & 0xff),
  );
}
