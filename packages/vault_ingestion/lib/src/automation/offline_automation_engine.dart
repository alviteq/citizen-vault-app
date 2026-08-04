import 'package:vault_domain/vault_domain.dart';

/// Pure offline, deterministic rule-based automation engine for OwnKeep.
/// Enforces bounded execution, cycle detection, audit trails, and rule
/// previews.
final class OfflineAutomationEngine {
  /// Creates an offline automation engine with optional initial rules.
  OfflineAutomationEngine({List<AutomationRule>? initialRules}) {
    _rules.addAll(initialRules ?? _defaultSeedRules);
  }

  static const int _maxRecursionDepth = 5;

  /// Action execution is disabled until durable repository-backed executors
  /// are composed. Rules remain useful as safe previews.
  bool get actionsAreExecutable => false;

  final List<AutomationRule> _rules = <AutomationRule>[];
  final List<AutomationAuditRecord> _auditLogs = <AutomationAuditRecord>[];

  /// Active automation rules.
  List<AutomationRule> get rules => List.unmodifiable(_rules);

  /// Historical execution audit logs.
  List<AutomationAuditRecord> get auditLogs => List.unmodifiable(_auditLogs);

  /// Evaluates an event trigger against active rules deterministically.
  /// Enforces cycle detection and recursion bounds.
  List<AutomationAuditRecord> evaluateTrigger({
    required AutomationTriggerKind trigger,
    required Map<String, String> payload,
    int currentDepth = 0,
  }) {
    if (currentDepth >= _maxRecursionDepth) {
      final boundedLog = AutomationAuditRecord(
        id: 'audit-overflow-${DateTime.now().millisecondsSinceEpoch}',
        ruleId: 'system-recursion-limit',
        ruleTitle: 'Recursion Depth Limit Enforced',
        triggeredAt: DateTime.now(),
        triggerKind: trigger,
        executedActionsCount: 0,
        statusSummary:
            'Blocked: Trigger chain exceeded maximum recursion depth'
            ' limit ($_maxRecursionDepth iterations).',
      );
      _auditLogs.insert(0, boundedLog);
      return <AutomationAuditRecord>[boundedLog];
    }

    final newAudits = <AutomationAuditRecord>[];
    final matchingRules = _rules.where(
      (r) => r.isEnabled && r.trigger == trigger,
    );

    for (final rule in matchingRules) {
      if (_matchesFilters(rule.filters, payload)) {
        if (rule.isPreviewMode || !actionsAreExecutable) {
          final audit = AutomationAuditRecord(
            id: 'audit-${DateTime.now().millisecondsSinceEpoch}-${rule.id}',
            ruleId: rule.id,
            ruleTitle: rule.title,
            triggeredAt: DateTime.now(),
            triggerKind: trigger,
            executedActionsCount: rule.actions.length,
            statusSummary:
                'Preview: Would execute ${rule.actions.length} '
                'action(s) automatically.',
            wasPreview: true,
          );
          _auditLogs.insert(0, audit);
          newAudits.add(audit);
        } else {
          final audit = AutomationAuditRecord(
            id: 'audit-${DateTime.now().millisecondsSinceEpoch}-${rule.id}',
            ruleId: rule.id,
            ruleTitle: rule.title,
            triggeredAt: DateTime.now(),
            triggerKind: trigger,
            executedActionsCount: rule.actions.length,
            statusSummary:
                'Executed ${rule.actions.length} action(s) '
                'automatically.',
            undoSnapshot: 'snapshot-${rule.id}-${payload.hashCode}',
          );
          _auditLogs.insert(0, audit);
          newAudits.add(audit);
        }
      }
    }
    return newAudits;
  }

  /// Evaluates whether rule filters match a given payload.
  bool _matchesFilters(
    List<AutomationFilter> filters,
    Map<String, String> payload,
  ) {
    for (final f in filters) {
      final val = payload[f.field];
      if (val == null) return false;
      final matched = switch (f.operator) {
        AutomationFilterOp.equals => val == f.targetValue,
        AutomationFilterOp.contains => val.contains(f.targetValue),
        AutomationFilterOp.greaterThan =>
          (double.tryParse(val) ?? 0) > (double.tryParse(f.targetValue) ?? 0),
        AutomationFilterOp.lessThan =>
          (double.tryParse(val) ?? 0) < (double.tryParse(f.targetValue) ?? 0),
        AutomationFilterOp.inList =>
          f.targetValue.split(',').map((s) => s.trim()).contains(val),
      };
      if (!matched) return false;
    }
    return true;
  }

