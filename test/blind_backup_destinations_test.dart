import 'package:citizen_vault_app/src/backup/blind_backup_destinations_screen.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

final class _TestIngestionController extends IngestionUiController {
  final _blindBackupEngine = BlindBackupDestinationEngine();

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
  BlindBackupDestinationEngine get blindBackupEngine => _blindBackupEngine;

  @override
  void configureBlindBackupDestination(BlindBackupConfig config) {
    _blindBackupEngine.activeConfig = config;
    notifyListeners();
  }

  @override
  BlindBackupSyncStatus triggerBlindSyncRehearsal() {
    final res = _blindBackupEngine.triggerBlindSync(
      encryptedArchiveBytesHex: '0102030405060708',
    );
    notifyListeners();
    return res;
  }
}

void main() {
  group('Blind Backup Destinations Screen (Milestone 24)', () {
    late _TestIngestionController controller;

    setUp(() {
      controller = _TestIngestionController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders blind backup options and zero token policy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlindBackupDestinationsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blind Backup Destinations'), findsOneWidget);
      expect(find.text('Zero Token Blind Backup Policy'), findsOneWidget);
      expect(find.text('Trigger Blind Sync Rehearsal'), findsOneWidget);
    });

    testWidgets('triggers blind sync rehearsal cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlindBackupDestinationsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Trigger Blind Sync Rehearsal'),
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );
      await tester.tap(find.text('Trigger Blind Sync Rehearsal'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Automatic provider sync is not configured'),
        findsOneWidget,
      );
    });
  });
}
