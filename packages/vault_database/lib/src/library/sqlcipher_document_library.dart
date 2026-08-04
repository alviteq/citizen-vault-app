// Named public dependencies intentionally initialize private owned fields.
// Boolean values map directly to encrypted integer columns.
// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: prefer_if_elements_to_conditional_expressions
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/src/database/encrypted_database_opener.dart';
import 'package:vault_domain/vault_domain.dart';

/// SQLCipher-backed document browsing, metadata, tag, and preference access.
final class SqlCipherDocumentLibrary {
  /// Creates a library for one unlocked vault.
  const SqlCipherDocumentLibrary({
    required VaultDatabaseSession session,
    required CryptographicRandom random,
  }) : _session = session,
       _random = random;

  final VaultDatabaseSession _session;
  final CryptographicRandom _random;

  /// Lists active documents using bounded local filters and FTS.
  Future<List<DocumentListItemView>> listDocuments(
    DocumentLibraryFilter filter,
  ) => _session.read((database) async {
    final query = filter.query.trim();
    if (query.length > 200) throw ArgumentError.value(query, 'query');
    final where = <String>[
      filter.deletedOnly ? 'd.deleted_at IS NOT NULL' : 'd.deleted_at IS NULL',
    ];
    final variables = <Variable<Object>>[];
    if (filter.deletedOnly) {
      // Trash includes active and archived records.
    } else if (filter.archivedOnly) {
      where.add('d.is_archived = 1');
    } else {
      where.add('d.is_archived = 0');
    }
    if (filter.favouritesOnly) where.add('d.is_favourite = 1');
    if (filter.type case final type?) {
      where.add("COALESCE(d.document_type, 'UNKNOWN') = ?");
      variables.add(Variable<String>(type.storageValue));
    }
    if (filter.tagId case final tagId?) {
      where.add(
        'EXISTS (SELECT 1 FROM document_tag_links filter_link '
        'WHERE filter_link.document_id = d.id AND filter_link.tag_id = ?)',
      );
      variables.add(Variable<String>(tagId));
    }
    if (query.isNotEmpty) {
      where.add(
        'd.id IN (SELECT document_id FROM document_fts '
        'WHERE document_fts MATCH ?)',
      );
      variables.add(Variable<String>(_ftsQuery(query)));
    }
    final orderBy = switch (filter.sort) {
      DocumentSort.newest => 'd.imported_at DESC',
      DocumentSort.oldest => 'd.imported_at ASC',
      DocumentSort.name => 'd.logical_filename COLLATE NOCASE ASC',
      DocumentSort.type =>
        "COALESCE(d.document_type, 'UNKNOWN') ASC, d.imported_at DESC",
      DocumentSort.upcomingReminder =>
        'next_reminder_at IS NULL, next_reminder_at ASC, d.imported_at DESC',
    };
    final rows = await database.customSelect(
      '''
          SELECT d.id, d.logical_filename, d.document_type, d.mime_type,
                 d.status, d.integrity_status, d.imported_at,
                 d.is_favourite, d.is_archived, d.deleted_at,
            (SELECT min(r.due_at) FROM reminders r
              WHERE r.document_id = d.id AND r.is_enabled = 1
                AND r.completed_at IS NULL) AS next_reminder_at,
            (SELECT f.normalized_value FROM extracted_fields f
              WHERE f.document_id = d.id AND f.field_type = 'EXPIRY_DATE'
              ORDER BY f.confirmed_by_user DESC, f.updated_at DESC
              LIMIT 1) AS expiry_value,
            COALESCE((SELECT group_concat(
              tag.id || char(31) || tag.name, char(30))
              FROM document_tag_links link
              JOIN document_tags tag ON tag.id = link.tag_id
              WHERE link.document_id = d.id), '') AS tag_values
          FROM documents d
          WHERE ${where.join(' AND ')}
          ORDER BY $orderBy
          LIMIT 500
          ''',
      variables: variables,
    ).get();
    return rows.map(_mapSummary).toList(growable: false);
  });

