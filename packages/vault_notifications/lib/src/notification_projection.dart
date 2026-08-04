import 'package:vault_domain/vault_domain.dart';

/// Current OS authorization state without triggering a prompt.
// Enum values are documented at the type boundary.
// ignore: public_member_api_docs
enum NotificationPermissionState { granted, denied, notDetermined }

/// Replaceable projection of authoritative SQLCipher reminders into the OS.
abstract interface class LocalNotificationProjection {
  /// Initializes platform notification and time-zone services.
  Future<void> initialize();

  /// Reads permission without prompting.
  Future<NotificationPermissionState> permissionState();

  /// Requests permission from an explicit user reminder action.
  Future<bool> requestPermission();

  /// Pending OS notification identifiers owned by Citizen Vault.
  Future<Set<int>> pendingNotificationIds();

  /// Schedules or replaces a private notification for [reminder].
  Future<void> schedule(ReminderView reminder);

  /// Cancels one projected notification.
  Future<void> cancel(int notificationId);
}

/// Test/headless projection that reports permission denied.
final class DisabledNotificationProjection
    implements LocalNotificationProjection {
  /// Creates the disabled projection.
  const DisabledNotificationProjection();

  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<Set<int>> pendingNotificationIds() async => const <int>{};

  @override
  Future<NotificationPermissionState> permissionState() async =>
      NotificationPermissionState.denied;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule(ReminderView reminder) async {}
}
