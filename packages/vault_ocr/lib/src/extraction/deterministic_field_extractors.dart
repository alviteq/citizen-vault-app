// Extractor contract fields are documented by their containing value types.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ocr/src/model/ocr_models.dart';

/// Input shared by deterministic extractors.
@immutable
final class ExtractionContext {
  /// Creates extraction context.
  const ExtractionContext({required this.documentType, required this.ocr});

  final DocumentType documentType;
  final OcrResult ocr;
}

/// Candidate produced by a reproducible local rule.
@immutable
final class ExtractedFieldCandidate {
  /// Creates a candidate.
  const ExtractedFieldCandidate({
    required this.type,
    required this.rawValue,
    required this.normalizedValue,
    required this.extractorId,
    required this.extractorVersion,
    required this.confidence,
    this.sourcePage,
    this.sourceBlockId,
  });

  final ExtractedFieldType type;
  final String rawValue;
  final String normalizedValue;
  final double confidence;
  final int? sourcePage;
  final String? sourceBlockId;
  final String extractorId;
  final String extractorVersion;
}

/// Replaceable deterministic field extractor.
abstract interface class DocumentFieldExtractor {
  String get extractorId;
  String get extractorVersion;
  bool supports(DocumentType type);
  Future<List<ExtractedFieldCandidate>> extract(ExtractionContext context);
}

/// Runs reviewed extractors and deduplicates stable normalized values.
final class DeterministicExtractionPipeline {
  /// Creates the default Milestone 7 extractor set.
  DeterministicExtractionPipeline({
    List<DocumentFieldExtractor>? extractors,
  }) : extractors = List.unmodifiable(
         extractors ??
             const <DocumentFieldExtractor>[
               DateFieldExtractor(),
               AmountFieldExtractor(),
               DocumentNumberExtractor(),
               IssuerFieldExtractor(),
               ContactFieldExtractor(),
               MaskedAccountNumberExtractor(),
               AddressCandidateExtractor(),
               VoterInformationExtractor(),
               LabelledDocumentDetailsExtractor(),
             ],
       );

  final List<DocumentFieldExtractor> extractors;

  /// Extracts in stable order without duplicate field/value pairs.
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async {
    if (context.documentType == DocumentType.voterId) {
      final columnar = _extractColumnarTable(context);
      if (columnar.isNotEmpty) return columnar;
    }

    final output = <ExtractedFieldCandidate>[];
    final seen = <String>{};
    for (final extractor in extractors) {
      if (!extractor.supports(context.documentType)) continue;
      for (final candidate in await extractor.extract(context)) {
        final key =
            '${candidate.type.storageValue}\u0000'
            '${candidate.normalizedValue.toLowerCase()}';
        if (seen.add(key)) output.add(candidate);
      }
    }
    return output;
  }

