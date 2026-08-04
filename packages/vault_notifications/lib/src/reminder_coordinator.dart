// Named public dependencies intentionally initialize private owned fields.
// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: prefer_initializing_formals

import 'package:vault_domain/vault_domain.dart';
import 'package:vault_notifications/src/notification_projection.dart';
import 'package:vault_notifications/src/reminder_repository.dart';

/// Keeps OS notifications as a bounded projection of SQLCipher reminders.
final class ReminderCoordinator {
  /// Creates a coordinator for one unlocked vault.
  const ReminderCoordinator({
    required ReminderRepository repository,
    required LocalNotificationProjection projection,
  }) : _repository = repository,
       _projection = projection;

  final ReminderRepository _repository;
  final LocalNotificationProjection _projection;

  /// Initializes the adapter and repairs projection drift without prompting.
  Future<void> initializeAndReconcile() async {
    await _projection.initialize();
    await reconcile();
  }

  /// Lists active authoritative reminders.
  Future<List<ReminderView>> list({String? documentId}) =>
      _repository.list(documentId: documentId);

  /// Creates an in-app reminder and requests OS permission from this user act.
  Future<ReminderView> create(ReminderDraft draft) async {
    final granted = await _projection.requestPermission();
    final reminder = await _repository.create(draft, enabled: granted);
    await reconcile();
    return reminder;
  }

  /// Enables or disables a reminder, prompting only when explicitly enabled.
  Future<void> setEnabled(String reminderId, bool enabled) async {
    final allowed = !enabled || await _projection.requestPermission();
    await _repository.setEnabled(reminderId, enabled && allowed);
    await reconcile();
  }

  /// Snoozes relative to the current instant.
  Future<void> snooze(String reminderId, Duration duration) async {
    if (duration <= Duration.zero) throw ArgumentError.value(duration);
    final granted = await _projection.requestPermission();
    await _repository.reschedule(
      reminderId,
      DateTime.now().toUtc().add(duration),
    );
    if (!granted) await _repository.setEnabled(reminderId, false);
    await reconcile();
  }

  /// Reschedules to an explicit instant.
  Future<void> reschedule(String reminderId, DateTime dueAt) async {
    final granted = await _projection.requestPermission();
    await _repository.reschedule(reminderId, dueAt);
    if (!granted) await _repository.setEnabled(reminderId, false);
    await reconcile();
  }

  /// Completes a reminder and removes its OS projection.
  Future<void> complete(String reminderId) async {
    await _repository.complete(reminderId);
    await reconcile();
  }

  /// Deletes a reminder and removes its OS projection.
  Future<void> delete(String reminderId) async {
    await _repository.delete(reminderId);
    await reconcile();
  }

  /// Repairs pending OS state from the encrypted database source of truth.
  Future<void> reconcile() async {
    final reminders = await _repository.list();
    final desired = <int, ReminderView>{
      for (final reminder in reminders)
        if (reminder.isEnabled &&
            reminder.dueAt.isAfter(DateTime.now().toUtc()))
          reminder.notificationId: reminder,
    };
    final pending = await _projection.pendingNotificationIds();
    for (final notificationId in pending.difference(desired.keys.toSet())) {
      await _projection.cancel(notificationId);
    }
    if (await _projection.permissionState() !=
        NotificationPermissionState.granted) {
      return;
    }
    // iOS retains at most 64 pending notifications; keep a safety margin and
    // always project the soonest authoritative reminders.
    final ordered = desired.values.toList()
      ..sort((left, right) => left.dueAt.compareTo(right.dueAt));
    for (final reminder in ordered.take(60)) {
      await _projection.schedule(reminder);
    }
  }
}
