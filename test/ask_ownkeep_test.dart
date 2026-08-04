import 'package:citizen_vault_app/src/ask/ask_ownkeep_screen.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
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
  group('Ask OwnKeep Screen (Milestone 19)', () {
    late _TestIngestionController controller;

    setUp(() {
      controller = _TestIngestionController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders Ask OwnKeep search input and query templates', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AskOwnKeepScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ask OwnKeep'), findsOneWidget);
      expect(find.text('Deterministic Graph Answers'), findsOneWidget);
      expect(find.text('Warranties'), findsOneWidget);
      expect(find.text('Total Spend'), findsOneWidget);
    });

    testWidgets('executes deterministic query and renders evidence steps', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AskOwnKeepScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Warranties'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Fact Verified'), findsOneWidget);
      expect(find.textContaining('Warranties'), findsAtLeast(1));
    });
  });
}