  List<ExtractedFieldCandidate> _extractColumnarTable(
    ExtractionContext context,
  ) {
    final lines = context.ocr.rawText
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final epicIndex = lines.indexWhere(
      (line) => RegExp(r'^[A-Z]{3}\d{7}$').hasMatch(line),
    );
    if (epicIndex < 2 ||
        !RegExp(r'^\d{1,3}$').hasMatch(lines[epicIndex - 2]) ||
        !RegExp(
          r'^(?:Male|Female|Other)$',
          caseSensitive: false,
        ).hasMatch(lines[epicIndex - 1])) {
      return const <ExtractedFieldCandidate>[];
    }

    final pollingLabelIndex = lines.lastIndexWhere(
      (line) => line.toLowerCase().contains('polling date'),
      epicIndex - 1,
    );
    if (pollingLabelIndex < 0) return const <ExtractedFieldCandidate>[];
    final preAge = lines
        .sublist(pollingLabelIndex + 1, epicIndex - 2)
        .where(
          (line) =>
              RegExp(r'[A-Za-z]').hasMatch(line) &&
              !line.contains('/') &&
              !_looksLikeVoterLabel(line),
        )
        .toList(growable: false);
    final names = preAge.length >= 7
        ? <String>[preAge[0], preAge[2], preAge[4], preAge[6]]
        : preAge.take(4).toList(growable: false);

    final values = <ExtractedFieldType, String>{
      if (names.isNotEmpty) ExtractedFieldType.firstName: names[0],
      if (names.length > 1) ExtractedFieldType.lastName: names[1],
      if (names.length > 2)
        ExtractedFieldType.relativeName: names.skip(2).take(2).join(' '),
      ExtractedFieldType.age: lines[epicIndex - 2],
      ExtractedFieldType.gender: lines[epicIndex - 1],
      ExtractedFieldType.documentNumber: lines[epicIndex],
    };

    var cursor = epicIndex + 1;
    if (cursor < lines.length)
      values[ExtractedFieldType.state] = lines[cursor++];
    if (cursor < lines.length) {
      values[ExtractedFieldType.parliamentaryConstituency] = lines[cursor++];
    }
    if (cursor < lines.length) {
      values[ExtractedFieldType.assemblyConstituency] = lines[cursor++];
    }

    final partIndex = lines.indexWhere(
      (line) => RegExp(r'^\d+\s*-\s*').hasMatch(line),
      cursor,
    );
    if (partIndex > cursor) {
      values[ExtractedFieldType.pollingStation] = lines
          .sublist(cursor, partIndex)
          .join(' ');
      cursor = partIndex;
    }
    final serialIndex = lines.indexWhere(
      (line) => RegExp(r'^\d{1,6}$').hasMatch(line),
      cursor + 1,
    );
    if (serialIndex > cursor) {
      values[ExtractedFieldType.partNumber] = lines
          .sublist(cursor, serialIndex)
          .join(' ');
      values[ExtractedFieldType.serialNumber] = lines[serialIndex];
      if (serialIndex + 1 < lines.length) {
        values[ExtractedFieldType.pollingDate] = lines
            .sublist(serialIndex + 1)
            .join(' ');
      }
    }

    return values.entries
        .map((entry) {
          final location = context.ocr.locate(entry.value);
          return ExtractedFieldCandidate(
            type: entry.key,
            rawValue: entry.value,
            normalizedValue: entry.value,
            confidence: entry.key == ExtractedFieldType.documentNumber
                ? 0.95
                : 0.82,
            sourcePage: location?.page,
            sourceBlockId: location?.blockId,
            extractorId: 'voter-information-column-rules',
            extractorVersion: '1.0.0',
          );
        })
        .toList(growable: false);
  }

  static bool _looksLikeVoterLabel(String line) {
    final lower = line.toLowerCase();
    return lower.contains('first name') ||
        lower.contains('last name') ||
        lower.contains('relative') ||
        lower.contains('age') ||
        lower.contains('gender') ||
        lower.contains('epic') ||
        lower.contains('state') ||
        lower.contains('constituency') ||
        lower.contains('polling station') ||
        lower.contains('part number') ||
        lower.contains('serial number');
  }
}

/// Extracts common labelled values used across identity, policy, utility,
/// medical, invoice, and receipt documents.
final class LabelledDocumentDetailsExtractor extends _BaseExtractor {
  const LabelledDocumentDetailsExtractor();

