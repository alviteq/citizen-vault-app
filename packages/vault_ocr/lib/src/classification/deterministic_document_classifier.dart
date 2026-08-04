// Rule result fields and interface members are documented at type level.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ocr/src/model/ocr_models.dart';

/// Non-authoritative local classification suggestion.
@immutable
final class DocumentClassificationSuggestion {
  /// Creates a suggestion and its stable evidence codes.
  DocumentClassificationSuggestion({
    required this.type,
    required this.confidence,
    required List<String> evidence,
    required this.classifierId,
    required this.classifierVersion,
  }) : evidence = List.unmodifiable(evidence);

  final DocumentType type;
  final double confidence;
  final List<String> evidence;
  final String classifierId;
  final String classifierVersion;
}

/// Replaceable document classifier.
abstract interface class DocumentClassifier {
  String get classifierId;
  String get classifierVersion;
  DocumentClassificationSuggestion classify(OcrResult result);
}

/// Keyword/format classifier whose evidence can be reviewed and reproduced.
final class DeterministicDocumentClassifier implements DocumentClassifier {
  /// Creates the version-one ruleset.
  const DeterministicDocumentClassifier();

  @override
  String get classifierId => 'citizen-vault-rules';

  @override
  String get classifierVersion => '1.0.0';

  @override
  DocumentClassificationSuggestion classify(OcrResult result) {
    final text = _normalize(result.rawText);
    final candidates = <_ScoredType>[
      _score(
        DocumentType.aadhaar,
        text,
        keywords: const <String>[
          'aadhaar',
          'unique identification authority of india',
          'government of india',
        ],
        patterns: <RegExp>[RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b')],
      ),
      _score(
        DocumentType.pan,
        text,
        keywords: const <String>[
          'income tax department',
          'permanent account number',
        ],
        patterns: <RegExp>[RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b')],
        originalText: result.rawText,
      ),
      _score(
        DocumentType.passport,
        text,
        keywords: const <String>[
          'passport',
          'republic of india',
          'nationality',
        ],
        patterns: <RegExp>[RegExp(r'\b[A-Z]\d{7}\b')],
        originalText: result.rawText,
      ),
      _score(
        DocumentType.drivingLicence,
        text,
        keywords: const <String>[
          'driving licence',
          'driving license',
          'transport department',
        ],
      ),
      _score(
        DocumentType.voterId,
        text,
        keywords: const <String>[
          'election commission of india',
          'elector photo identity card',
          'voter id',
          'voter information',
          'epic no',
          'polling station',
          'parliamentary constituency',
        ],
        patterns: <RegExp>[RegExp(r'\b[A-Z]{3}\d{7}\b')],
        originalText: result.rawText,
      ),
      _score(
        DocumentType.electricityBill,
        text,
        keywords: const <String>[
          'electricity bill',
          'electricity board',
          'meter number',
          'kwh',
        ],
      ),
      _score(
        DocumentType.waterBill,
        text,
        keywords: const <String>['water bill', 'water supply', 'water charges'],
      ),
      _score(
        DocumentType.gasBill,
        text,
        keywords: const <String>[
          'gas bill',
          'consumer number',
          'gas service',
        ],
      ),
      _score(
        DocumentType.propertyTax,
        text,
        keywords: const <String>[
          'property tax',
          'municipal corporation',
          'assessment year',
        ],
      ),
      _score(
        DocumentType.bankStatement,
        text,
        keywords: const <String>[
          'bank statement',
          'account statement',
          'opening balance',
          'closing balance',
        ],
      ),
      _score(
        DocumentType.insurancePolicy,
        text,
        keywords: const <String>[
          'insurance policy',
          'policy number',
          'sum insured',
          'premium',
        ],
      ),
      _score(
        DocumentType.medicalReport,
        text,
        keywords: const <String>[
          'medical report',
          'laboratory report',
          'patient id',
          'reference range',
        ],
      ),
      _score(
        DocumentType.prescription,
        text,
        keywords: const <String>[
          'prescription',
          'dosage',
          'tablet',
          'doctor',
        ],
      ),
      _score(
        DocumentType.educationCertificate,
        text,
        keywords: const <String>[
          'certificate',
          'university',
          'board of secondary education',
          'has successfully completed',
        ],
      ),
      _score(
        DocumentType.vehicleDocument,
        text,
        keywords: const <String>[
          'registration certificate',
          'vehicle class',
          'chassis number',
          'engine number',
        ],
      ),
      _score(
        DocumentType.invoice,
        text,
        keywords: const <String>[
          'invoice',
          'invoice number',
          'gstin',
          'tax invoice',
        ],
      ),
      _score(
        DocumentType.receipt,
        text,
        keywords: const <String>[
          'receipt',
          'amount paid',
          'payment received',
        ],
      ),
    ]..sort((left, right) => right.score.compareTo(left.score));

    final best = candidates.first;
    final type = best.score == 0
        ? (text.isEmpty ? DocumentType.unknown : DocumentType.generalDocument)
        : best.type;
    final evidence = <String>[];
    if (best.score == 0) {
      evidence.add(
        text.isEmpty ? 'no_ocr_text' : 'unclassified_text_present',
      );
    } else {
      evidence.addAll(best.evidence);
    }
    return DocumentClassificationSuggestion(
      type: type,
      confidence: best.score == 0 ? 0 : (best.score / 6).clamp(0.1, 0.95),
      evidence: evidence,
      classifierId: classifierId,
      classifierVersion: classifierVersion,
    );
  }

  static _ScoredType _score(
    DocumentType type,
    String normalizedText, {
    required List<String> keywords,
    List<RegExp> patterns = const <RegExp>[],
    String? originalText,
  }) {
    var score = 0;
    final evidence = <String>[];
    for (var index = 0; index < keywords.length; index += 1) {
      if (!normalizedText.contains(keywords[index])) continue;
      score += index == 0 ? 2 : 1;
      evidence.add('keyword_${index + 1}');
    }
    final source = originalText ?? normalizedText;
    for (var index = 0; index < patterns.length; index += 1) {
      if (!patterns[index].hasMatch(source)) continue;
      score += 2;
      evidence.add('format_${index + 1}');
    }
    return _ScoredType(type: type, score: score, evidence: evidence);
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

final class _ScoredType {
  const _ScoredType({
    required this.type,
    required this.score,
    required this.evidence,
  });

  final DocumentType type;
  final int score;
  final List<String> evidence;
}
