import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('OnDeviceIntelligenceEngine (Milestone 21 Gate)', () {
    late OnDeviceIntelligenceEngine engine;

    setUp(() {
      engine = OnDeviceIntelligenceEngine();
    });

    test('generates grounded summaries strictly from verified claims', () {
      final doc = DocumentListItemView(
        id: 'doc-1',
        logicalFilename: 'vehicle_insurance.pdf',
        documentType: DocumentType.insurancePolicy,
        mimeType: 'application/pdf',
        status: 'ready',
        integrityStatus: 'valid',
        importedAt: DateTime.utc(2026, 7, 26),
        isFavourite: false,
        isArchived: false,
        tags: const [],
      );

      const reviews = [
        DocumentReviewView(
          documentId: 'doc-1',
          logicalFilename: 'vehicle_insurance.pdf',
          suggestedType: DocumentType.insurancePolicy,
          classificationConfidence: 0.95,
          classificationEvidence: ['INSURANCE'],
          ocrTextPreview: 'POLICY POL-12345',
          fields: [
            ExtractedFieldView(
              id: 'f-1',
              type: ExtractedFieldType.documentNumber,
              rawValue: 'POL-12345',
              normalizedValue: 'POL-12345',
              extractorId: 'heuristic',
              extractorVersion: '1.0.0',
              confirmedByUser: true,
            ),
          ],
        ),
      ];

      final summary = engine.generateSummary(
        document: doc,
        verifiedReviews: reviews,
      );

      expect(summary.documentId, 'doc-1');
      expect(summary.keyTakeaways, contains('Document number: POL-12345'));
      expect(summary.groundingEvidence.length, 1);
      expect(
        summary.groundingEvidence.first.evidenceSnippet,
        contains('POL-12345'),
      );
    });

    test('fallback deterministically when model is unloaded', () {
      final unloadedEngine = OnDeviceIntelligenceEngine(isModelLoaded: false);
      final doc = DocumentListItemView(
        id: 'doc-2',
        logicalFilename: 'receipt.pdf',
        documentType: DocumentType.receipt,
        mimeType: 'application/pdf',
        status: 'ready',
        integrityStatus: 'valid',
        importedAt: DateTime.utc(2026, 7, 26),
        isFavourite: false,
        isArchived: false,
        tags: const [],
      );

      final summary = unloadedEngine.generateSummary(
        document: doc,
        verifiedReviews: const [],
      );

      expect(summary.groundingEvidence, isEmpty);
      expect(
        summary.keyTakeaways.last,
        contains('Deterministic Fallback Active'),
      );
    });

    test('generates actionable grounded recommendations', () {
      final recs = engine.generateRecommendations(
        assets: const [],
        smartPacks: const [],
        attentionItems: const [],
      );

      expect(recs.length, greaterThanOrEqualTo(1));
      expect(recs.first.id, 'rec-pack');
    });
  });
}
