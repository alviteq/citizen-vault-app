import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('DeterministicAskEngine (Milestone 19 Gate)', () {
    late DeterministicAskEngine askEngine;

    setUp(() {
      askEngine = const DeterministicAskEngine();
    });

    test('reproduces answers deterministically with evidence steps', () {
      final assets = [
        HouseholdAssetRecord(
          id: 'asset-1',
          name: 'Honda City ZX',
          category: HouseholdAssetCategory.vehicle,
          status: HouseholdAssetStatus.active,
          warrantyProvider: 'Honda Shield',
          warrantyEndDate: DateTime.utc(2028, 4, 14),
        ),
      ];

      final response = askEngine.queryVault(
        query: 'What warranties do I have?',
        documents: const [],
        attentionItems: const [],
        householdAssets: assets,
        householdEvents: const [],
        smartPacks: const [],
      );

      expect(response.isAvailable, isTrue);
      expect(response.category, AskQueryCategory.warranties);
      expect(response.answerText, contains('Honda City ZX'));
      expect(response.explanationSteps.length, 1);
      expect(
        response.explanationSteps.first.description,
        contains('Honda Shield'),
      );
    });

    test('returns explicit unavailable response when fact is missing', () {
      final response = askEngine.queryVault(
        query: 'Who is my passport issuer?',
        documents: const [],
        attentionItems: const [],
        householdAssets: const [],
        householdEvents: const [],
        smartPacks: const [],
      );

      expect(response.isAvailable, isFalse);
      expect(response.confidence, 0);
      expect(
        response.answerText,
        contains('Information not available in vault'),
      );
    });
  });
}
