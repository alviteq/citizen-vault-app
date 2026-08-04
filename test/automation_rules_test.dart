import 'package:citizen_vault_app/src/automation/automation_rules_screen.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

final class _TestIngestionController extends IngestionUiController {
  final _engine = OfflineAutomationEngine();

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
  OfflineAutomationEngine get automationEngine => _engine;

  @override
  void addOrUpdateAutomationRule(AutomationRule rule) {
    _engine.addOrUpdateRule(rule);
    notifyListeners();
  }

  @override
  void toggleAutomationRule(String ruleId, bool isEnabled) {
    _engine.toggleRule(ruleId, isEnabled: isEnabled);
    notifyListeners();
  }

  @override
  void toggleAutomationPreviewMode(String ruleId, bool isPreviewMode) {
    _engine.togglePreviewMode(ruleId, isPreviewMode: isPreviewMode);
    notifyListeners();
  }

  @override
  void evaluateAutomationTrigger({
    required AutomationTriggerKind trigger,
    required Map<String, String> payload,
  }) {
    _engine.evaluateTrigger(trigger: trigger, payload: payload);
    notifyListeners();
  }

  @override
  bool undoAutomationExecution(String auditId) {
    final res = _engine.undoExecution(auditId);
    if (res) notifyListeners();
    return res;
  }
}

void main() {
  group('Offline Automation Engine (Milestone 18)', () {
    late _TestIngestionController controller;

    setUp(() {
      controller = _TestIngestionController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders active rules and preset templates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AutomationRulesScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline Automation Engine'), findsOneWidget);
      expect(find.text('Auto-link Vehicle Invoices'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Remind Property Tax Expiry'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      expect(find.text('Remind Property Tax Expiry'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Prepare Utility Receipts Pack'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      expect(find.text('Prepare Utility Receipts Pack'), findsOneWidget);
    });

    testWidgets('evaluates triggers and records execution audit logs', (
      tester,
    ) async {
      controller.evaluateAutomationTrigger(
        trigger: AutomationTriggerKind.reviewConfirmed,
        payload: <String, String>{'category': 'vehicle'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AutomationRulesScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Execution Audit'));
      await tester.pumpAndSettle();

      expect(find.text('Auto-link Vehicle Invoices'), findsOneWidget);
      expect(
        find.text('Preview: Would execute 1 action(s) automatically.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.undo), findsNothing);
    });

    testWidgets('toggles rule preview mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AutomationRulesScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Mode'), findsAtLeast(1));

      await tester.tap(find.text('Live Mode').first);
      await tester.pumpAndSettle();

      expect(find.text('Preview Mode'), findsAtLeast(1));
    });
  });
}
