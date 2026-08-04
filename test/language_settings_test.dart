import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/settings/language_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

final class _TestIngestionController extends IngestionUiController {
  final _multilingualEngine = OfflineMultilingualEngine(
    initialPreferences: const LanguagePreferences(),
  );

  @override
  bool get isBusy => false;

  @override
  bool get isVaultAvailable => true;

  @override
  String? get notice => null;

  @override
  List<DocumentProcessingView> get jobs => const <DocumentProcessingView>[];

  @override
  List<DocumentReviewView> get reviews => const <DocumentReviewView>[];

  @override
  Future<void> captureImage() async {}

  @override
  Future<void> confirmReview({
    required String documentId,
    required DocumentType documentType,
    required List<ConfirmedFieldEdit> fields,
    String? profileEntityId,
  }) async {}

  @override
  Future<void> importFile() async {}

  @override
  Future<void> importGalleryImage() async {}

  @override
  Future<void> recover() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<List<DocumentSearchResult>> search(String query) async =>
      const <DocumentSearchResult>[];

  @override
  OfflineMultilingualEngine get multilingualEngine => _multilingualEngine;

  @override
  void setUiLanguage(SupportedLanguage language) {
    _multilingualEngine.setUiLanguage(language);
    notifyListeners();
  }

  @override
  void setOcrLanguage(String ocrLanguageCode) {
    _multilingualEngine.setOcrLanguage(ocrLanguageCode);
    notifyListeners();
  }
}

void main() {
  group('Language Settings Screen (Milestone 22)', () {
    late _TestIngestionController controller;

    setUp(() {
      controller = _TestIngestionController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders persisted interface language preferences', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: LanguageSettingsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Multilingual Invariance Guaranteed'), findsOneWidget);
      expect(find.text('हिन्दी (Hindi)'), findsOneWidget);
      expect(find.text('తెలుగు (Telugu)'), findsOneWidget);
      expect(find.text('Hindi (हिन्दी) OCR'), findsOneWidget);
    });

    testWidgets('switches UI language preference', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: LanguageSettingsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('हिन्दी (Hindi)'));
      await tester.pumpAndSettle();

      expect(
        controller.multilingualEngine.preferences.uiLanguage,
        SupportedLanguage.hindi,
      );
      expect(find.text('भाषा'), findsOneWidget);
    });

    testWidgets('switches OCR language independently from UI language', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: LanguageSettingsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Hindi (हिन्दी) OCR'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Hindi (हिन्दी) OCR'));
      await tester.pumpAndSettle();

      expect(controller.multilingualEngine.preferences.ocrLanguage, 'hi');
      expect(
        controller.multilingualEngine.preferences.uiLanguage,
        SupportedLanguage.english,
      );
    });
  });
}