  static final List<({ExtractedFieldType type, RegExp pattern})> _patterns = [
    (
      type: ExtractedFieldType.fullName,
      pattern: _label(r'(?:full\s+name|name(?:\s+of\s+(?:holder|insured))?)'),
    ),
    (
      type: ExtractedFieldType.relativeName,
      pattern: _label(r"(?:father(?:'s)?|mother(?:'s)?|spouse)\s+name"),
    ),
    (
      type: ExtractedFieldType.age,
      pattern: _label(r'age', value: r'\d{1,3}'),
    ),
    (
      type: ExtractedFieldType.gender,
      pattern: _label(r'(?:gender|sex)', value: r'(?:male|female|other)'),
    ),
    (
      type: ExtractedFieldType.nationality,
      pattern: _label(r'nationality'),
    ),
    (
      type: ExtractedFieldType.placeOfBirth,
      pattern: _label(r'place\s+of\s+birth'),
    ),
    (
      type: ExtractedFieldType.policyholder,
      pattern: _label(r'(?:policyholder|insured\s+name|proposer\s+name)'),
    ),
    (
      type: ExtractedFieldType.consumerNumber,
      pattern: _label(r'(?:consumer|customer|service)\s+(?:no|number|id)'),
    ),
    (
      type: ExtractedFieldType.billingPeriod,
      pattern: _label(r'(?:billing|bill)\s+period'),
    ),
    (
      type: ExtractedFieldType.patientName,
      pattern: _label(r'patient\s+name'),
    ),
    (
      type: ExtractedFieldType.merchant,
      pattern: _label(r'(?:merchant|seller|vendor)'),
    ),
    (
      type: ExtractedFieldType.taxAmount,
      pattern: _label(
        r'(?:tax|gst|cgst|sgst|igst)\s*(?:amount)?',
        value: r'(?:₹|INR|Rs\.?)?\s*[0-9,]+(?:\.\d{1,2})?',
      ),
    ),
    (
      type: ExtractedFieldType.totalAmount,
      pattern: _label(
        r'(?:grand\s+total|total\s+amount|net\s+amount)',
        value: r'(?:₹|INR|Rs\.?)?\s*[0-9,]+(?:\.\d{1,2})?',
      ),
    ),
  ];

  static RegExp _label(String label, {String value = r'[^\n]{2,120}'}) =>
      RegExp(
        '(?:^|\\n)\\s*(?:$label)\\s*(?:[:#.-]|\\s)\\s*($value)',
        caseSensitive: false,
      );

  @override
  String get extractorId => 'labelled-document-details';

  @override
  String get extractorVersion => '1.0.0';

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async {
    final output = <ExtractedFieldCandidate>[];
    for (final definition in _patterns) {
      final match = definition.pattern.firstMatch(context.ocr.rawText);
      final raw = match?.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      output.add(
        candidate(
          context: context,
          type: definition.type,
          raw: raw,
          normalized: raw.replaceAll(RegExp(r'\s+'), ' ').trim(),
          confidence: 0.78,
        ),
      );
    }
    return output;
  }
}

/// Extracts labelled fields from Indian voter-information documents.
final class VoterInformationExtractor extends _BaseExtractor {
  const VoterInformationExtractor();

