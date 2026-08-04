// Event fields are documented at their public type boundaries.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';

/// Stable event vocabulary for OwnKeep's temporal Life Graph.
enum LifeEventType {
  purchase('PURCHASE', 'Purchase'),
  payment('PAYMENT', 'Payment'),
  renewal('RENEWAL', 'Renewal'),
  expiry('EXPIRY', 'Expiry'),
  service('SERVICE', 'Service'),
  repair('REPAIR', 'Repair'),
  medical('MEDICAL', 'Medical'),
  education('EDUCATION', 'Education'),
  tax('TAX', 'Tax'),
  employment('EMPLOYMENT', 'Employment'),
  warranty('WARRANTY', 'Warranty'),
  custom('CUSTOM', 'Custom');

  const LifeEventType(this.storageValue, this.displayName);

  final String storageValue;
  final String displayName;

  static LifeEventType fromStorage(String value) => values.firstWhere(
    (type) => type.storageValue == value,
    orElse: () => custom,
  );
}

/// Review state for a temporal event.
enum LifeEventStatus {
  suggested('SUGGESTED'),
  confirmed('CONFIRMED'),
  rejected('REJECTED'),
  superseded('SUPERSEDED');

  const LifeEventStatus(this.storageValue);

  final String storageValue;

  static LifeEventStatus fromStorage(String value) => values.firstWhere(
    (status) => status.storageValue == value,
    orElse: () => suggested,
  );
}

/// Immutable temporal event with optional money, place, and provenance.
@immutable
final class LifeEvent {
  const LifeEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.startAt,
    required this.status,
    this.endAt,
    this.amountMinorUnits,
    this.currency,
    this.locationEntityId,
    this.notes,
    this.supersedesId,
    this.provenanceId,
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.rejectedAt,
  });

  final String id;
  final LifeEventType type;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final LifeEventStatus status;
  final int? amountMinorUnits;
  final String? currency;
  final String? locationEntityId;
  final String? notes;
  final String? supersedesId;
  final String? provenanceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final DateTime? rejectedAt;

  bool get isExpense =>
      amountMinorUnits != null &&
      amountMinorUnits! >= 0 &&
      (type == LifeEventType.purchase ||
          type == LifeEventType.payment ||
          type == LifeEventType.renewal ||
          type == LifeEventType.service ||
          type == LifeEventType.repair ||
          type == LifeEventType.medical ||
          type == LifeEventType.education ||
          type == LifeEventType.tax ||
          type == LifeEventType.warranty);
}

/// One role-qualified link between an Event and an Entity.
@immutable
final class LifeEventEntityLink {
  const LifeEventEntityLink({
    required this.id,
    required this.eventId,
    required this.entityId,
    required this.role,
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String entityId;
  final String role;
  final DateTime? createdAt;
}

/// Exact encrypted-document evidence attached to an Event.
@immutable
final class LifeEventEvidence {
  const LifeEventEvidence({
    required this.id,
    required this.eventId,
    required this.documentId,
    required this.evidenceRole,
    this.assetId,
    this.pageNumber,
    this.boundingPolygonJson,
    this.textFragmentHash,
    this.provenanceId,
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String documentId;
  final String evidenceRole;
  final String? assetId;
  final int? pageNumber;
  final String? boundingPolygonJson;
  final List<int>? textFragmentHash;
  final String? provenanceId;
  final DateTime? createdAt;
}

/// One auditable status transition in an Event's immutable history.
@immutable
final class LifeEventHistoryEntry {
  const LifeEventHistoryEntry({
    required this.id,
    required this.eventId,
    required this.eventType,
    required this.createdAt,
    this.previousStatus,
    this.provenanceId,
  });

  final String id;
  final String eventId;
  final String eventType;
  final LifeEventStatus? previousStatus;
  final String? provenanceId;
  final DateTime createdAt;
}

/// Currency-specific confirmed expense total for one requested period.
@immutable
final class LifeExpenseTotal {
  const LifeExpenseTotal({
    required this.currency,
    required this.amountMinorUnits,
    required this.eventCount,
  });

  final String currency;
  final int amountMinorUnits;
  final int eventCount;
}
