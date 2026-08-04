import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_notifications/vault_notifications.dart';

void main() {
  test(
    'database remains authoritative during reminder reconciliation',
    () async {
      final root = Directory.systemTemp.createTempSync('vault_reminder_test_');
      final key = SecretBytes(List<int>.generate(32, (index) => index + 1));
      final session = await EncryptedDatabaseOpener.open(
        file: File('${root.path}/vault.db'),
        databaseKey: key,
        runInBackground: false,
      );
      key.destroy();
      addTearDown(() async {
        await session.close();
        root.deleteSync(recursive: true);
      });
      await session.write((database) async {
        final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
        await database.customStatement(
          '''
        INSERT INTO documents(
          id, logical_filename, mime_type, source_type, status,
          primary_object_id, plaintext_sha256, plaintext_size, encrypted_size,
          imported_at, updated_at, integrity_status
        ) VALUES ('document-1', 'policy.pdf', 'application/pdf', 'FILE_PICKER',
          'READY', 'object-1', ?, 100, 200, ?, ?, 'VERIFIED')
        ''',
          <Object>[Uint8List(32), timestamp, timestamp],
        );
      });
      final projection = _FakeProjection()..pending.add(999);
      final coordinator = ReminderCoordinator(
        repository: ReminderRepository(
          session: session,
          random: const _FixedRandom(),
        ),
        projection: projection,
      );
      final reminder = await coordinator.create(
        ReminderDraft(
          documentId: 'document-1',
          type: ReminderType.expiry,
          title: 'Policy expiry',
          dueAt: DateTime.now().toUtc().add(const Duration(days: 30)),
        ),
      );

      expect(reminder.isEnabled, isTrue);
      final duplicate = await coordinator.create(
        ReminderDraft(
          documentId: 'document-1',
          type: ReminderType.expiry,
          title: 'Policy expiry duplicate',
          dueAt: reminder.dueAt,
        ),
      );
      expect(duplicate.id, reminder.id);
      expect(await coordinator.list(), hasLength(1));
      expect(projection.scheduled, contains(reminder.notificationId));
      expect(projection.cancelled, contains(999));
      await coordinator.snooze(reminder.id, const Duration(days: 1));
      expect(projection.scheduled, contains(reminder.notificationId));
      await coordinator.complete(reminder.id);
      expect(await coordinator.list(), isEmpty);
      expect(projection.cancelled, contains(reminder.notificationId));
    },
  );
}

final class _FakeProjection implements LocalNotificationProjection {
  final Set<int> pending = <int>{};
  final Set<int> scheduled = <int>{};
  final Set<int> cancelled = <int>{};

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    pending.remove(notificationId);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<Set<int>> pendingNotificationIds() async => Set<int>.from(pending);

  @override
  Future<NotificationPermissionState> permissionState() async =>
      NotificationPermissionState.granted;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(ReminderView reminder) async {
    scheduled.add(reminder.notificationId);
    pending.add(reminder.notificationId);
  }
}

final class _FixedRandom implements CryptographicRandom {
  const _FixedRandom();

  @override
  Future<Uint8List> secureBytes(int length) async =>
      Uint8List.fromList(List<int>.generate(length, (index) => index + 10));
}