  static final List<
    ({
      ExtractedFieldType type,
      RegExp pattern,
      double confidence,
    })
  >
  _fields =
      <
        ({
          ExtractedFieldType type,
          RegExp pattern,
          double confidence,
        })
      >[
        (
          type: ExtractedFieldType.firstName,
          pattern: RegExp(
            r'(?:^|\n)\s*(?:First\s*Name)\s*[:\-]?\s*([A-Z][A-Za-z .]{1,60})',
            caseSensitive: false,
          ),
          confidence: 0.9,
        ),
        (
          type: ExtractedFieldType.lastName,
          pattern: RegExp(
            r'(?:^|\n)\s*(?:Last\s*Name)\s*[:\-]?\s*([A-Z][A-Za-z .]{1,60})',
            caseSensitive: false,
          ),
          confidence: 0.9,
        ),
        (
          type: ExtractedFieldType.relativeName,
          pattern: RegExp(
            r"(?:Relative(?:'s)?\s*(?:First|Last)?\s*Name)\s*[:\-]?\s*([A-Z][A-Za-z .]{1,80})",
            caseSensitive: false,
          ),
          confidence: 0.82,
        ),
        (
          type: ExtractedFieldType.age,
          pattern: RegExp(
            r'\bAge\s*[:\-]?\s*(\d{1,3})\b',
            caseSensitive: false,
          ),
          confidence: 0.9,
        ),
        (
          type: ExtractedFieldType.gender,
          pattern: RegExp(
            r'\bGender\s*[:\-]?\s*(Male|Female|Other)\b',
            caseSensitive: false,
          ),
          confidence: 0.9,
        ),
        (
          type: ExtractedFieldType.state,
          pattern: RegExp(
            r'(?:^|\n)\s*State\s*[:\-]?\s*([A-Z][A-Za-z ]{2,50})',
            caseSensitive: false,
          ),
          confidence: 0.88,
        ),
        (
          type: ExtractedFieldType.parliamentaryConstituency,
          pattern: RegExp(
            r'Parliamentary\s+Constituency(?:\s+Number)?(?:\s*-\s*Parliamentary\s+Constituency\s+Name)?\s*[:\-]?\s*(\d+\s*-\s*[A-Za-z][A-Za-z ]+)',
            caseSensitive: false,
          ),
          confidence: 0.84,
        ),
        (
          type: ExtractedFieldType.assemblyConstituency,
          pattern: RegExp(
            r'Assembly\s+Constituency(?:\s+Number)?(?:\s*-\s*Assembly\s+Constituency\s+Name)?\s*[:\-]?\s*(\d+\s*-\s*[A-Za-z][A-Za-z ]+)',
            caseSensitive: false,
          ),
          confidence: 0.84,
        ),
        (
          type: ExtractedFieldType.pollingStation,
          pattern: RegExp(
            r'Polling\s+Station\s*[:\-]?\s*([^\n]{3,160})',
            caseSensitive: false,
          ),
          confidence: 0.8,
        ),
        (
          type: ExtractedFieldType.partNumber,
          pattern: RegExp(
            r'Part\s+Number(?:\s*-\s*Part\s+Name)?\s*[:\-]?\s*(\d+\s*-\s*[^\n]{2,160})',
            caseSensitive: false,
          ),
          confidence: 0.82,
        ),
        (
          type: ExtractedFieldType.serialNumber,
          pattern: RegExp(
            r'Part\s+Serial\s+Number\s*[:\-]?\s*(\d+)',
            caseSensitive: false,
          ),
          confidence: 0.9,
        ),
        (
          type: ExtractedFieldType.pollingDate,
          pattern: RegExp(
            r'Polling\s+Date\s*[:\-]?\s*([^\n]{3,80})',
            caseSensitive: false,
          ),
          confidence: 0.8,
        ),
      ];

  @override
  String get extractorId => 'voter-information-rules';

  @override
  String get extractorVersion => '1.0.0';

  @override
  bool supports(DocumentType type) => type == DocumentType.voterId;

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async {
    final output = <ExtractedFieldCandidate>[];
    for (final field in _fields) {
      final match = field.pattern.firstMatch(context.ocr.rawText);
      final raw = match?.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      output.add(
        candidate(
          context: context,
          type: field.type,
          raw: raw,
          normalized: raw.replaceAll(RegExp(r'\s+'), ' ').trim(),
          confidence: field.confidence,
        ),
      );
    }
    return output;
  }
}

abstract base class _BaseExtractor implements DocumentFieldExtractor {
  const _BaseExtractor();

  @override
  bool supports(DocumentType type) => true;

  ExtractedFieldCandidate candidate({
    required ExtractionContext context,
    required ExtractedFieldType type,
    required String raw,
    required String normalized,
    required double confidence,
  }) {
    final location = context.ocr.locate(raw);
    return ExtractedFieldCandidate(
      type: type,
      rawValue: raw,
      normalizedValue: normalized,
      confidence: confidence,
      sourcePage: location?.page,
      sourceBlockId: location?.blockId,
      extractorId: extractorId,
      extractorVersion: extractorVersion,
    );
  }

  @override
  String get extractorVersion => '1.0.0';
}

