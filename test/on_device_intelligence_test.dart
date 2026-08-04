import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/intelligence/on_device_intelligence_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_domain/vault_domain.dart';

final class _TestIngestionController extends IngestionUiController {
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
}

void main() {
  group('On-device Intelligence Screen (Milestone 21)', () {
    late _TestIngestionController controller;

    setUp(() {
      controller = _TestIngestionController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders grounded intelligence summaries and recommendations', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnDeviceIntelligenceScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('On-device Intelligence'), findsOneWidget);
      expect(find.text('Local Grounded NLU Engine'), findsOneWidget);
      expect(find.textContaining('Grounded Recommendations'), findsOneWidget);
    });
  });
}