  /// Loads all reviewable metadata for one active document.
  Future<DocumentDetailView?> document(String documentId) =>
      _session.read((database) async {
        final summaryRow = await database
            .customSelect(
              '''
              SELECT d.id, d.logical_filename, d.document_type, d.mime_type,
                     d.status, d.integrity_status, d.imported_at,
                     d.is_favourite, d.is_archived, d.deleted_at,
                (SELECT min(r.due_at) FROM reminders r
                  WHERE r.document_id = d.id AND r.is_enabled = 1
                    AND r.completed_at IS NULL) AS next_reminder_at,
                (SELECT f.normalized_value FROM extracted_fields f
                  WHERE f.document_id = d.id AND f.field_type = 'EXPIRY_DATE'
                  ORDER BY f.confirmed_by_user DESC, f.updated_at DESC
                  LIMIT 1) AS expiry_value,
                COALESCE((SELECT group_concat(
                  tag.id || char(31) || tag.name, char(30))
                  FROM document_tag_links link
                  JOIN document_tags tag ON tag.id = link.tag_id
                  WHERE link.document_id = d.id), '') AS tag_values
              FROM documents d WHERE d.id = ? AND d.deleted_at IS NULL
              ''',
              variables: <Variable<Object>>[
                Variable<String>(documentId),
              ],
            )
            .getSingleOrNull();
        if (summaryRow == null) return null;
        final fields = await database
            .customSelect(
              '''
              SELECT id, field_type, raw_value, normalized_value, confidence,
                     source_page, source_block_id, extractor_id,
                     extractor_version, confirmed_by_user
              FROM extracted_fields WHERE document_id = ?
              ORDER BY field_type, id
              ''',
              variables: <Variable<Object>>[
                Variable<String>(documentId),
              ],
            )
            .get();
        final text = await database
            .customSelect(
              '''
              SELECT page_number, raw_text FROM document_text
              WHERE document_id = ? ORDER BY page_number, id
              ''',
              variables: <Variable<Object>>[
                Variable<String>(documentId),
              ],
            )
            .get();
        final assets = await database
            .customSelect(
              '''
              SELECT asset_type, mime_type, created_at FROM document_assets
              WHERE document_id = ? AND deleted_at IS NULL
              ORDER BY created_at
              ''',
              variables: <Variable<Object>>[
                Variable<String>(documentId),
              ],
            )
            .get();
        final history = await database
            .customSelect(
              '''
              SELECT s.step_name, s.status, s.attempt_count, s.completed_at,
                     s.error_code
              FROM processing_job_steps s
              JOIN processing_jobs j ON j.id = s.job_id
              WHERE j.document_id = ?
              ORDER BY j.created_at, s.rowid
              ''',
              variables: <Variable<Object>>[
                Variable<String>(documentId),
              ],
            )
            .get();
        return DocumentDetailView(
          summary: _mapSummary(summaryRow),
          fields: fields
              .map(_mapField)
              .whereType<ExtractedFieldView>()
              .toList(
                growable: false,
              ),
          textPages: text
              .map(
                (row) => DocumentTextPageView(
                  pageNumber: row.readNullable<int>('page_number'),
                  text: row.read<String>('raw_text'),
                ),
              )
              .toList(growable: false),
          assets: assets
              .map(
                (row) => DocumentAssetView(
                  assetType: row.read<String>('asset_type'),
                  mimeType: row.read<String>('mime_type'),
                  createdAt: _date(row.read<int>('created_at')),
                ),
              )
              .toList(growable: false),
          processingHistory: history
              .map(
                (row) => ProcessingHistoryView(
                  stepName: row.read<String>('step_name'),
                  status: row.read<String>('status'),
                  attemptCount: row.read<int>('attempt_count'),
                  completedAt: _optionalDate(
                    row.readNullable<int>('completed_at'),
                  ),
                  errorCode: row.readNullable<String>('error_code'),
                ),
              )
              .toList(growable: false),
        );
      });

  /// Lists all tags in case-insensitive name order.
  Future<List<DocumentTagView>> listTags() => _session.read(
    (database) => database
        .customSelect(
          'SELECT id, name FROM document_tags ORDER BY name COLLATE NOCASE',
        )
        .get()
        .then(
          (rows) => rows
              .map(
                (row) => DocumentTagView(
                  id: row.read<String>('id'),
                  name: row.read<String>('name'),
                ),
              )
              .toList(growable: false),
        ),
  );