/// Extracts general, expiry, and due dates from numeric date formats.
final class DateFieldExtractor extends _BaseExtractor {
  const DateFieldExtractor();

  static final RegExp _date = RegExp(
    r'\b(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{4})\b',
  );

  @override
  String get extractorId => 'date-rules';

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async {
    final output = <ExtractedFieldCandidate>[];
    for (final match in _date.allMatches(context.ocr.rawText).take(20)) {
      final raw = match.group(0)!;
      final normalized = _normalizeDate(raw);
      if (normalized == null) continue;
      final prefixStart = match.start > 40 ? match.start - 40 : 0;
      final prefix = context.ocr.rawText
          .substring(prefixStart, match.start)
          .toLowerCase();
      final type = prefix.contains('expir') || prefix.contains('valid until')
          ? ExtractedFieldType.expiryDate
          : prefix.contains('due')
          ? ExtractedFieldType.dueDate
          : ExtractedFieldType.date;
      output.add(
        candidate(
          context: context,
          type: type,
          raw: raw,
          normalized: normalized,
          confidence: type == ExtractedFieldType.date ? 0.65 : 0.85,
        ),
      );
    }
    return output;
  }

  static String? _normalizeDate(String value) {
    final parts = value.split(RegExp('[-/.]')).map(int.parse).toList();
    final (year, month, day) = parts[0] > 999
        ? (parts[0], parts[1], parts[2])
        : (parts[2], parts[1], parts[0]);
    if (year < 1900 || year > 2200 || month < 1 || month > 12) return null;
    final candidate = DateTime.utc(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }
}

/// Extracts explicitly currency-labelled amounts.
final class AmountFieldExtractor extends _BaseExtractor {
  const AmountFieldExtractor();

  static final RegExp _amount = RegExp(
    r'(?:₹|INR|Rs\.?)\s*([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  @override
  String get extractorId => 'amount-rules';

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async => _amount
      .allMatches(context.ocr.rawText)
      .take(20)
      .map((match) {
        final raw = match.group(0)!;
        final numeric = match.group(1)!.replaceAll(',', '');
        return candidate(
          context: context,
          type: ExtractedFieldType.amount,
          raw: raw,
          normalized: 'INR $numeric',
          confidence: 0.8,
        );
      })
      .toList(growable: false);
}

/// Extracts type-specific Indian document identifiers.
final class DocumentNumberExtractor extends _BaseExtractor {
  const DocumentNumberExtractor();

  @override
  String get extractorId => 'document-number-rules';

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async {
    final patterns = switch (context.documentType) {
      DocumentType.aadhaar => <RegExp>[RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b')],
      DocumentType.pan => <RegExp>[RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b')],
      DocumentType.passport => <RegExp>[RegExp(r'\b[A-Z]\d{7}\b')],
      DocumentType.voterId => <RegExp>[RegExp(r'\b[A-Z]{3}\d{7}\b')],
      DocumentType.vehicleDocument => <RegExp>[
        RegExp(r'\b[A-Z]{2}\s?\d{1,2}\s?[A-Z]{1,3}\s?\d{4}\b'),
      ],
      _ => <RegExp>[
        RegExp(
          r'(?:document|invoice|policy|consumer|reference|ref)\s*(?:no|number|#)?\s*[:.-]?\s*([A-Z0-9][A-Z0-9/-]{4,24})',
          caseSensitive: false,
        ),
      ],
    };
    final output = <ExtractedFieldCandidate>[];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(context.ocr.rawText).take(5)) {
        final raw = match.groupCount > 0 ? match.group(1)! : match.group(0)!;
        output.add(
          candidate(
            context: context,
            type: ExtractedFieldType.documentNumber,
            raw: raw,
            normalized: raw.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
            confidence: context.documentType == DocumentType.unknown
                ? 0.55
                : 0.9,
          ),
        );
      }
    }
    return output;
  }
}

/// Uses explicit issuer labels or the first short OCR line.
final class IssuerFieldExtractor extends _BaseExtractor {
  const IssuerFieldExtractor();

