import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_notifications/vault_notifications.dart';

/// Android/iOS private local-notification projection.
final class FlutterLocalNotificationProjection
    implements LocalNotificationProjection {
  /// Creates a projection with an injectable plugin for tests.
  FlutterLocalNotificationProjection({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static final StreamController<String> _documentOpenController =
      StreamController<String>.broadcast();

  /// Document IDs requested by user taps on projected notifications.
  static Stream<String> get documentOpenRequests =>
      _documentOpenController.stream;
  var _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      timezone_data.initializeTimeZones();
      timezone.setLocalLocation(timezone.UTC);
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_vault'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _emitPayload(launch?.notificationResponse?.payload);
      }
    } on Object {
      // Fallback on platforms without local notification native binding
    }
  }

  static void _handleResponse(NotificationResponse response) {
    _emitPayload(response.payload);
  }

  static void _emitPayload(String? payload) {
    const prefix = 'document:';
    if (payload == null || !payload.startsWith(prefix)) return;
    final documentId = payload.substring(prefix.length);
    if (documentId.isNotEmpty) _documentOpenController.add(documentId);
  }

  @override
  Future<NotificationPermissionState> permissionState() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return enabled == true
          ? NotificationPermissionState.granted
          : NotificationPermissionState.denied;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      if (options == null) return NotificationPermissionState.notDetermined;
      return options.isEnabled || options.isProvisionalEnabled
          ? NotificationPermissionState.granted
          : NotificationPermissionState.denied;
    }
    return NotificationPermissionState.denied;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    await initialize();
    return (await _plugin.pendingNotificationRequests())
        .map((request) => request.id)
        .toSet();
  }

  @override
  Future<void> schedule(ReminderView reminder) async {
    await initialize();
    if (!reminder.dueAt.isAfter(DateTime.now().toUtc())) {
      await cancel(reminder.notificationId);
      return;
    }
    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      title: 'OwnKeep reminder',
      body: 'Open OwnKeep to review a private document reminder.',
      scheduledDate: timezone.TZDateTime.from(reminder.dueAt, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'citizen_vault_reminders',
          'Document reminders',
          channelDescription: 'Private due-date and expiry reminders',
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'document:${reminder.documentId}',
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    await initialize();
    await _plugin.cancel(id: notificationId);
  }
}
