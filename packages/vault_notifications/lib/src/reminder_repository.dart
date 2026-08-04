// Named public dependencies intentionally initialize private owned fields.
// Boolean values map directly to encrypted integer columns.
// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: prefer_if_elements_to_conditional_expressions
// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_domain/vault_domain.dart';

/// SQLCipher source of truth for reminders.
final class ReminderRepository {
  /// Creates the repository for one unlocked vault.
  const ReminderRepository({
    required VaultDatabaseSession session,
    required CryptographicRandom random,
  }) : _session = session,
       _random = random;

  final VaultDatabaseSession _session;
  final CryptographicRandom _random;

  /// Lists active reminders, optionally scoped to one document.
  Future<List<ReminderView>> list({String? documentId}) =>
      _session.read((database) async {
        final where = documentId == null
            ? 'r.completed_at IS NULL'
            : 'r.completed_at IS NULL AND r.document_id = ?';
        final rows = await database.customSelect(
          '''
              SELECT r.id, r.document_id, d.logical_filename, r.reminder_type,
                     r.title, r.due_at, r.is_enabled, r.notification_id,
                     r.completed_at
              FROM reminders r
              JOIN documents d ON d.id = r.document_id
              WHERE $where AND d.deleted_at IS NULL
              ORDER BY r.due_at, r.id
              ''',
          variables: documentId == null
              ? const <Variable<Object>>[]
              : <Variable<Object>>[Variable<String>(documentId)],
        ).get();
        return rows.map(_map).toList(growable: false);
      });

  /// Creates a reminder with collision-resistant internal and OS identifiers.
  Future<ReminderView> create(
    ReminderDraft draft, {
    required bool enabled,
  }) async {
    final title = draft.title.trim();
    if (title.isEmpty || title.length > 120) {
      throw ArgumentError.value(draft.title, 'title');
    }
    final duplicate = await _session.read(
      (database) => database
          .customSelect(
            '''
            SELECT id FROM reminders
            WHERE document_id = ? AND reminder_type = ? AND due_at = ?
              AND completed_at IS NULL
            LIMIT 1
            ''',
            variables: <Variable<Object>>[
              Variable<String>(draft.documentId),
              Variable<String>(draft.type.storageValue),
              Variable<int>(draft.dueAt.toUtc().millisecondsSinceEpoch),
            ],
          )
          .getSingleOrNull(),
    );
    if (duplicate != null) {
      final id = duplicate.read<String>('id');
      return (await list(documentId: draft.documentId)).singleWhere(
        (reminder) => reminder.id == id,
      );
    }
    final bytes = await _random.secureBytes(16);
    final id = _hex(bytes);
    final notificationId =
        ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
        0x7fffffff;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _session.write(
      (database) => database.customStatement(
        '''
        INSERT INTO reminders(
          id, document_id, reminder_type, title, due_at, is_enabled,
          notification_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        <Object>[
          id,
          draft.documentId,
          draft.type.storageValue,
          title,
          draft.dueAt.toUtc().millisecondsSinceEpoch,
          enabled ? 1 : 0,
          notificationId,
          now,
          now,
        ],
      ),
    );
    return (await list(documentId: draft.documentId)).singleWhere(
      (reminder) => reminder.id == id,
    );
  }

  /// Changes whether a reminder is projected to the OS.
  Future<void> setEnabled(String reminderId, bool enabled) => _session.write(
    (database) => database.customStatement(
      '''
      UPDATE reminders SET is_enabled = ?, updated_at = ?
      WHERE id = ? AND completed_at IS NULL
      ''',
      <Object>[
        enabled ? 1 : 0,
        DateTime.now().toUtc().millisecondsSinceEpoch,
        reminderId,
      ],
    ),
  );

  /// Reschedules a reminder to an explicit UTC instant.
  Future<void> reschedule(String reminderId, DateTime dueAt) => _session.write(
    (database) => database.customStatement(
      '''
      UPDATE reminders SET due_at = ?, is_enabled = 1, updated_at = ?
      WHERE id = ? AND completed_at IS NULL
      ''',
      <Object>[
        dueAt.toUtc().millisecondsSinceEpoch,
        DateTime.now().toUtc().millisecondsSinceEpoch,
        reminderId,
      ],
    ),
  );

  /// Marks a reminder complete and disables its projection.
  Future<void> complete(String reminderId) => _session.write((database) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await database.customStatement(
      '''
      UPDATE reminders SET completed_at = ?, is_enabled = 0, updated_at = ?
      WHERE id = ? AND completed_at IS NULL
      ''',
      <Object>[now, now, reminderId],
    );
  });

  /// Deletes a reminder from the authoritative store.
  Future<void> delete(String reminderId) => _session.write(
    (database) => database.customStatement(
      'DELETE FROM reminders WHERE id = ?',
      <Object>[reminderId],
    ),
  );

  static ReminderView _map(QueryRow row) => ReminderView(
    id: row.read<String>('id'),
    documentId: row.read<String>('document_id'),
    documentFilename: row.read<String>('logical_filename'),
    type: ReminderType.fromStorage(row.read<String>('reminder_type')),
    title: row.read<String>('title'),
    dueAt: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('due_at'),
      isUtc: true,
    ),
    isEnabled: row.read<int>('is_enabled') == 1,
    notificationId: row.read<int>('notification_id'),
    completedAt: switch (row.readNullable<int>('completed_at')) {
      final value? => DateTime.fromMillisecondsSinceEpoch(value, isUtc: true),
      null => null,
    },
  );

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
