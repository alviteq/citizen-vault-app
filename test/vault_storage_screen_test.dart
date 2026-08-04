import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/settings/vault_storage_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _StorageController extends IngestionUiController {
  var cleanupCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<VaultStorageSummary> storageSummary() async =>
      const VaultStorageSummary(
        databaseBytes: 2048,
        objectBytes: 4096,
        temporaryBytes: 512,
        otherBytes: 128,
        fileCount: 4,
      );

  @override
  Future<void> cleanTemporaryStorage() async {
    cleanupCount += 1;
  }
}

void main() {
  testWidgets('storage maintenance is explicit and safely refreshes usage', (
    tester,
  ) async {
    final controller = _StorageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: VaultStorageScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('6.6 KB'), findsOneWidget);
    expect(find.text('Clean temporary files'), findsOneWidget);

    await tester.tap(find.text('Clean temporary files'));
    await tester.pumpAndSettle();

    expect(controller.cleanupCount, 1);
    await tester.scrollUntilVisible(
      find.text('Recently deleted'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Recently deleted'), findsOneWidget);
  });
}