  /// Renames a tag, merging it into an existing normalized tag when needed.
  Future<void> renameTag(String tagId, String name) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty || clean.length > 40) {
      throw ArgumentError.value(name, 'name');
    }
    return _session.write(
      (database) => database.transaction(() async {
        final affected = await database
            .customSelect(
              'SELECT document_id FROM document_tag_links WHERE tag_id = ?',
              variables: [Variable<String>(tagId)],
            )
            .get();
        final existing = await database
            .customSelect(
              'SELECT id FROM document_tags WHERE normalized_name = ? '
              'AND id != ?',
              variables: [
                Variable<String>(clean.toLowerCase()),
                Variable<String>(tagId),
              ],
            )
            .getSingleOrNull();
        if (existing == null) {
          await database.customStatement(
            'UPDATE document_tags SET name = ?, normalized_name = ?, '
            'updated_at = ? WHERE id = ?',
            <Object>[
              clean,
              clean.toLowerCase(),
              DateTime.now().toUtc().millisecondsSinceEpoch,
              tagId,
            ],
          );
        } else {
          final targetId = existing.read<String>('id');
          await database.customStatement(
            'INSERT OR IGNORE INTO document_tag_links '
            '(document_id, tag_id, created_at) '
            'SELECT document_id, ?, created_at FROM document_tag_links '
            'WHERE tag_id = ?',
            <Object>[targetId, tagId],
          );
          await database.customStatement(
            'DELETE FROM document_tags WHERE id = ?',
            <Object>[tagId],
          );
        }
        for (final row in affected) {
          await database.indexDocument(row.read<String>('document_id'));
        }
      }),
    );
  }

  /// Deletes a tag and its links without deleting any document.
  Future<void> deleteTag(String tagId) => _session.write(
    (database) => database.transaction(() async {
      final affected = await database
          .customSelect(
            'SELECT document_id FROM document_tag_links WHERE tag_id = ?',
            variables: [Variable<String>(tagId)],
          )
          .get();
      await database.customStatement(
        'DELETE FROM document_tags WHERE id = ?',
        <Object>[tagId],
      );
      for (final row in affected) {
        await database.indexDocument(row.read<String>('document_id'));
      }
    }),
  );

  /// Replaces a document's tags, creating normalized tags when necessary.
  Future<void> replaceTags(String documentId, List<String> names) async {
    final normalized = <String, String>{};
    for (final raw in names) {
      final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (name.isEmpty) continue;
      if (name.length > 40 ||
          normalized.length >= 20 ||
          name.contains(String.fromCharCode(30)) ||
          name.contains(String.fromCharCode(31))) {
        throw ArgumentError.value(names, 'names');
      }
      normalized[name.toLowerCase()] = name;
    }
    final ids = <String, String>{};
    for (final name in normalized.keys) {
      ids[name] = _hex(await _random.secureBytes(16));
    }
    await _session.write(
      (database) => database.transaction(() async {
        final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
        await database.customStatement(
          'DELETE FROM document_tag_links WHERE document_id = ?',
          <Object>[documentId],
        );
        for (final entry in normalized.entries) {
          await database.customStatement(
            '''
            INSERT OR IGNORE INTO document_tags(
              id, name, normalized_name, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?)
            ''',
            <Object>[
              ids[entry.key]!,
              entry.value,
              entry.key,
              timestamp,
              timestamp,
            ],
          );
          await database.customStatement(
            '''
            INSERT INTO document_tag_links(document_id, tag_id, created_at)
            SELECT ?, id, ? FROM document_tags WHERE normalized_name = ?
            ''',
            <Object>[documentId, timestamp, entry.key],
          );
        }
        await database.indexDocument(documentId);
      }),
    );
  }

  /// Updates a document's favourite state.
  Future<void> setFavourite(String documentId, bool value) =>
      _setBoolean(documentId, 'is_favourite', value);

  /// Updates a document's archive state.
  Future<void> setArchived(String documentId, bool value) =>
      _setBoolean(documentId, 'is_archived', value);

  /// Updates a user-corrected document type and refreshes encrypted search.
  Future<void> setDocumentType(String documentId, DocumentType type) =>
      _session.write(
        (database) => database.transaction(() async {
          await database.customStatement(
            'UPDATE documents SET document_type = ?, updated_at = ? '
            'WHERE id = ? AND deleted_at IS NULL',
            <Object>[
              type.storageValue,
              DateTime.now().toUtc().millisecondsSinceEpoch,
              documentId,
            ],
          );
          await database.indexDocument(documentId);
        }),
      );

  /// Changes the display filename without replacing the encrypted original.
  Future<void> rename(String documentId, String logicalFilename) {
    final name = logicalFilename.trim();
    if (name.isEmpty ||
        name.length > 240 ||
        name.contains('/') ||
        name.contains(r'\')) {
      throw ArgumentError.value(logicalFilename, 'logicalFilename');
    }
    return _session.write(
      (database) => database.transaction(() async {
        await database.customStatement(
          'UPDATE documents SET logical_filename = ?, updated_at = ? '
          'WHERE id = ? AND deleted_at IS NULL',
          <Object>[
            name,
            DateTime.now().toUtc().millisecondsSinceEpoch,
            documentId,
          ],
        );
        await database.indexDocument(documentId);
      }),
    );
  }

  /// Moves a record to recoverable encrypted trash.
  Future<void> moveToTrash(String documentId) => _session.write(
    (database) => database.transaction(() async {
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      await database.customStatement(
        'UPDATE documents SET deleted_at = ?, updated_at = ? '
        'WHERE id = ? AND deleted_at IS NULL',
        <Object>[timestamp, timestamp, documentId],
      );
      await database.indexDocument(documentId);
    }),
  );

  /// Restores one record from encrypted trash.
  Future<void> restoreFromTrash(String documentId) => _session.write(
    (database) => database.transaction(() async {
      await database.customStatement(
        'UPDATE documents SET deleted_at = NULL, updated_at = ? '
        'WHERE id = ? AND deleted_at IS NOT NULL',
        <Object>[
          DateTime.now().toUtc().millisecondsSinceEpoch,
          documentId,
        ],
      );
      await database.indexDocument(documentId);
    }),
  );

  /// Reads encrypted local presentation and reminder defaults.
  Future<VaultPreferencesView> preferences() => _session.read((database) async {
    final row = await database
        .customSelect(
          'SELECT setting_value FROM app_settings '
          "WHERE setting_key = 'preferences-v1'",
        )
        .getSingleOrNull();
    if (row == null) return const VaultPreferencesView.defaults();
    try {
      final value = jsonDecode(row.read<String>('setting_value'));
      if (value is! Map<String, Object?>) {
        return const VaultPreferencesView.defaults();
      }
      final offsets = (value['defaultReminderOffsets'] as List<Object?>?)
          ?.whereType<int>()
          .where((days) => days >= 0 && days <= 3650)
          .toSet()
          .toList(growable: false);
      return VaultPreferencesView(
        useGrid: value['useGrid'] == true,
        darkMode: value['darkMode'] == true,
        defaultReminderOffsets: offsets == null || offsets.isEmpty
            ? const <int>[30, 7, 1]
            : offsets,
        lastBackupAt: value['lastBackupAt'] is String
            ? DateTime.tryParse(value['lastBackupAt']! as String)
            : null,
        lastBackupObjectCount: value['lastBackupObjectCount'] is int
            ? value['lastBackupObjectCount']! as int
            : null,
      );
    } on Object {
      return const VaultPreferencesView.defaults();
    }
  });

  /// Persists encrypted local presentation and reminder defaults.
  Future<void> savePreferences(VaultPreferencesView preferences) {
    if (preferences.defaultReminderOffsets.isEmpty ||
        preferences.defaultReminderOffsets.any(
          (days) => days < 0 || days > 3650,
        )) {
      throw ArgumentError.value(preferences.defaultReminderOffsets);
    }
    return _session.write(
      (database) => database.customStatement(
        '''
        INSERT INTO app_settings(setting_key, setting_value, updated_at)
        VALUES ('preferences-v1', ?, ?)
        ON CONFLICT(setting_key) DO UPDATE SET
          setting_value = excluded.setting_value,
          updated_at = excluded.updated_at
        ''',
        <Object>[
          jsonEncode(<String, Object>{
            'useGrid': preferences.useGrid,
            'darkMode': preferences.darkMode,
            'defaultReminderOffsets': preferences.defaultReminderOffsets,
            if (preferences.lastBackupAt != null)
              'lastBackupAt': preferences.lastBackupAt!
                  .toUtc()
                  .toIso8601String(),
            if (preferences.lastBackupObjectCount != null)
              'lastBackupObjectCount': preferences.lastBackupObjectCount!,
          }),
          DateTime.now().toUtc().millisecondsSinceEpoch,
        ],
      ),
    );
  }

  Future<void> _setBoolean(
    String documentId,
    String column,
    bool value,
  ) => _session.write(
    (database) => database.customStatement(
      'UPDATE documents SET $column = ?, updated_at = ? '
      'WHERE id = ? AND deleted_at IS NULL',
      <Object>[
        value ? 1 : 0,
        DateTime.now().toUtc().millisecondsSinceEpoch,
        documentId,
      ],
    ),
  );

  static DocumentListItemView _mapSummary(QueryRow row) => DocumentListItemView(
    id: row.read<String>('id'),
    logicalFilename: row.read<String>('logical_filename'),
    documentType: DocumentType.fromStorage(
      row.readNullable<String>('document_type') ?? 'UNKNOWN',
    ),
    mimeType: row.read<String>('mime_type'),
    status: row.read<String>('status'),
    integrityStatus: row.read<String>('integrity_status'),
    importedAt: _date(row.read<int>('imported_at')),
    isFavourite: row.read<int>('is_favourite') == 1,
    isArchived: row.read<int>('is_archived') == 1,
    isDeleted: row.readNullable<int>('deleted_at') != null,
    tags: _decodeTags(row.read<String>('tag_values')),
    nextReminderAt: _optionalDate(
      row.readNullable<int>('next_reminder_at'),
    ),
    expiryAt: DateTime.tryParse(
      row.readNullable<String>('expiry_value') ?? '',
    )?.toUtc(),
  );

  static ExtractedFieldView? _mapField(QueryRow row) {
    final type = ExtractedFieldType.tryFromStorage(
      row.read<String>('field_type'),
    );
    if (type == null) return null;
    return ExtractedFieldView(
      id: row.read<String>('id'),
      type: type,
      rawValue: row.readNullable<String>('raw_value'),
      normalizedValue: row.readNullable<String>('normalized_value'),
      confidence: row.readNullable<double>('confidence'),
      sourcePage: row.readNullable<int>('source_page'),
      sourceBlockId: row.readNullable<String>('source_block_id'),
      extractorId: row.read<String>('extractor_id'),
      extractorVersion: row.read<String>('extractor_version'),
      confirmedByUser: row.read<int>('confirmed_by_user') == 1,
    );
  }

  static List<DocumentTagView> _decodeTags(String encoded) {
    if (encoded.isEmpty) return const <DocumentTagView>[];
    return encoded
        .split(String.fromCharCode(30))
        .map((value) {
          final parts = value.split(String.fromCharCode(31));
          return DocumentTagView(
            id: parts.first,
            name: parts.length > 1 ? parts.sublist(1).join() : '',
          );
        })
        .toList(growable: false);
  }

  static String _ftsQuery(String query) {
    final terms = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    )
        .allMatches(query)
        .map((match) => match.group(0)!.toLowerCase())
        .take(16)
        .toList();
    if (terms.isEmpty) return '""';
    return terms
        .map((term) => '"${term.replaceAll('"', '""')}"*')
        .join(' AND ');
  }

  static DateTime _date(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  static DateTime? _optionalDate(int? milliseconds) =>
      milliseconds == null ? null : _date(milliseconds);

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
