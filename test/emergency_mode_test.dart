import 'package:citizen_vault_app/src/emergency/emergency_mode_screen.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

final class _TestIngestionController extends IngestionUiController {
  final _emergencyManager = EmergencyStorageManager();

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
  EmergencyStorageManager get emergencyStorage => _emergencyManager;

  @override
  void recordEmergencyAccess() {
    _emergencyManager.recordAccessEvent();
    notifyListeners();
  }
}

void main() {
  group('Emergency Mode Screen (Milestone 20)', () {
    late _TestIngestionController controller;

    setUp(() {
      controller = _TestIngestionController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders minimized emergency medical card and contacts', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyModeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Card'), findsOneWidget);
      expect(find.text('Taraka Srikakolapu'), findsOneWidget);
      expect(find.text('O +ve'), findsOneWidget);
      expect(find.text('Penicillin (Severe Rash)'), findsOneWidget);
      expect(find.text('Ananya Srikakolapu'), findsOneWidget);
    });

    testWidgets('records access timestamp on opening screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyModeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.emergencyStorage.envelope.accessLog.length, 1);
    });
  });
}
