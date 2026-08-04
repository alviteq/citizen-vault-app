import 'package:meta/meta.dart';

/// Supported automation trigger kinds.
enum AutomationTriggerKind {
  /// Triggered when a new document is imported into the vault.
  documentImported('Document Imported'),

  /// Triggered when a document extraction review is confirmed.
  reviewConfirmed('Review Confirmed'),

  /// Triggered when an entity or asset operational state changes.
  derivedStateChanged('State Changed'),

  /// Triggered on a scheduled calendar date or reminder boundary.
  dateReached('Date Reached'),

  /// Triggered when a vehicle/property/device maintenance or tax log is recorded.
  householdEventLogged('Household Event Logged');

  const AutomationTriggerKind(this.displayName);

  /// Human-readable display label.
  final String displayName;
}

/// Comparison operators for rule filters.
enum AutomationFilterOp {
  /// Exact match comparison.
  equals('equals'),

  /// Substring match comparison.
  contains('contains'),

  /// Greater than threshold comparison.
  greaterThan('greater than'),

  /// Less than threshold comparison.
  lessThan('less than'),

  /// Value exists within a list of valid options.
  inList('in list');

  const AutomationFilterOp(this.displayName);

  /// Human-readable display label.
  final String displayName;
}

/// Single filter criteria evaluated against trigger payload.
@immutable
final class AutomationFilter {
  /// Creates a filter condition.
  const AutomationFilter({
    required this.field,
    required this.operator,
    required this.targetValue,
  });

  /// Target payload field name (e.g. 'category', 'cost', 'documentType').
  final String field;

  /// Comparison operator.
  final AutomationFilterOp operator;

  /// Target value to evaluate against.
  final String targetValue;
}

/// Action kinds that can be executed automatically.
enum AutomationActionKind {
  /// Automatically link document to a person, place, or thing profile.
  linkToEntity('Link to Profile'),

  /// Propose an insurance or warranty claim.
  proposeClaim('Propose Claim'),

  /// Create a life timeline event.
  createLifeEvent('Create Life Event'),

  /// Schedule a follow-up reminder.
  scheduleReminder('Schedule Reminder'),

  /// Create a life task or checklist item.
  createLifeTask('Create Life Task'),

  /// Prepare an offline smart pack.
  prepareSmartPack('Prepare Smart Pack');

  const AutomationActionKind(this.displayName);

  /// Human-readable display label.
  final String displayName;
}

/// Single action payload to execute when rule filters match.
@immutable
final class AutomationAction {
  /// Creates an action specification.
  const AutomationAction({
    required this.kind,
    this.parameters = const <String, String>{},
  });

  /// Kind of automation action.
  final AutomationActionKind kind;

  /// Parameter map for action execution (e.g. target entity ID, task title).
  final Map<String, String> parameters;
}

/// A local WHEN / IF / THEN automation rule.
@immutable
final class AutomationRule {
  /// Creates an automation rule.
  const AutomationRule({
    required this.id,
    required this.title,
    required this.trigger,
    this.version = 1,
    this.description,
    this.filters = const <AutomationFilter>[],
    this.actions = const <AutomationAction>[],
    this.isEnabled = true,
    this.isPreviewMode = false,
  });

  /// Unique identifier.
  final String id;

  /// Human-readable title.
  final String title;

  /// Version number of rule schema.
  final int version;

  /// Explanation of rule purpose.
  final String? description;

  /// WHEN trigger condition.
  final AutomationTriggerKind trigger;

  /// IF filter criteria list.
  final List<AutomationFilter> filters;

  /// THEN action list to execute.
  final List<AutomationAction> actions;

  /// Whether rule is actively running.
  final bool isEnabled;

  /// If true, rule logs intended execution without mutating state.
  final bool isPreviewMode;

  /// Creates a copy with updated properties.
  AutomationRule copyWith({
    String? id,
    String? title,
    int? version,
    String? description,
    AutomationTriggerKind? trigger,
    List<AutomationFilter>? filters,
    List<AutomationAction>? actions,
    bool? isEnabled,
    bool? isPreviewMode,
  }) {
    return AutomationRule(
      id: id ?? this.id,
      title: title ?? this.title,
      version: version ?? this.version,
      description: description ?? this.description,
      trigger: trigger ?? this.trigger,
      filters: filters ?? this.filters,
      actions: actions ?? this.actions,
      isEnabled: isEnabled ?? this.isEnabled,
      isPreviewMode: isPreviewMode ?? this.isPreviewMode,
    );
  }
}

/// Replayable and explainable execution audit log record for an automation.
@immutable
final class AutomationAuditRecord {
  /// Creates an execution audit log.
  const AutomationAuditRecord({
    required this.id,
    required this.ruleId,
    required this.ruleTitle,
    required this.triggeredAt,
    required this.triggerKind,
    required this.executedActionsCount,
    required this.statusSummary,
    this.wasPreview = false,
    this.undoSnapshot,
  });

  /// Unique audit record ID.
  final String id;

  /// Target rule ID.
  final String ruleId;

  /// Target rule title.
  final String ruleTitle;

  /// Timestamp of trigger event.
  final DateTime triggeredAt;

  /// Trigger kind that matched.
  final AutomationTriggerKind triggerKind;

  /// Number of actions executed.
  final int executedActionsCount;

  /// Human-readable status summary.
  final String statusSummary;

  /// Whether execution was preview-only.
  final bool wasPreview;

  /// Reversible state snapshot for safe undo operations.
  final String? undoSnapshot;
}
