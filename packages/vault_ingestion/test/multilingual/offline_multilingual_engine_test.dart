import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('OfflineMultilingualEngine (Milestone 22 Gate)', () {
    late OfflineMultilingualEngine engine;

    setUp(() {
      engine = OfflineMultilingualEngine();
    });

    test('initializes with English UI and separate OCR tracking', () {
      expect(engine.preferences.uiLanguage, SupportedLanguage.english);
      expect(engine.availableOcrPacks.length, 8);
    });

    test('switches UI language without altering stored claim invariance', () {
      engine.setUiLanguage(SupportedLanguage.hindi);
      expect(engine.preferences.uiLanguage, SupportedLanguage.hindi);

      // Verify Milestone 22 Gate claim invariance
      final isInvariant = engine.verifyClaimInvariance(
        originalClaimPredicate: 'hasWarranty',
        originalEntityId: 'entity-car-1',
      );
      expect(isInvariant, isTrue);
    });
  });
}
