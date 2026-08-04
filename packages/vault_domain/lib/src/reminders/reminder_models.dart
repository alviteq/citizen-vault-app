// Immutable reminder fields are documented at their type boundaries.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';

enum ReminderType {
  dueDate('DUE_DATE', 'Due date'),
  expiry('EXPIRY', 'Expiry'),
  custom('CUSTOM', 'Custom');

  const ReminderType(this.storageValue, this.displayName);

  final String storageValue;
  final String displayName;

  static ReminderType fromStorage(String value) => values.singleWhere(
    (type) => type.storageValue == value,
    orElse: () => custom,
  );
}

@immutable
final class ReminderView {
  const ReminderView({
    required this.id,
    required this.documentId,
    required this.documentFilename,
    required this.type,
    required this.title,
    required this.dueAt,
    required this.isEnabled,
    required this.notificationId,
    this.completedAt,
  });

  final String id;
  final String documentId;
  final String documentFilename;
  final ReminderType type;
  final String title;
  final DateTime dueAt;
  final bool isEnabled;
  final int notificationId;
  final DateTime? completedAt;
}

@immutable
final class ReminderDraft {
  const ReminderDraft({
    required this.documentId,
    required this.type,
    required this.title,
    required this.dueAt,
  });

  final String documentId;
  final ReminderType type;
  final String title;
  final DateTime dueAt;
}
