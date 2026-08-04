/// Local reminder scheduling and OS-notification projection.
library;

export 'src/notification_projection.dart';
export 'src/reminder_coordinator.dart';
export 'src/reminder_repository.dart';

/// Milestone-eight API metadata for local reminders and notifications.
abstract final class VaultNotificationsPackage {
  /// Package API version.
  static const String apiVersion = '0.9.0';
}