  static final RegExp _label = RegExp(
    r'(?:issued by|issuer|authority|bank)\s*[:.-]\s*([^\n]{3,100})',
    caseSensitive: false,
  );

  @override
  String get extractorId => 'issuer-rules';

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async {
    final labelled = _label.firstMatch(context.ocr.rawText);
    var value = labelled?.group(1)?.trim();
    var confidence = 0.8;
    if (value == null || value.isEmpty) {
      final lines = context.ocr.rawText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.length >= 3 && line.length <= 100);
      value = lines.firstOrNull;
      confidence = 0.35;
    }
    if (value == null) return const <ExtractedFieldCandidate>[];
    return <ExtractedFieldCandidate>[
      candidate(
        context: context,
        type: ExtractedFieldType.issuer,
        raw: value,
        normalized: value.replaceAll(RegExp(r'\s+'), ' ').trim(),
        confidence: confidence,
      ),
    ];
  }
}

/// Extracts email addresses and Indian phone-number candidates.
final class ContactFieldExtractor extends _BaseExtractor {
  const ContactFieldExtractor();

  static final RegExp _email = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _phone = RegExp(
    r'(?<!\d)(?:\+91[-\s]?)?[6-9]\d{9}(?!\d)',
  );

  @override
  String get extractorId => 'contact-rules';

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async => <ExtractedFieldCandidate>[
    ..._email.allMatches(context.ocr.rawText).take(10).map((match) {
      final raw = match.group(0)!;
      return candidate(
        context: context,
        type: ExtractedFieldType.email,
        raw: raw,
        normalized: raw.toLowerCase(),
        confidence: 0.9,
      );
    }),
    ..._phone.allMatches(context.ocr.rawText).take(10).map((match) {
      final raw = match.group(0)!;
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      return candidate(
        context: context,
        type: ExtractedFieldType.phone,
        raw: raw,
        normalized: digits.length == 12 ? '+$digits' : '+91$digits',
        confidence: 0.8,
      );
    }),
  ];
}

/// Extracts only already-masked account identifiers.
final class MaskedAccountNumberExtractor extends _BaseExtractor {
  const MaskedAccountNumberExtractor();

  static final RegExp _masked = RegExp(
    r'(?:account|a/c)\s*(?:no|number)?\s*[:.-]?\s*([Xx*]{2,}[Xx*\s-]*\d{3,6})',
    caseSensitive: false,
  );

  @override
  String get extractorId => 'masked-account-rules';

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async => _masked
      .allMatches(context.ocr.rawText)
      .take(5)
      .map((match) {
        final raw = match.group(1)!;
        return candidate(
          context: context,
          type: ExtractedFieldType.maskedAccountNumber,
          raw: raw,
          normalized: raw.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
          confidence: 0.85,
        );
      })
      .toList(growable: false);
}

/// Extracts bounded text following an explicit address label.
final class AddressCandidateExtractor extends _BaseExtractor {
  const AddressCandidateExtractor();

  static final RegExp _address = RegExp(
    r'(?:address|residence)\s*[:.-]\s*([^\n]+(?:\n[^\n]+){0,2})',
    caseSensitive: false,
  );

  @override
  String get extractorId => 'address-rules';

  @override
  Future<List<ExtractedFieldCandidate>> extract(
    ExtractionContext context,
  ) async => _address
      .allMatches(context.ocr.rawText)
      .take(3)
      .map((match) {
        final raw = match.group(1)!.trim();
        return candidate(
          context: context,
          type: ExtractedFieldType.address,
          raw: raw,
          normalized: raw.replaceAll(RegExp(r'\s+'), ' ').trim(),
          confidence: 0.65,
        );
      })
      .toList(growable: false);
}
