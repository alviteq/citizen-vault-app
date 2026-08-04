import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/life/entity_directory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  setUp(() {
    OfflineMultilingualEngine().setUiLanguage(SupportedLanguage.english);
  });

  testWidgets('place directory add flow defaults to an allowed place type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EntityDirectoryScreen(
          controller: _DirectoryController(),
          title: 'Places',
          initialTypes: const {LifeEntityType.place, LifeEntityType.property},
        ),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add profile'), findsOneWidget);
    expect(find.text('Place'), findsOneWidget);
    expect(find.text('Person'), findsNothing);
  });

  testWidgets('cancelling aliases closes without using a disposed controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EntityProfileScreen(
          controller: _DirectoryController(),
          entity: LifeEntity(
            id: 'person-1',
            type: LifeEntityType.person,
            displayName: 'Taraka',
            status: LifeEntityStatus.active,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aliases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Aliases'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _DirectoryController extends IngestionUiController {
  @override
  List<DocumentProcessingView> get jobs => const [];

  @override
  List<DocumentReviewView> get reviews => const [];

  @override
  bool get isBusy => false;

  @override
  bool get isVaultAvailable => true;

  @override
  String? get notice => null;

  @override
  Future<void> importFile() async {}

  @override
  Future<void> importGalleryImage() async {}

  @override
  Future<void> captureImage() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> recover() async {}

  @override
  Future<void> confirmReview({
    required String documentId,
    required DocumentType documentType,
    required List<ConfirmedFieldEdit> fields,
    String? profileEntityId,
  }) async {}

  @override
  Future<List<DocumentSearchResult>> search(String query) async => const [];
}
