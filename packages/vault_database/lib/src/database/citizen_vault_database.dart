import 'package:drift/drift.dart';
import 'package:vault_database/src/errors/database_failure.dart';

part 'citizen_vault_database.g.dart';

/// Current type-safe Citizen Vault schema.
@DriftDatabase(include: <String>{'../schema/vault_schema.drift'})
final class CitizenVaultDatabase extends _$CitizenVaultDatabase {
  /// Creates a database over an already configured encrypted executor.
  CitizenVaultDatabase(super.e);

  /// Current schema version.
  @override
  int get schemaVersion => 7;

  /// Incremental, non-destructive migration policy.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'INSERT INTO schema_versions(version, applied_at, schema_sha256) '
        'VALUES (?, ?, ?)',
        <Object>[
          schemaVersion,
          DateTime.now().toUtc().millisecondsSinceEpoch,
          schemaV7Sha256,
        ],
      );
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from >= to || to != schemaVersion) {
        throw DatabaseMigrationFailure(
          cause: StateError('Unsupported migration path $from -> $to'),
        );
      }
      try {
        if (from < 2) await _migrateVersionOneToTwo(migrator);
        if (from < 3) await _migrateVersionTwoToThree(migrator);
        if (from < 4) await _migrateVersionThreeToFour(migrator);
        if (from < 5) await _migrateVersionFourToFive(migrator);
        if (from < 6) await _migrateVersionFiveToSix(migrator);
        if (from < 7) await _migrateVersionSixToSeven(migrator);
      } on DatabaseMigrationFailure {
        rethrow;
      } on Object catch (error) {
        throw DatabaseMigrationFailure(cause: error);
      }
    },
    beforeOpen: (details) async {
      final foreignKeys = await customSelect(
        'PRAGMA foreign_keys;',
      ).getSingle();
      if (foreignKeys.data.values.single != 1) {
        throw const DatabaseOpenFailure();
      }
      // FTS is derived, disposable state. Rebuilding on open upgrades search
      // coverage without adding authoritative rows that alter backup fixtures.
      await rebuildFtsIndex();
    },
  );

  Future<void> _migrateVersionOneToTwo(Migrator migrator) async {
    await migrator.addColumn(
      objectReferences,
      objectReferences.objectFormatVersion,
    );
    await migrator.addColumn(objectReferences, objectReferences.keyVersion);
    await migrator.addColumn(objectReferences, objectReferences.chunkCount);
    await migrator.addColumn(
      objectReferences,
      objectReferences.verificationStatus,
    );
    await migrator.addColumn(
      objectReferences,
      objectReferences.lastVerifiedAt,
    );
    await _recordSchemaVersion(2, schemaV2Sha256);
  }

  Future<void> _migrateVersionTwoToThree(Migrator migrator) async {
    await migrator.addColumn(
      backupGenerations,
      backupGenerations.archivePathToken,
    );
    await migrator.addColumn(
      backupGenerationObjects,
      backupGenerationObjects.requiredUntil,
    );
    await migrator.addColumn(
      backupGenerationObjects,
      backupGenerationObjects.status,
    );
    await _recordSchemaVersion(3, schemaV3Sha256);
  }

  Future<void> _migrateVersionThreeToFour(Migrator migrator) async {
    await migrator.createTable(entities);
    await migrator.createTable(entityAttributes);
    await migrator.createTable(provenanceRecords);
    await migrator.createTable(relationships);
    await migrator.createTable(relationshipHistory);
    await migrator.createTable(claims);
    await migrator.createTable(claimValues);
    await migrator.createTable(claimHistory);
    await migrator.createTable(evidenceLinks);
    await migrator.createTable(graphAuditEvents);
    await customStatement(
      'CREATE INDEX entities_type_status ON entities(entity_type, status)',
    );
    await customStatement(
      'CREATE INDEX entities_name ON entities(display_name COLLATE NOCASE)',
    );
    await customStatement(
      'CREATE INDEX entity_attributes_lookup '
      'ON entity_attributes(attribute_key, value_type)',
    );
    await customStatement(
      'CREATE INDEX provenance_document '
      'ON provenance_records(source_document_id)',
    );
    await customStatement(
      'CREATE INDEX relationships_from '
      'ON relationships(from_entity_id, status)',
    );
    await customStatement(
      'CREATE INDEX relationships_to ON relationships(to_entity_id, status)',
    );
    await customStatement(
      'CREATE INDEX relationships_type '
      'ON relationships(relationship_type, status)',
    );
    await customStatement(
      'CREATE INDEX relationship_history_relationship '
      'ON relationship_history(relationship_id, created_at)',
    );
    await customStatement(
      'CREATE INDEX claims_subject_status '
      'ON claims(subject_entity_id, status)',
    );
    await customStatement(
      'CREATE INDEX claims_predicate_status '
      'ON claims(predicate, status)',
    );
    await customStatement(
      'CREATE INDEX claim_history_claim ON claim_history(claim_id, created_at)',
    );
    await customStatement(
      'CREATE INDEX evidence_links_document '
      'ON evidence_links(document_id)',
    );
    await customStatement(
      'CREATE INDEX evidence_links_claim ON evidence_links(claim_id)',
    );
    await customStatement(
      'CREATE INDEX evidence_links_relationship '
      'ON evidence_links(relationship_id)',
    );
    await customStatement(
      'CREATE INDEX graph_audit_events_created '
      'ON graph_audit_events(created_at)',
    );
    await _recordSchemaVersion(4, schemaV4Sha256);
  }

  Future<void> _migrateVersionFourToFive(Migrator migrator) async {
    await migrator.createTable(lifeEvents);
    await migrator.createTable(eventEntities);
    await migrator.createTable(eventEvidenceLinks);
    await migrator.createTable(eventHistory);
    await customStatement(
      'CREATE INDEX life_events_date_status '
      'ON life_events(start_at, status)',
    );
    await customStatement(
      'CREATE INDEX life_events_type_status '
      'ON life_events(event_type, status)',
    );
    await customStatement(
      'CREATE INDEX life_events_location ON life_events(location_entity_id)',
    );
    await customStatement(
      'CREATE INDEX event_entities_event ON event_entities(event_id)',
    );
    await customStatement(
      'CREATE INDEX event_entities_entity '
      'ON event_entities(entity_id, event_id)',
    );
    await customStatement(
      'CREATE INDEX event_evidence_event '
      'ON event_evidence_links(event_id)',
    );
    await customStatement(
      'CREATE INDEX event_evidence_document '
      'ON event_evidence_links(document_id)',
    );
    await customStatement(
      'CREATE INDEX event_history_event '
      'ON event_history(event_id, created_at)',
    );
    await _recordSchemaVersion(5, schemaV5Sha256);
  }

  Future<void> _migrateVersionFiveToSix(Migrator migrator) async {
    await migrator.createTable(derivedStates);
    await migrator.createTable(stateInputs);
    await migrator.createTable(attentionItems);
    await migrator.createTable(lifeTasks);
    await migrator.createTable(lifeChecklists);
    await migrator.createTable(lifeChecklistItems);
    await customStatement(
      'CREATE INDEX derived_states_subject '
      'ON derived_states(subject_entity_id)',
    );
    await customStatement(
      'CREATE INDEX derived_states_kind '
      'ON derived_states(state_kind, calculated_at)',
    );
    await customStatement(
      'CREATE INDEX state_inputs_state ON state_inputs(state_id)',
    );
    await customStatement(
      'CREATE INDEX attention_items_active '
      'ON attention_items(status, priority, due_at)',
    );
    await customStatement(
      'CREATE INDEX attention_items_entity '
      'ON attention_items(entity_id, status)',
    );
    await customStatement(
      'CREATE INDEX life_tasks_status_due '
      'ON life_tasks(status, due_at)',
    );
    await customStatement(
      'CREATE INDEX life_tasks_attention '
      'ON life_tasks(source_attention_id)',
    );
    await customStatement(
      'CREATE INDEX life_checklist_items_checklist '
      'ON life_checklist_items(checklist_id, position)',
    );
    await _recordSchemaVersion(6, schemaV6Sha256);
  }

  Future<void> _migrateVersionSixToSeven(Migrator migrator) async {
    await migrator.createTable(smartPacks);
    await migrator.createTable(smartPackItems);
    await customStatement(
      'CREATE INDEX smart_packs_active '
      'ON smart_packs(is_archived, updated_at)',
    );
    await customStatement(
      'CREATE INDEX smart_packs_entity '
      'ON smart_packs(entity_id, is_archived)',
    );
    await customStatement(
      'CREATE INDEX smart_pack_items_pack '
      'ON smart_pack_items(pack_id, is_enabled, position)',
    );
    await customStatement(
      'CREATE INDEX smart_pack_items_document '
      'ON smart_pack_items(linked_document_id)',
    );
    await _recordSchemaVersion(7, schemaV7Sha256);
  }

  Future<void> _recordSchemaVersion(int version, String digest) async {
    await customStatement(
      'UPDATE vault_metadata SET database_schema_version = ?',
      <Object>[version],
    );
    await customStatement(
      'INSERT INTO schema_versions(version, applied_at, schema_sha256) '
      'VALUES (?, ?, ?)',
      <Object>[
        version,
        DateTime.now().toUtc().millisecondsSinceEpoch,
        digest,
      ],
    );
  }

  /// SHA-256 of the reviewed version-three schema source.
  static const String schemaV3Sha256 =
      '6c4537216694943f1a3c5f136e0053b4fcd79bdd73f8c0a7f3aa36a8f421f7fd';

  /// SHA-256 of the reviewed version-four Life Graph schema source.
  static const String schemaV4Sha256 =
      'f80a47da285d22f49d3b81e7db6a20658f68e3f66c5d3253fa497c255a832b53';

  /// SHA-256 of the reviewed version-five temporal Event schema source.
  static const String schemaV5Sha256 =
      '5c8101d2936f47dfa7aac4a0693e28336cb2d6c72714a188b13bcd9efc2b0605';

  /// SHA-256 of the reviewed version-six State and Attention schema.
  static const String schemaV6Sha256 =
      '0061d6dccc4d8a70dbe3e6139cb98f3b3202f632e784b045ffbc4b75527f4dd0';

  /// SHA-256 of the reviewed version-seven Smart Pack schema.
  static const String schemaV7Sha256 =
      '486400de1af54d17dd909446de50a5f7e51907328ba014c4cc1c3392d8db971a';

  /// SHA-256 of the reviewed version-two schema source.
  static const String schemaV2Sha256 =
      '5cf5a4a238c2226c265ea7627c7ab0d49ad1cf444cb8c6db60434ff792c4b442';

  /// SHA-256 of the committed version-one schema source.
  static const String schemaV1Sha256 =
      'f13b1c5e7d4210afa9cabb140d7676f65571e682e675343c2a29df52d088a5d5';

  /// Rebuilds all derived FTS rows from authoritative tables.
  Future<void> rebuildFtsIndex() async {
    await transaction(() async {
      await customStatement('DELETE FROM document_fts;');
      await customStatement(
        '$_ftsInsertSql WHERE d.deleted_at IS NULL',
      );
    });
  }

  /// Rebuilds one document's derived FTS row.
  Future<void> indexDocument(String documentId) async {
    await transaction(() async {
      await customStatement(
        'DELETE FROM document_fts WHERE document_id = ?',
        <Object>[documentId],
      );
      await customStatement(
        '$_ftsInsertSql WHERE d.id = ? AND d.deleted_at IS NULL',
        <Object>[documentId],
      );
    });
  }

  /// Verifies that every active document has exactly one derived FTS row.
  Future<bool> verifyFtsIndex() async {
    final row = await customSelect('''
      SELECT
        (SELECT count(*) FROM documents WHERE deleted_at IS NULL) AS documents,
        (SELECT count(*) FROM document_fts) AS indexed,
        (SELECT count(*) FROM (
          SELECT document_id FROM document_fts
          GROUP BY document_id HAVING count(*) != 1
        )) AS duplicates,
        (SELECT count(*) FROM documents d
          WHERE d.deleted_at IS NULL AND NOT EXISTS (
            SELECT 1 FROM document_fts f WHERE f.document_id = d.id
          )) AS missing
    ''').getSingle();
    return row.read<int>('documents') == row.read<int>('indexed') &&
        row.read<int>('duplicates') == 0 &&
        row.read<int>('missing') == 0;
  }

  static const String _ftsInsertSql = '''
    INSERT INTO document_fts(
      document_id, logical_filename, ocr_text, document_type,
      issuer, document_number, tags
    )
    SELECT
      d.id,
      d.logical_filename,
      COALESCE((
        SELECT group_concat(COALESCE(t.normalized_text, t.raw_text), ' ')
        FROM document_text t WHERE t.document_id = d.id
      ), '') || ' ' || COALESCE((
        SELECT group_concat(
          f.field_type || ' ' ||
          COALESCE(f.normalized_value, f.raw_value),
          ' '
        )
        FROM extracted_fields f WHERE f.document_id = d.id
      ), ''),
      COALESCE(
        d.document_type,
        (
          SELECT c.document_type FROM document_classifications c
          WHERE c.document_id = d.id
          ORDER BY c.confirmed_by_user DESC, c.updated_at DESC LIMIT 1
        ),
        ''
      ),
      COALESCE((
        SELECT COALESCE(f.normalized_value, f.raw_value)
        FROM extracted_fields f
        WHERE f.document_id = d.id AND f.field_type = 'ISSUER'
        ORDER BY f.confirmed_by_user DESC, f.updated_at DESC LIMIT 1
      ), ''),
      COALESCE((
        SELECT COALESCE(f.normalized_value, f.raw_value)
        FROM extracted_fields f
        WHERE f.document_id = d.id AND f.field_type = 'DOCUMENT_NUMBER'
        ORDER BY f.confirmed_by_user DESC, f.updated_at DESC LIMIT 1
      ), ''),
      COALESCE((
        SELECT group_concat(tag.name, ' ')
        FROM document_tag_links link
        JOIN document_tags tag ON tag.id = link.tag_id
        WHERE link.document_id = d.id
      ), '')
    FROM documents d
  ''';
}