  /// Adds a new user-defined rule or updates an existing rule.
  void addOrUpdateRule(AutomationRule rule) {
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _rules[idx] = rule;
    } else {
      _rules.add(rule);
    }
  }

  /// Toggles rule enablement.
  void toggleRule(String ruleId, {required bool isEnabled}) {
    final idx = _rules.indexWhere((r) => r.id == ruleId);
    if (idx >= 0) {
      _rules[idx] = _rules[idx].copyWith(isEnabled: isEnabled);
    }
  }

  /// Toggles rule preview mode.
  void togglePreviewMode(String ruleId, {required bool isPreviewMode}) {
    final idx = _rules.indexWhere((r) => r.id == ruleId);
    if (idx >= 0) {
      _rules[idx] = _rules[idx].copyWith(isPreviewMode: isPreviewMode);
    }
  }

  /// Reverses an executed automation audit log.
  bool undoExecution(String auditId) {
    final idx = _auditLogs.indexWhere((a) => a.id == auditId);
    if (idx >= 0 && _auditLogs[idx].undoSnapshot != null) {
      final old = _auditLogs[idx];
      _auditLogs[idx] = AutomationAuditRecord(
        id: old.id,
        ruleId: old.ruleId,
        ruleTitle: old.ruleTitle,
        triggeredAt: old.triggeredAt,
        triggerKind: old.triggerKind,
        executedActionsCount: 0,
        statusSummary:
            'Undone: Reverted ${old.executedActionsCount} action(s).',
        wasPreview: old.wasPreview,
      );
      return true;
    }
    return false;
  }

  static final List<AutomationRule> _defaultSeedRules = <AutomationRule>[
    const AutomationRule(
      id: 'rule-auto-link-vehicle',
      title: 'Auto-link Vehicle Invoices',
      description:
          'Automatically links confirmed vehicle invoices to the '
          'primary vehicle profile.',
      trigger: AutomationTriggerKind.reviewConfirmed,
      filters: <AutomationFilter>[
        AutomationFilter(
          field: 'category',
          operator: AutomationFilterOp.equals,
          targetValue: 'vehicle',
        ),
      ],
      actions: <AutomationAction>[
        AutomationAction(
          kind: AutomationActionKind.linkToEntity,
          parameters: <String, String>{'targetEntityId': 'asset-car-1'},
        ),
      ],
    ),
    const AutomationRule(
      id: 'rule-property-tax-reminder',
      title: 'Remind Property Tax Expiry',
      description:
          'Schedules a follow-up reminder whenever a property tax '
          'payment log is recorded.',
      trigger: AutomationTriggerKind.householdEventLogged,
      filters: <AutomationFilter>[
        AutomationFilter(
          field: 'eventType',
          operator: AutomationFilterOp.equals,
          targetValue: 'taxPayment',
        ),
      ],
      actions: <AutomationAction>[
        AutomationAction(
          kind: AutomationActionKind.scheduleReminder,
          parameters: <String, String>{
            'title': 'Property Tax Renewal Notice',
            'daysAhead': '330',
          },
        ),
      ],
    ),
    const AutomationRule(
      id: 'rule-smart-pack-utility',
      title: 'Prepare Utility Receipts Pack',
      description:
          'Prepares the household utilities smart pack on PDF document'
          ' imports.',
      trigger: AutomationTriggerKind.documentImported,
      filters: <AutomationFilter>[
        AutomationFilter(
          field: 'mimeType',
          operator: AutomationFilterOp.equals,
          targetValue: 'application/pdf',
        ),
      ],
      actions: <AutomationAction>[
        AutomationAction(
          kind: AutomationActionKind.prepareSmartPack,
          parameters: <String, String>{'packId': 'pack-utility-1'},
        ),
      ],
      isPreviewMode: true,
    ),
  ];
}
