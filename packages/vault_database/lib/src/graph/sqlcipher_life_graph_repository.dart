// The repository keeps its SQL mapping close to the schema for auditability.
// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars
// ignore_for_file: avoid_dynamic_calls, always_use_package_imports
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: prefer_if_elements_to_conditional_expressions
// ignore_for_file: avoid_positional_boolean_parameters
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_domain/vault_domain.dart';

import '../database/encrypted_database_opener.dart';

/// Persistence boundary for the encrypted Life Graph.
///
/// The repository deliberately writes through SQLCipher's database session;
/// callers never receive a raw database handle and all graph mutations are
/// coordinated with snapshot barriers.
final class SqlCipherLifeGraphRepository {
  SqlCipherLifeGraphRepository(this.session, this.random);

  final VaultDatabaseSession session;
  final CryptographicRandom random;

  Future<String> createEntity({
    required LifeEntityType type,
    required String displayName,
    String? subtype,
  }) async {
    final id = await _id();
    final now = _now;
    await session.write((db) async {
      await db.customStatement(
        'INSERT INTO entities(id, entity_type, subtype, display_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [id, type.storageValue, subtype, displayName, now, now],
      );
      await _audit(db, 'ENTITY_CREATED', id, now);
    });
    return id;
  }

  Future<List<LifeEntity>> listEntities({
    Set<LifeEntityType>? types,
    bool includeArchived = false,
  }) => session.read((db) async {
    final clauses = <String>[];
    final variables = <Variable<Object>>[];
    if (!includeArchived) {
      clauses.add('status = ?');
      variables.add(Variable.withString(LifeEntityStatus.active.storageValue));
    }
    if (types != null && types.isNotEmpty) {
      clauses.add(
        'entity_type IN (${List.filled(types.length, '?').join(', ')})',
      );
      variables.addAll(
        types.map((type) => Variable.withString(type.storageValue)),
      );
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await db
        .customSelect(
          'SELECT * FROM entities $where ORDER BY display_name COLLATE NOCASE',
          variables: variables,
        )
        .get();
    return rows.map(_entityFromRow).toList(growable: false);
  });

  Future<LifeEntity?> entity(String entityId) => session.read((db) async {
    final row = await db
        .customSelect(
          'SELECT * FROM entities WHERE id = ?',
          variables: [Variable.withString(entityId)],
        )
        .getSingleOrNull();
    return row == null ? null : _entityFromRow(row);
  });

  /// Lists active entities that use [documentId] as confirmed evidence.
  Future<List<LifeEntity>> entitiesForDocument(String documentId) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              '''
              SELECT DISTINCT entity.*
              FROM entities entity
              JOIN claims claim ON claim.subject_entity_id = entity.id
              JOIN evidence_links evidence ON evidence.claim_id = claim.id
              WHERE evidence.document_id = ?
                AND claim.status = 'CONFIRMED'
                AND entity.status = 'ACTIVE'
              ORDER BY entity.display_name COLLATE NOCASE
              ''',
              variables: [Variable.withString(documentId)],
            )
            .get();
        return rows.map(_entityFromRow).toList(growable: false);
      });

  /// Removes the active user-facing link while retaining its audit evidence.
  Future<void> unlinkDocumentEvidence({
    required String entityId,
    required String documentId,
  }) => session.write((db) async {
    final now = _now;
    await db.customStatement(
      '''
      UPDATE claims SET status = 'REJECTED', rejected_at = ?, updated_at = ?
      WHERE subject_entity_id = ?
        AND predicate = 'SUPPORTING_DOCUMENT'
        AND status = 'CONFIRMED'
        AND id IN (
          SELECT claim_id FROM claim_values WHERE identifier_value = ?
        )
        AND id IN (
          SELECT claim_id FROM evidence_links WHERE document_id = ?
        )
      ''',
      <Object>[now, now, entityId, documentId, documentId],
    );
  });

  Future<void> updateEntity({
    required String entityId,
    required String displayName,
    String? subtype,
  }) async {
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(displayName, 'displayName');
    }
    final now = _now;
    await session.write((db) async {
      await _ensureEntityIn(db, entityId);
      await db.customStatement(
        'UPDATE entities SET display_name = ?, subtype = ?, updated_at = ? WHERE id = ?',
        [displayName.trim(), subtype, now, entityId],
      );
      await _audit(db, 'ENTITY_UPDATED', entityId, now);
    });
  }

  Future<void> setEntityArchived(String entityId, bool archived) async {
    final now = _now;
    await session.write((db) async {
      await _ensureEntityIn(db, entityId);
      await db.customStatement(
        'UPDATE entities SET status = ?, archived_at = ?, updated_at = ? WHERE id = ?',
        [
          archived
              ? LifeEntityStatus.archived.storageValue
              : LifeEntityStatus.active.storageValue,
          archived ? now : null,
          now,
          entityId,
        ],
      );
      await _audit(
        db,
        archived ? 'ENTITY_ARCHIVED' : 'ENTITY_RESTORED',
        entityId,
        now,
      );
    });
  }

  Future<List<LifeEntity>> duplicateCandidates({
    required LifeEntityType type,
    required String displayName,
    String? excludingId,
  }) => session.read((db) async {
    final normalized = displayName.trim().toLowerCase();
    if (normalized.isEmpty) return const <LifeEntity>[];
    final rows = await db
        .customSelect(
          'SELECT * FROM entities WHERE entity_type = ? AND status = ? '
          'AND lower(trim(display_name)) = ? '
          'AND (? IS NULL OR id != ?) ORDER BY created_at',
          variables: [
            Variable.withString(type.storageValue),
            Variable.withString(LifeEntityStatus.active.storageValue),
            Variable.withString(normalized),
            Variable<String>(excludingId),
            Variable<String>(excludingId),
          ],
        )
        .get();
    return rows.map(_entityFromRow).toList(growable: false);
  });

  Future<void> upsertEntityAttribute({
    required String entityId,
    required String key,
    required ClaimValue value,
  }) async {
    if (key.trim().isEmpty) throw ArgumentError.value(key, 'key');
    if (value.type == ClaimValueType.entityReference) {
      await _ensureEntity(value.stringValue);
    }
    final id = await _id();
    final fields = _claimValueFields(value);
    final now = _now;
    await session.write((db) async {
      await _ensureEntityIn(db, entityId);
      await db.customStatement(
        'INSERT INTO entity_attributes(id, entity_id, attribute_key, '
        'value_type, string_value, integer_value, decimal_value, '
        'boolean_value, date_value, datetime_value, money_amount_minor, '
        'money_currency, identifier_value, uri_value, entity_reference_id, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?) ON CONFLICT(entity_id, attribute_key) DO UPDATE SET '
        'value_type = excluded.value_type, string_value = excluded.string_value, '
        'integer_value = excluded.integer_value, '
        'decimal_value = excluded.decimal_value, '
        'boolean_value = excluded.boolean_value, date_value = excluded.date_value, '
        'datetime_value = excluded.datetime_value, '
        'money_amount_minor = excluded.money_amount_minor, '
        'money_currency = excluded.money_currency, '
        'identifier_value = excluded.identifier_value, '
        'uri_value = excluded.uri_value, '
        'entity_reference_id = excluded.entity_reference_id, '
        'updated_at = excluded.updated_at',
        [
          id,
          entityId,
          key.trim(),
          value.type.storageValue,
          ...fields,
          now,
          now,
        ],
      );
      await _audit(
        db,
        'ENTITY_ATTRIBUTE_UPDATED',
        entityId,
        now,
        payloadJson: jsonEncode({'attribute_key': key.trim()}),
      );
    });
  }

  Future<List<LifeEntityAttribute>> entityAttributes(String entityId) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM entity_attributes WHERE entity_id = ? '
              'ORDER BY attribute_key',
              variables: [Variable.withString(entityId)],
            )
            .get();
        return rows.map(_attributeFromRow).toList(growable: false);
      });

  Future<List<LifeEntityHistoryEvent>> entityHistory(
    String entityId,
  ) => session.read((db) async {
    final rows = await db
        .customSelect(
          'SELECT id, event_type, subject_id, payload_json, created_at '
          'FROM graph_audit_events WHERE subject_type = ? AND subject_id = ? '
          'ORDER BY created_at DESC, id DESC',
          variables: [
            Variable.withString('ENTITY'),
            Variable.withString(entityId),
          ],
        )
        .get();
    return rows
        .map(
          (row) => LifeEntityHistoryEvent(
            id: row.read<String>('id'),
            entityId: row.read<String>('subject_id'),
            eventType: row.read<String>('event_type'),
            payloadJson: row.readNullable<String>('payload_json'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('created_at'),
              isUtc: true,
            ),
          ),
        )
        .toList(growable: false);
  });

  /// Archives [duplicateEntityId] under [primaryEntityId] without changing IDs.
  Future<void> mergeEntities({
    required String primaryEntityId,
    required String duplicateEntityId,
  }) async {
    if (primaryEntityId == duplicateEntityId) {
      throw ArgumentError('An entity cannot be merged into itself.');
    }
    final mergeAttributeId = await _id();
    final now = _now;
    await session.write((db) async {
      final primary = await db
          .customSelect(
            'SELECT entity_type, status FROM entities WHERE id = ?',
            variables: [Variable.withString(primaryEntityId)],
          )
          .getSingleOrNull();
      final duplicate = await db
          .customSelect(
            'SELECT entity_type, status FROM entities WHERE id = ?',
            variables: [Variable.withString(duplicateEntityId)],
          )
          .getSingleOrNull();
      if (primary == null || duplicate == null) {
        throw StateError('Both merge entities must exist.');
      }
      if (primary.read<String>('entity_type') !=
          duplicate.read<String>('entity_type')) {
        throw StateError('Only entities of the same type can be merged.');
      }
      if (primary.read<String>('status') !=
          LifeEntityStatus.active.storageValue) {
        throw StateError('The primary entity must be active.');
      }
      final priorMerge = await db
          .customSelect(
            'SELECT entity_reference_id FROM entity_attributes '
            'WHERE entity_id = ? AND attribute_key = ?',
            variables: [
              Variable.withString(duplicateEntityId),
              Variable.withString('MERGED_INTO'),
            ],
          )
          .getSingleOrNull();
      if (priorMerge != null) {
        throw StateError('The duplicate entity was already merged.');
      }
      await db.customStatement(
        'INSERT INTO entity_attributes(id, entity_id, attribute_key, '
        'value_type, entity_reference_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          mergeAttributeId,
          duplicateEntityId,
          'MERGED_INTO',
          ClaimValueType.entityReference.storageValue,
          primaryEntityId,
          now,
          now,
        ],
      );
      await db.customStatement(
        'UPDATE entities SET status = ?, archived_at = ?, updated_at = ? '
        'WHERE id = ?',
        [
          LifeEntityStatus.archived.storageValue,
          now,
          now,
          duplicateEntityId,
        ],
      );
      await _audit(
        db,
        'ENTITY_MERGED_FROM',
        primaryEntityId,
        now,
        payloadJson: jsonEncode({'duplicate_entity_id': duplicateEntityId}),
      );
      await _audit(
        db,
        'ENTITY_MERGED_INTO',
        duplicateEntityId,
        now,
        payloadJson: jsonEncode({'primary_entity_id': primaryEntityId}),
      );
    });
  }

  Future<String> createProvenance({
    required ProvenanceSourceType sourceType,
    String? sourceDocumentId,
    String? extractorId,
    String? extractorVersion,
    String? ruleId,
    String? ruleVersion,
    double? confidence,
    String? confidenceSource,
  }) async {
    if (confidence != null && (confidence < 0 || confidence > 1)) {
      throw ArgumentError.value(confidence, 'confidence');
    }
    final id = await _id();
    await session.write((db) async {
      await db.customStatement(
        'INSERT INTO provenance_records(id, source_type, source_document_id, extractor_id, extractor_version, rule_id, rule_version, confidence, confidence_source, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          sourceType.storageValue,
          sourceDocumentId,
          extractorId,
          extractorVersion,
          ruleId,
          ruleVersion,
          confidence,
          confidenceSource,
          _now,
        ],
      );
    });
    return id;
  }

  Future<String> suggestClaim({
    required String subjectEntityId,
    required String predicate,
    required ClaimValue value,
    required ClaimCardinality cardinality,
    String? provenanceId,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    _validateTemporal(validFrom, validUntil);
    if (value.type == ClaimValueType.entityReference) {
      await _ensureEntity(value.stringValue);
    }
    final id = await _id();
    final now = _now;
    await session.write((db) async {
      await _ensureEntityIn(db, subjectEntityId);
      await db.customStatement(
        'INSERT INTO claims(id, subject_entity_id, predicate, value_type, cardinality, valid_from, valid_until, provenance_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          subjectEntityId,
          predicate,
          value.type.storageValue,
          cardinality.storageValue,
          validFrom?.toUtc().millisecondsSinceEpoch,
          validUntil?.toUtc().millisecondsSinceEpoch,
          provenanceId,
          now,
          now,
        ],
      );
      final fields = _claimValueFields(value);
      await db.customStatement(
        'INSERT INTO claim_values(id, claim_id, string_value, integer_value, decimal_value, boolean_value, date_value, datetime_value, money_amount_minor, money_currency, identifier_value, uri_value, entity_reference_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [id, id, ...fields],
      );
      await _history(db, 'claim_history', id, 'SUGGESTED', provenanceId, now);
    });
    return id;
  }

  Future<void> setClaimStatus(String claimId, ClaimStatus status) async {
    final now = _now;
    await session.write((db) async {
      final old = await db
          .customSelect(
            'SELECT status, provenance_id, subject_entity_id, predicate, '
            'cardinality FROM claims WHERE id = ?',
            variables: [Variable.withString(claimId)],
          )
          .getSingleOrNull();
      if (old == null) throw StateError('Unknown claim: $claimId');
      String? supersedesId;
      if (status == ClaimStatus.confirmed &&
          old.read<String>('cardinality') ==
              ClaimCardinality.singleCurrent.storageValue) {
        final prior = await db
            .customSelect(
              'SELECT id, provenance_id, valid_from FROM claims '
              'WHERE subject_entity_id = ? '
              'AND predicate = ? AND status = ? AND id != ? '
              'ORDER BY confirmed_at DESC LIMIT 1',
              variables: [
                Variable.withString(old.read<String>('subject_entity_id')),
                Variable.withString(old.read<String>('predicate')),
                Variable.withString(ClaimStatus.confirmed.storageValue),
                Variable.withString(claimId),
              ],
            )
            .getSingleOrNull();
        if (prior != null) {
          supersedesId = prior.read<String>('id');
          final priorValidFrom = prior.readNullable<int>('valid_from');
          final priorValidUntil =
              priorValidFrom == null || priorValidFrom <= now ? now : null;
          await db.customStatement(
            'UPDATE claims SET status = ?, '
            'valid_until = COALESCE(?, valid_until), updated_at = ? '
            'WHERE id = ?',
            [
              ClaimStatus.superseded.storageValue,
              priorValidUntil,
              now,
              supersedesId,
            ],
          );
          await _history(
            db,
            'claim_history',
            supersedesId,
            ClaimStatus.superseded.storageValue,
            prior.readNullable<String>('provenance_id'),
            now,
          );
        }
      }
      final confirmed = status == ClaimStatus.confirmed ? now : null;
      final rejected = status == ClaimStatus.rejected ? now : null;
      await db.customStatement(
        'UPDATE claims SET status = ?, confirmed_at = ?, rejected_at = ?, '
        'supersedes_id = COALESCE(?, supersedes_id), updated_at = ? '
        'WHERE id = ?',
        [
          status.storageValue,
          confirmed,
          rejected,
          supersedesId,
          now,
          claimId,
        ],
      );
      await _history(
        db,
        'claim_history',
        claimId,
        status.storageValue,
        old.data['provenance_id'] as String?,
        now,
      );
    });
  }

  Future<String> suggestRelationship({
    required String fromEntityId,
    required String toEntityId,
    required LifeRelationshipType type,
    String? provenanceId,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    _validateTemporal(validFrom, validUntil);
    final id = await _id();
    final now = _now;
    await session.write((db) async {
      await _ensureEntityIn(db, fromEntityId);
      await _ensureEntityIn(db, toEntityId);
      await db.customStatement(
        'INSERT INTO relationships(id, from_entity_id, to_entity_id, relationship_type, valid_from, valid_until, provenance_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          fromEntityId,
          toEntityId,
          type.storageValue,
          validFrom?.toUtc().millisecondsSinceEpoch,
          validUntil?.toUtc().millisecondsSinceEpoch,
          provenanceId,
          now,
          now,
        ],
      );
      await _history(
        db,
        'relationship_history',
        id,
        ClaimStatus.suggested.storageValue,
        provenanceId,
        now,
      );
    });
    return id;
  }

  /// Confirms or rejects a suggested relationship while preserving history.
  Future<void> setRelationshipStatus(
    String relationshipId,
    ClaimStatus status,
  ) async {
    final now = _now;
    await session.write((db) async {
      final old = await db
          .customSelect(
            'SELECT provenance_id FROM relationships WHERE id = ?',
            variables: [Variable.withString(relationshipId)],
          )
          .getSingleOrNull();
      if (old == null) {
        throw StateError('Unknown relationship: $relationshipId');
      }
      await db.customStatement(
        'UPDATE relationships SET status = ?, confirmed_at = ?, updated_at = ? WHERE id = ?',
        [
          status.storageValue,
          status == ClaimStatus.confirmed ? now : null,
          now,
          relationshipId,
        ],
      );
      await _history(
        db,
        'relationship_history',
        relationshipId,
        status.storageValue,
        old.data['provenance_id'] as String?,
        now,
      );
    });
  }

  Future<void> addEvidence({
    required String documentId,
    String? assetId,
    String? claimId,
    String? relationshipId,
    int? pageNumber,
    String? boundingPolygonJson,
    String? textFragmentHash,
    String? provenanceId,
  }) async {
    if (claimId == null && relationshipId == null)
      throw ArgumentError('An evidence link needs a claim or relationship');
    final id = await _id();
    await session.write((db) async {
      await db.customStatement(
        'INSERT INTO evidence_links(id, document_id, asset_id, claim_id, relationship_id, evidence_role, page_number, bounding_polygon_json, text_fragment_hash, provenance_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          documentId,
          assetId,
          claimId,
          relationshipId,
          'SOURCE',
          pageNumber,
          boundingPolygonJson,
          textFragmentHash == null ? null : utf8.encode(textFragmentHash),
          provenanceId,
          _now,
        ],
      );
    });
  }

  Future<List<QueryRow>> currentClaims(String entityId) => session.read(
    (db) => db
        .customSelect(
          'SELECT c.*, v.* FROM claims c JOIN claim_values v ON v.claim_id = c.id WHERE c.subject_entity_id = ? AND c.status = ? ORDER BY c.created_at',
          variables: [
            Variable.withString(entityId),
            Variable.withString(ClaimStatus.confirmed.storageValue),
          ],
        )
        .get(),
  );

  Future<List<LifeClaim>> claimsForEntity(
    String entityId, {
    bool includeHistorical = true,
  }) => session.read((db) async {
    final rows = await db
        .customSelect(
          'SELECT c.*, v.string_value, v.integer_value, v.decimal_value, '
          'v.boolean_value, v.date_value, v.datetime_value, '
          'v.money_amount_minor, v.money_currency, v.identifier_value, '
          'v.uri_value, v.entity_reference_id FROM claims c '
          'JOIN claim_values v ON v.claim_id = c.id '
          'WHERE c.subject_entity_id = ? '
          "${includeHistorical ? '' : "AND c.status IN ('SUGGESTED', 'CONFIRMED') "}"
          'ORDER BY c.updated_at DESC, c.id',
          variables: [Variable.withString(entityId)],
        )
        .get();
    return rows.map(_claimFromRow).toList(growable: false);
  });

  Future<LifeClaim?> claim(String claimId) => session.read((db) async {
    final row = await db
        .customSelect(
          'SELECT c.*, v.string_value, v.integer_value, v.decimal_value, '
          'v.boolean_value, v.date_value, v.datetime_value, '
          'v.money_amount_minor, v.money_currency, v.identifier_value, '
          'v.uri_value, v.entity_reference_id FROM claims c '
          'JOIN claim_values v ON v.claim_id = c.id WHERE c.id = ?',
          variables: [Variable.withString(claimId)],
        )
        .getSingleOrNull();
    return row == null ? null : _claimFromRow(row);
  });

  Future<List<EvidenceLink>> evidenceForClaim(String claimId) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM evidence_links WHERE claim_id = ? '
              'ORDER BY created_at, id',
              variables: [Variable.withString(claimId)],
            )
            .get();
        return rows.map(_evidenceFromRow).toList(growable: false);
      });

  Future<List<EvidenceLink>> evidenceForEntity(String entityId) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT DISTINCT e.* FROM evidence_links e '
              'LEFT JOIN claims c ON c.id = e.claim_id '
              'LEFT JOIN relationships r ON r.id = e.relationship_id '
              'WHERE c.subject_entity_id = ? OR r.from_entity_id = ? '
              'OR r.to_entity_id = ? ORDER BY e.created_at DESC, e.id',
              variables: [
                Variable.withString(entityId),
                Variable.withString(entityId),
                Variable.withString(entityId),
              ],
            )
            .get();
        return rows.map(_evidenceFromRow).toList(growable: false);
      });

  Future<List<LifeRelationship>> relationshipsForEntity(String entityId) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM relationships WHERE from_entity_id = ? '
              'OR to_entity_id = ? ORDER BY updated_at DESC, id',
              variables: [
                Variable.withString(entityId),
                Variable.withString(entityId),
              ],
            )
            .get();
        return rows.map(_relationshipFromRow).toList(growable: false);
      });

  Future<String> suggestEvent({
    required LifeEventType type,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    int? amountMinorUnits,
    String? currency,
    String? locationEntityId,
    String? notes,
    Map<String, String> entityRoles = const {},
    String? provenanceId,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) throw ArgumentError.value(title, 'title');
    _validateEvent(
      startAt: startAt,
      endAt: endAt,
      amountMinorUnits: amountMinorUnits,
      currency: currency,
    );
    final id = await _id();
    final now = _now;
    await session.write((db) async {
      if (locationEntityId != null) {
        await _ensureEntityIn(db, locationEntityId);
      }
      for (final entityId in entityRoles.keys) {
        await _ensureEntityIn(db, entityId);
      }
      await db.customStatement(
        'INSERT INTO life_events(id, event_type, title, start_at, end_at, '
        'status, amount_minor, currency, location_entity_id, notes, '
        'provenance_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          type.storageValue,
          normalizedTitle,
          startAt.toUtc().millisecondsSinceEpoch,
          endAt?.toUtc().millisecondsSinceEpoch,
          LifeEventStatus.suggested.storageValue,
          amountMinorUnits,
          amountMinorUnits == null ? null : currency!.trim().toUpperCase(),
          locationEntityId,
          notes?.trim(),
          provenanceId,
          now,
          now,
        ],
      );
      for (final entry in entityRoles.entries) {
        await db.customStatement(
          'INSERT INTO event_entities(id, event_id, entity_id, role, '
          'created_at) VALUES (?, ?, ?, ?, ?)',
          [await _id(), id, entry.key, entry.value.trim(), now],
        );
      }
      await _eventHistory(
        db,
        id,
        LifeEventStatus.suggested.storageValue,
        null,
        provenanceId,
        now,
      );
      await _audit(
        db,
        'EVENT_SUGGESTED',
        id,
        now,
        subjectType: 'EVENT',
      );
    });
    return id;
  }

  Future<void> setEventStatus(
    String eventId,
    LifeEventStatus status,
  ) async {
    final now = _now;
    await session.write((db) async {
      final old = await db
          .customSelect(
            'SELECT status, provenance_id FROM life_events WHERE id = ?',
            variables: [Variable.withString(eventId)],
          )
          .getSingleOrNull();
      if (old == null) throw StateError('Unknown event: $eventId');
      final previous = old.read<String>('status');
      await db.customStatement(
        'UPDATE life_events SET status = ?, confirmed_at = ?, '
        'rejected_at = ?, updated_at = ? WHERE id = ?',
        [
          status.storageValue,
          status == LifeEventStatus.confirmed ? now : null,
          status == LifeEventStatus.rejected ? now : null,
          now,
          eventId,
        ],
      );
      await _eventHistory(
        db,
        eventId,
        status.storageValue,
        previous,
        old.readNullable<String>('provenance_id'),
        now,
      );
      await _audit(
        db,
        'EVENT_${status.storageValue}',
        eventId,
        now,
        subjectType: 'EVENT',
      );
    });
  }

  Future<void> addEventEvidence({
    required String eventId,
    required String documentId,
    String evidenceRole = 'SOURCE',
    String? assetId,
    int? pageNumber,
    String? boundingPolygonJson,
    List<int>? textFragmentHash,
    String? provenanceId,
  }) async {
    final id = await _id();
    await session.write((db) async {
      await _ensureEventIn(db, eventId);
      await db.customStatement(
        'INSERT INTO event_evidence_links(id, event_id, document_id, '
        'asset_id, evidence_role, page_number, bounding_polygon_json, '
        'text_fragment_hash, provenance_id, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          eventId,
          documentId,
          assetId,
          evidenceRole,
          pageNumber,
          boundingPolygonJson,
          textFragmentHash,
          provenanceId,
          _now,
        ],
      );
    });
  }

  Future<List<LifeEvent>> listEvents({
    String? entityId,
    bool includeHistorical = false,
  }) => session.read((db) async {
    final statusClause = includeHistorical
        ? ''
        : "AND e.status IN ('SUGGESTED', 'CONFIRMED') ";
    final entityJoin = entityId == null
        ? ''
        : 'JOIN event_entities ee ON ee.event_id = e.id ';
    final entityClause = entityId == null ? '' : 'AND ee.entity_id = ? ';
    final rows = await db
        .customSelect(
          'SELECT DISTINCT e.* FROM life_events e $entityJoin'
          'WHERE 1 = 1 $statusClause$entityClause'
          'ORDER BY e.start_at DESC, e.created_at DESC, e.id',
          variables: entityId == null
              ? const []
              : [Variable.withString(entityId)],
        )
        .get();
    return rows.map(_eventFromRow).toList(growable: false);
  });

  Future<List<LifeEventEntityLink>> eventEntityLinks(String eventId) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM event_entities WHERE event_id = ? '
              'ORDER BY role, entity_id',
              variables: [Variable.withString(eventId)],
            )
            .get();
        return rows.map(_eventEntityFromRow).toList(growable: false);
      });

  Future<List<LifeEventEvidence>> eventEvidence(String eventId) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM event_evidence_links WHERE event_id = ? '
              'ORDER BY created_at, id',
              variables: [Variable.withString(eventId)],
            )
            .get();
        return rows.map(_eventEvidenceFromRow).toList(growable: false);
      });

  Future<List<LifeEventHistoryEntry>> eventHistory(String eventId) =>
      session.read((db) async {
        final rows = await db
            .customSelect(
              'SELECT * FROM event_history WHERE event_id = ? '
              'ORDER BY created_at, id',
              variables: [Variable.withString(eventId)],
            )
            .get();
        return rows.map(_eventHistoryFromRow).toList(growable: false);
      });

  Future<String> correctEvent({
    required String eventId,
    required LifeEventType type,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    int? amountMinorUnits,
    String? currency,
    String? locationEntityId,
    String? notes,
    String? provenanceId,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) throw ArgumentError.value(title, 'title');
    _validateEvent(
      startAt: startAt,
      endAt: endAt,
      amountMinorUnits: amountMinorUnits,
      currency: currency,
    );
    final replacementId = await _id();
    final now = _now;
    await session.write((db) async {
      final prior = await db
          .customSelect(
            'SELECT status, provenance_id FROM life_events WHERE id = ?',
            variables: [Variable.withString(eventId)],
          )
          .getSingleOrNull();
      if (prior == null) throw StateError('Unknown event: $eventId');
      if (locationEntityId != null) {
        await _ensureEntityIn(db, locationEntityId);
      }
      final replacementProvenance =
          provenanceId ?? prior.readNullable<String>('provenance_id');
      await db.customStatement(
        'INSERT INTO life_events(id, event_type, title, start_at, end_at, '
        'status, amount_minor, currency, location_entity_id, notes, '
        'supersedes_id, provenance_id, created_at, updated_at, confirmed_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          replacementId,
          type.storageValue,
          normalizedTitle,
          startAt.toUtc().millisecondsSinceEpoch,
          endAt?.toUtc().millisecondsSinceEpoch,
          LifeEventStatus.confirmed.storageValue,
          amountMinorUnits,
          amountMinorUnits == null ? null : currency!.trim().toUpperCase(),
          locationEntityId,
          notes?.trim(),
          eventId,
          replacementProvenance,
          now,
          now,
          now,
        ],
      );
      final entityRows = await db
          .customSelect(
            'SELECT entity_id, role FROM event_entities WHERE event_id = ?',
            variables: [Variable.withString(eventId)],
          )
          .get();
      for (final row in entityRows) {
        await db.customStatement(
          'INSERT INTO event_entities(id, event_id, entity_id, role, '
          'created_at) VALUES (?, ?, ?, ?, ?)',
          [
            await _id(),
            replacementId,
            row.read<String>('entity_id'),
            row.read<String>('role'),
            now,
          ],
        );
      }
      final evidenceRows = await db
          .customSelect(
            'SELECT document_id, asset_id, evidence_role, page_number, '
            'bounding_polygon_json, text_fragment_hash, provenance_id '
            'FROM event_evidence_links WHERE event_id = ?',
            variables: [Variable.withString(eventId)],
          )
          .get();
      for (final row in evidenceRows) {
        await db.customStatement(
          'INSERT INTO event_evidence_links(id, event_id, document_id, '
          'asset_id, evidence_role, page_number, bounding_polygon_json, '
          'text_fragment_hash, provenance_id, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            await _id(),
            replacementId,
            row.read<String>('document_id'),
            row.readNullable<String>('asset_id'),
            row.read<String>('evidence_role'),
            row.readNullable<int>('page_number'),
            row.readNullable<String>('bounding_polygon_json'),
            row.readNullable<Uint8List>('text_fragment_hash'),
            row.readNullable<String>('provenance_id'),
            now,
          ],
        );
      }
      final previousStatus = prior.read<String>('status');
      await db.customStatement(
        'UPDATE life_events SET status = ?, updated_at = ? WHERE id = ?',
        [LifeEventStatus.superseded.storageValue, now, eventId],
      );
      await _eventHistory(
        db,
        eventId,
        LifeEventStatus.superseded.storageValue,
        previousStatus,
        prior.readNullable<String>('provenance_id'),
        now,
      );
      await _eventHistory(
        db,
        replacementId,
        LifeEventStatus.confirmed.storageValue,
        null,
        replacementProvenance,
        now,
      );
      await _audit(
        db,
        'EVENT_CORRECTED',
        replacementId,
        now,
        subjectType: 'EVENT',
        payloadJson: jsonEncode({'supersedes_id': eventId}),
      );
    });
    return replacementId;
  }

  Future<List<LifeExpenseTotal>> expenseTotals({
    required DateTime from,
    required DateTime until,
    String? entityId,
  }) => session.read((db) async {
    if (!until.isAfter(from)) throw ArgumentError('until must be after from');
    final join = entityId == null
        ? ''
        : 'JOIN event_entities ee ON ee.event_id = e.id ';
    final entityClause = entityId == null ? '' : 'AND ee.entity_id = ? ';
    final expenseTypes = <LifeEventType>[
      LifeEventType.purchase,
      LifeEventType.payment,
      LifeEventType.renewal,
      LifeEventType.service,
      LifeEventType.repair,
      LifeEventType.medical,
      LifeEventType.education,
      LifeEventType.tax,
      LifeEventType.warranty,
    ];
    final variables = <Variable<Object>>[
      Variable.withInt(from.toUtc().millisecondsSinceEpoch),
      Variable.withInt(until.toUtc().millisecondsSinceEpoch),
      ...expenseTypes.map(
        (type) => Variable.withString(type.storageValue),
      ),
      if (entityId != null) Variable.withString(entityId),
    ];
    final rows = await db
        .customSelect(
          'SELECT e.currency, SUM(e.amount_minor) AS total, '
          'COUNT(DISTINCT e.id) AS event_count FROM life_events e $join'
          "WHERE e.status = 'CONFIRMED' AND e.amount_minor IS NOT NULL "
          'AND e.start_at >= ? AND e.start_at < ? AND e.event_type IN '
          '(${List.filled(expenseTypes.length, '?').join(',')}) '
          '$entityClause GROUP BY e.currency ORDER BY e.currency',
          variables: variables,
        )
        .get();
    return rows
        .map(
          (row) => LifeExpenseTotal(
            currency: row.read<String>('currency'),
            amountMinorUnits: row.read<int>('total'),
            eventCount: row.read<int>('event_count'),
          ),
        )
        .toList(growable: false);
  });

  static int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;

  static LifeEntity _entityFromRow(QueryRow row) => LifeEntity(
    id: row.read<String>('id'),
    type: LifeEntityType.fromStorage(row.read<String>('entity_type')),
    subtype: row.readNullable<String>('subtype'),
    displayName: row.read<String>('display_name'),
    status: LifeEntityStatus.fromStorage(row.read<String>('status')),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('created_at'),
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('updated_at'),
      isUtc: true,
    ),
    archivedAt: switch (row.readNullable<int>('archived_at')) {
      final value? => DateTime.fromMillisecondsSinceEpoch(value, isUtc: true),
      null => null,
    },
  );

  static LifeEntityAttribute _attributeFromRow(QueryRow row) =>
      LifeEntityAttribute(
        id: row.read<String>('id'),
        entityId: row.read<String>('entity_id'),
        key: row.read<String>('attribute_key'),
        value: _claimValueFromRow(
          ClaimValueType.values.firstWhere(
            (type) => type.storageValue == row.read<String>('value_type'),
          ),
          row,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('created_at'),
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('updated_at'),
          isUtc: true,
        ),
      );

  static ClaimValue _claimValueFromRow(ClaimValueType type, QueryRow row) =>
      switch (type) {
        ClaimValueType.string => ClaimValue.string(
          row.read<String>('string_value'),
        ),
        ClaimValueType.integer => ClaimValue.integer(
          row.read<int>('integer_value'),
        ),
        ClaimValueType.decimal => ClaimValue.decimal(
          row.read<double>('decimal_value'),
        ),
        ClaimValueType.boolean => ClaimValue.boolean(
          row.read<int>('boolean_value') == 1,
        ),
        ClaimValueType.date => ClaimValue.date(
          DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('date_value'),
            isUtc: true,
          ),
        ),
        ClaimValueType.datetime => ClaimValue.datetime(
          DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('datetime_value'),
            isUtc: true,
          ),
        ),
        ClaimValueType.money => ClaimValue.money(
          ClaimMoney(
            amountMinorUnits: row.read<int>('money_amount_minor'),
            currency: row.read<String>('money_currency'),
          ),
        ),
        ClaimValueType.identifier => ClaimValue.identifier(
          row.read<String>('identifier_value'),
        ),
        ClaimValueType.uri => ClaimValue.uri(row.read<String>('uri_value')),
        ClaimValueType.entityReference => ClaimValue.entityReference(
          row.read<String>('entity_reference_id'),
        ),
      };

  static LifeClaim _claimFromRow(QueryRow row) {
    final valueType = ClaimValueType.values.firstWhere(
      (type) => type.storageValue == row.read<String>('value_type'),
    );
    return LifeClaim(
      id: row.read<String>('id'),
      subjectEntityId: row.read<String>('subject_entity_id'),
      predicate: row.read<String>('predicate'),
      value: _claimValueFromRow(valueType, row),
      status: ClaimStatus.fromStorage(row.read<String>('status')),
      cardinality: ClaimCardinality.fromStorage(
        row.read<String>('cardinality'),
      ),
      validFrom: _dateFromNullable(row.readNullable<int>('valid_from')),
      validUntil: _dateFromNullable(row.readNullable<int>('valid_until')),
      supersedesId: row.readNullable<String>('supersedes_id'),
      provenanceId: row.readNullable<String>('provenance_id'),
      createdAt: _dateFromNullable(row.readNullable<int>('created_at')),
      updatedAt: _dateFromNullable(row.readNullable<int>('updated_at')),
      confirmedAt: _dateFromNullable(row.readNullable<int>('confirmed_at')),
      rejectedAt: _dateFromNullable(row.readNullable<int>('rejected_at')),
    );
  }

  static EvidenceLink _evidenceFromRow(QueryRow row) => EvidenceLink(
    id: row.read<String>('id'),
    documentId: row.read<String>('document_id'),
    assetId: row.readNullable<String>('asset_id'),
    claimId: row.readNullable<String>('claim_id'),
    relationshipId: row.readNullable<String>('relationship_id'),
    evidenceRole: row.read<String>('evidence_role'),
    pageNumber: row.readNullable<int>('page_number'),
    boundingPolygonJson: row.readNullable<String>('bounding_polygon_json'),
    textFragmentHash: row
        .readNullable<Uint8List>('text_fragment_hash')
        ?.toList(growable: false),
    provenanceId: row.readNullable<String>('provenance_id'),
    createdAt: _dateFromNullable(row.readNullable<int>('created_at')),
  );

  static LifeRelationship _relationshipFromRow(QueryRow row) =>
      LifeRelationship(
        id: row.read<String>('id'),
        fromEntityId: row.read<String>('from_entity_id'),
        toEntityId: row.read<String>('to_entity_id'),
        type: LifeRelationshipType.fromStorage(
          row.read<String>('relationship_type'),
        ),
        status: ClaimStatus.fromStorage(row.read<String>('status')),
        validFrom: _dateFromNullable(row.readNullable<int>('valid_from')),
        validUntil: _dateFromNullable(row.readNullable<int>('valid_until')),
        supersedesId: row.readNullable<String>('supersedes_id'),
        provenanceId: row.readNullable<String>('provenance_id'),
        createdAt: _dateFromNullable(row.readNullable<int>('created_at')),
        updatedAt: _dateFromNullable(row.readNullable<int>('updated_at')),
        confirmedAt: _dateFromNullable(row.readNullable<int>('confirmed_at')),
      );

  static LifeEvent _eventFromRow(QueryRow row) => LifeEvent(
    id: row.read<String>('id'),
    type: LifeEventType.fromStorage(row.read<String>('event_type')),
    title: row.read<String>('title'),
    startAt: _dateFromNullable(row.read<int>('start_at'))!,
    endAt: _dateFromNullable(row.readNullable<int>('end_at')),
    status: LifeEventStatus.fromStorage(row.read<String>('status')),
    amountMinorUnits: row.readNullable<int>('amount_minor'),
    currency: row.readNullable<String>('currency'),
    locationEntityId: row.readNullable<String>('location_entity_id'),
    notes: row.readNullable<String>('notes'),
    supersedesId: row.readNullable<String>('supersedes_id'),
    provenanceId: row.readNullable<String>('provenance_id'),
    createdAt: _dateFromNullable(row.readNullable<int>('created_at')),
    updatedAt: _dateFromNullable(row.readNullable<int>('updated_at')),
    confirmedAt: _dateFromNullable(row.readNullable<int>('confirmed_at')),
    rejectedAt: _dateFromNullable(row.readNullable<int>('rejected_at')),
  );

  static LifeEventEntityLink _eventEntityFromRow(QueryRow row) =>
      LifeEventEntityLink(
        id: row.read<String>('id'),
        eventId: row.read<String>('event_id'),
        entityId: row.read<String>('entity_id'),
        role: row.read<String>('role'),
        createdAt: _dateFromNullable(row.readNullable<int>('created_at')),
      );

  static LifeEventEvidence _eventEvidenceFromRow(QueryRow row) =>
      LifeEventEvidence(
        id: row.read<String>('id'),
        eventId: row.read<String>('event_id'),
        documentId: row.read<String>('document_id'),
        evidenceRole: row.read<String>('evidence_role'),
        assetId: row.readNullable<String>('asset_id'),
        pageNumber: row.readNullable<int>('page_number'),
        boundingPolygonJson: row.readNullable<String>(
          'bounding_polygon_json',
        ),
        textFragmentHash: row
            .readNullable<Uint8List>('text_fragment_hash')
            ?.toList(growable: false),
        provenanceId: row.readNullable<String>('provenance_id'),
        createdAt: _dateFromNullable(row.readNullable<int>('created_at')),
      );

  static LifeEventHistoryEntry _eventHistoryFromRow(QueryRow row) =>
      LifeEventHistoryEntry(
        id: row.read<String>('id'),
        eventId: row.read<String>('event_id'),
        eventType: row.read<String>('event_type'),
        previousStatus: switch (row.readNullable<String>('previous_status')) {
          final status? => LifeEventStatus.fromStorage(status),
          null => null,
        },
        provenanceId: row.readNullable<String>('provenance_id'),
        createdAt: _dateFromNullable(row.read<int>('created_at'))!,
      );

  static DateTime? _dateFromNullable(int? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

  Future<String> _id() async =>
      base64UrlEncode(await random.secureBytes(24)).replaceAll('=', '');
  Future<void> _ensureEntity(String id) =>
      session.read((db) => _ensureEntityIn(db, id));
  static Future<void> _ensureEntityIn(dynamic db, String id) async {
    final row = await db
        .customSelect(
          'SELECT id FROM entities WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Unknown entity: $id');
  }

  static Future<void> _ensureEventIn(dynamic db, String id) async {
    final row = await db
        .customSelect(
          'SELECT id FROM life_events WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Unknown event: $id');
  }

  static void _validateTemporal(DateTime? from, DateTime? until) {
    if (from != null && until != null && until.isBefore(from))
      throw ArgumentError('validUntil cannot precede validFrom');
  }

  static void _validateEvent({
    required DateTime startAt,
    DateTime? endAt,
    int? amountMinorUnits,
    String? currency,
  }) {
    if (endAt != null && endAt.isBefore(startAt)) {
      throw ArgumentError('endAt must not be before startAt');
    }
    if (amountMinorUnits != null &&
        (currency == null || currency.trim().isEmpty)) {
      throw ArgumentError('currency is required when amount is present');
    }
  }

  static List<Object?> _claimValueFields(ClaimValue v) {
    final x = List<Object?>.filled(11, null);
    switch (v.type) {
      case ClaimValueType.string:
        x[0] = v.stringValue;
      case ClaimValueType.integer:
        x[1] = v.integerValue;
      case ClaimValueType.decimal:
        x[2] = v.decimalValue;
      case ClaimValueType.boolean:
        x[3] = v.booleanValue ? 1 : 0;
      case ClaimValueType.date:
        x[4] = v.dateTimeValue.toUtc().millisecondsSinceEpoch;
      case ClaimValueType.datetime:
        x[5] = v.dateTimeValue.toUtc().millisecondsSinceEpoch;
      case ClaimValueType.money:
        x[6] = v.moneyValue.amountMinorUnits;
        x[7] = v.moneyValue.currency;
      case ClaimValueType.identifier:
        x[8] = v.stringValue;
      case ClaimValueType.uri:
        x[9] = v.stringValue;
      case ClaimValueType.entityReference:
        x[10] = v.stringValue;
    }
    return x;
  }

  Future<void> _history(
    dynamic db,
    String table,
    String id,
    String event,
    String? provenance,
    int now,
  ) async {
    final historyId = await _id();
    await db.customStatement(
      'INSERT INTO $table(id, ${table == 'claim_history' ? 'claim_id' : 'relationship_id'}, event_type, provenance_id, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        historyId,
        id,
        event,
        provenance,
        now,
      ],
    );
  }

  Future<void> _eventHistory(
    dynamic db,
    String eventId,
    String eventType,
    String? previousStatus,
    String? provenanceId,
    int now,
  ) async {
    await db.customStatement(
      'INSERT INTO event_history(id, event_id, event_type, previous_status, '
      'provenance_id, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [
        await _id(),
        eventId,
        eventType,
        previousStatus,
        provenanceId,
        now,
      ],
    );
  }

  Future<void> _audit(
    dynamic db,
    String event,
    String id,
    int now, {
    String subjectType = 'ENTITY',
    String? payloadJson,
  }) async {
    final auditId = await _id();
    await db.customStatement(
      'INSERT INTO graph_audit_events(id, event_type, subject_type, subject_id, payload_json, event_hash, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        auditId,
        event,
        subjectType,
        id,
        payloadJson,
        List<int>.filled(32, 0),
        now,
      ],
    );
  }
}
