import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('OfflineAutomationEngine (Milestone 18 Gate)', () {
    late OfflineAutomationEngine engine;

    setUp(() {
      engine = OfflineAutomationEngine();
    });

    test('evaluates default seed rules deterministically', () {
      expect(engine.rules.length, greaterThanOrEqualTo(3));

      final audits = engine.evaluateTrigger(
        trigger: AutomationTriggerKind.reviewConfirmed,
        payload: <String, String>{'category': 'vehicle'},
      );

      expect(audits, hasLength(1));
      expect(audits.first.ruleTitle, 'Auto-link Vehicle Invoices');
      expect(audits.first.executedActionsCount, 1);
      expect(audits.first.wasPreview, isTrue);
      expect(audits.first.statusSummary, contains('Preview'));
    });

    test('respects preview mode without mutating state', () {
      final audits = engine.evaluateTrigger(
        trigger: AutomationTriggerKind.documentImported,
        payload: <String, String>{'mimeType': 'application/pdf'},
      );

      expect(audits, hasLength(1));
      expect(audits.first.wasPreview, isTrue);
      expect(audits.first.statusSummary, contains('Preview'));
    });

    test('enforces max recursion depth bound (Milestone 18 Gate)', () {
      final audits = engine.evaluateTrigger(
        trigger: AutomationTriggerKind.derivedStateChanged,
        payload: <String, String>{'state': 'updated'},
        currentDepth: 5,
      );

      expect(audits, hasLength(1));
      expect(audits.first.ruleTitle, 'Recursion Depth Limit Enforced');
      expect(
        audits.first.statusSummary,
        contains('exceeded maximum recursion'),
      );
    });

    test('does not claim undo for preview-only actions', () {
      final audits = engine.evaluateTrigger(
        trigger: AutomationTriggerKind.reviewConfirmed,
        payload: <String, String>{'category': 'vehicle'},
      );

      final auditId = audits.first.id;
      final undone = engine.undoExecution(auditId);

      expect(undone, isFalse);
      expect(engine.auditLogs.first.statusSummary, contains('Preview'));
    });

    test('toggles rule status and preview mode', () {
      engine.toggleRule('rule-auto-link-vehicle', isEnabled: false);
      var audits = engine.evaluateTrigger(
        trigger: AutomationTriggerKind.reviewConfirmed,
        payload: <String, String>{'category': 'vehicle'},
      );
      expect(audits, isEmpty);

      engine.toggleRule('rule-auto-link-vehicle', isEnabled: true);
      audits = engine.evaluateTrigger(
        trigger: AutomationTriggerKind.reviewConfirmed,
        payload: <String, String>{'category': 'vehicle'},
      );
      expect(audits, hasLength(1));
    });
  });
}
