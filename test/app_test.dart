import 'package:citizen_vault_app/src/app.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_domain/vault_domain.dart';

final class _AppTestController extends IngestionUiController {
  VaultPreferencesView _preferences = const VaultPreferencesView.defaults();

  @override
  VaultPreferencesView get preferences => _preferences;

  @override
  List<DocumentProcessingView> get jobs => const <DocumentProcessingView>[];

  @override
  List<DocumentReviewView> get reviews => const <DocumentReviewView>[];

  @override
  bool get isBusy => false;

  @override
  bool get isVaultAvailable => true;

  @override
  String? get notice => null;

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
  Future<void> savePreferences(VaultPreferencesView value) async {
    _preferences = value;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AppTestController controller;

  setUp(() {
    controller = _AppTestController();
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('unlocked shell navigates across every primary destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CitizenVaultApp(ingestionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    expect(find.text('Search OwnKeep...'), findsOneWidget);

    await tester.tap(find.text('Timeline').last);
    await tester.pumpAndSettle();
    expect(find.text('Life Timeline'), findsWidgets);

    await tester.tap(find.text('Vault').last);
    await tester.pumpAndSettle();
    expect(find.text('Backup & Recovery'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    expect(find.text('Add New'), findsOneWidget);
    expect(find.text('Scan Document'), findsOneWidget);
    expect(find.text('From Files'), findsOneWidget);
  });

  testWidgets('appearance preference updates the unlocked shell immediately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CitizenVaultApp(ingestionController: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vault').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Dark Mode'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    final switchFinder = find.widgetWithText(SwitchListTile, 'Dark Mode');
    expect(Theme.of(tester.element(switchFinder)).brightness, Brightness.light);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(controller.preferences.darkMode, isTrue);
    expect(
      Theme.of(tester.element(find.byType(SwitchListTile).first)).brightness,
      Brightness.dark,
    );
  });
}
