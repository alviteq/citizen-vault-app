// Attention fields are documented at their public type boundaries.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';

enum LifeStateKind {
  ok('OK'),
  unknown('UNKNOWN'),
  incomplete('INCOMPLETE'),
  missing('MISSING'),
  expiresSoon('EXPIRES_SOON'),
  expired('EXPIRED'),
  overdue('OVERDUE'),
  actionRequired('ACTION_REQUIRED');

  const LifeStateKind(this.storageValue);
  final String storageValue;

  static LifeStateKind fromStorage(String value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => unknown,
  );
}

enum AttentionCategory {
  expiry('EXPIRY'),
  missingEvidence('MISSING_EVIDENCE'),
  dueBill('DUE_BILL'),
  service('SERVICE'),
  warranty('WARRANTY'),
  inbox('INBOX'),
  integrity('INTEGRITY');

  const AttentionCategory(this.storageValue);
  final String storageValue;

  static AttentionCategory fromStorage(String value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => inbox,
  );
}

enum AttentionStatus {
  active('ACTIVE'),
  resolved('RESOLVED'),
  dismissed('DISMISSED');

  const AttentionStatus(this.storageValue);
  final String storageValue;

  static AttentionStatus fromStorage(String value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => active,
  );
}

enum LifeTaskOrigin {
  manual('MANUAL'),
  generated('GENERATED');

  const LifeTaskOrigin(this.storageValue);
  final String storageValue;

  static LifeTaskOrigin fromStorage(String value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => manual,
  );
}

enum LifeTaskStatus {
  open('OPEN'),
  completed('COMPLETED'),
  dismissed('DISMISSED');

  const LifeTaskStatus(this.storageValue);
  final String storageValue;

  static LifeTaskStatus fromStorage(String value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => open,
  );
}

@immutable
final class DerivedLifeState {
  const DerivedLifeState({
    required this.id,
    required this.kind,
    required this.ruleId,
    required this.ruleVersion,
    required this.explanation,
    required this.calculatedAt,
    this.subjectEntityId,
    this.sourceClaimId,
    this.sourceEventId,
    this.sourceDocumentId,
    this.evidenceDocumentId,
    this.inputFingerprint,
  });

  final String id;
  final LifeStateKind kind;
  final String ruleId;
  final String ruleVersion;
  final String explanation;
  final DateTime calculatedAt;
  final String? subjectEntityId;
  final String? sourceClaimId;
  final String? sourceEventId;
  final String? sourceDocumentId;
  final String? evidenceDocumentId;
  final String? inputFingerprint;
}

@immutable
final class AttentionItem {
  const AttentionItem({
    required this.id,
    required this.category,
    required this.title,
    required this.explanation,
    required this.priority,
    required this.status,
    required this.ruleId,
    required this.ruleVersion,
    required this.createdAt,
    required this.updatedAt,
    this.stateId,
    this.dueAt,
    this.entityId,
    this.claimId,
    this.eventId,
    this.documentId,
    this.evidenceDocumentId,
  });

  final String id;
  final AttentionCategory category;
  final String title;
  final String explanation;
  final int priority;
  final AttentionStatus status;
  final String ruleId;
  final String ruleVersion;
  final String? stateId;
  final DateTime? dueAt;
  final String? entityId;
  final String? claimId;
  final String? eventId;
  final String? documentId;
  final String? evidenceDocumentId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
final class LifeTask {
  const LifeTask({
    required this.id,
    required this.title,
    required this.origin,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.dueAt,
    this.recurrenceRule,
    this.snoozedUntil,
    this.completedAt,
    this.dismissedAt,
    this.sourceAttentionId,
    this.entityId,
    this.eventId,
    this.documentId,
  });

  final String id;
  final String title;
  final String? notes;
  final LifeTaskOrigin origin;
  final LifeTaskStatus status;
  final DateTime? dueAt;
  final String? recurrenceRule;
  final DateTime? snoozedUntil;
  final DateTime? completedAt;
  final DateTime? dismissedAt;
  final String? sourceAttentionId;
  final String? entityId;
  final String? eventId;
  final String? documentId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
final class LifeChecklist {
  const LifeChecklist({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.entityId,
    this.eventId,
    this.evidenceDocumentId,
    this.items = const [],
  });

  final String id;
  final String title;
  final String? entityId;
  final String? eventId;
  final String? evidenceDocumentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LifeChecklistItem> items;
}

@immutable
final class LifeChecklistItem {
  const LifeChecklistItem({
    required this.id,
    required this.checklistId,
    required this.title,
    required this.position,
    required this.isCompleted,
    this.completedAt,
  });

  final String id;
  final String checklistId;
  final String title;
  final int position;
  final bool isCompleted;
  final DateTime? completedAt;
}
