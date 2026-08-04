import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/src/errors/ingestion_failure.dart';
import 'package:vault_ingestion/src/model/ingestion_models.dart';
import 'package:vault_objects/vault_objects.dart';
import 'package:vault_ocr/vault_ocr.dart';

/// SQLCipher-backed source of truth for durable ingestion work.
final class IngestionJobRepository {
  /// Creates the repository for one unlocked vault session.
  const IngestionJobRepository(this._session);

  final VaultDatabaseSession _session;

  static const List<Duration> _retrySchedule = <Duration>[
    Duration.zero,
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
    Duration(hours: 1),
  ];

  /// Atomically creates the document and durable job after object publication.
  Future<void> registerOriginal({
    required String documentId,
    required String jobId,
    required IngestionCandidate candidate,
    required EncryptedObjectWriteResult original,
    required int pipelineVersion,
    required DateTime now,
  }) => _session.write(
    (database) => database.transaction(() async {
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      await database.customStatement(
        '''
        INSERT INTO documents(
          id, logical_filename, mime_type, source_type, status,
          primary_object_id, plaintext_sha256, plaintext_size, encrypted_size,
          imported_at, updated_at, verified_at, integrity_status
        ) VALUES (?, ?, ?, ?, 'PROCESSING', ?, ?, ?, ?, ?, ?, ?, 'VERIFIED')
        ''',
        <Object>[
          documentId,
          candidate.logicalFilename,
          candidate.mimeType,
          candidate.source.storageValue,
          original.objectId.value,
          original.plaintextSha256,
          original.plaintextSize,
          original.encryptedSize,
          timestamp,
          timestamp,
          timestamp,
        ],
      );
      await database.customStatement(
        'UPDATE object_references SET reference_count = 1, '
        'last_referenced_at = ? WHERE object_id = ?',
        <Object>[timestamp, original.objectId.value],
      );
      await database.customStatement(
        '''
        INSERT INTO processing_jobs(
          id, document_id, pipeline_version, status, priority,
          created_at, updated_at
        ) VALUES (?, ?, ?, 'QUEUED', 100, ?, ?)
        ''',
        <Object>[jobId, documentId, pipelineVersion, timestamp, timestamp],
      );
      await database.customStatement(
        '''
        INSERT INTO processing_job_steps(
          id, job_id, step_name, step_version, status, input_fingerprint,
          output_reference, attempt_count, started_at, completed_at
        ) VALUES (?, ?, 'ORIGINAL_STORE', 1, 'COMPLETED', ?, ?, 1, ?, ?)
        ''',
        <Object>[
          '$jobId-original-v1',
          jobId,
          _hex(original.plaintextSha256),
          original.objectId.value,
          timestamp,
          timestamp,
        ],
      );
      await database.customStatement(
        '''
        INSERT INTO processing_job_steps(
          id, job_id, step_name, step_version, status, attempt_count
        ) VALUES (?, ?, 'THUMBNAIL', 1, 'PENDING', 0)
        ''',
        <Object>['$jobId-thumbnail-v1', jobId],
      );
      for (final step in const <String>[
        'OCR',
        'CLASSIFY',
        'EXTRACT',
        'INDEX',
        'REVIEW',
      ]) {
        await database.customStatement(
          '''
          INSERT INTO processing_job_steps(
            id, job_id, step_name, step_version, status, attempt_count
          ) VALUES (?, ?, ?, 1, 'PENDING', 0)
          ''',
          <Object>['$jobId-${step.toLowerCase()}-v1', jobId, step],
        );
      }
    }),
  );

  /// Claims one eligible job, reclaiming an expired lease transactionally.
  Future<IngestionJobLease?> claimNext({
    required String workerId,
    required DateTime now,
    Duration leaseDuration = const Duration(minutes: 2),
  }) => _session.write(
    (database) => database.transaction(() async {
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      final row = await database
          .customSelect(
            '''
        SELECT j.id, j.document_id, j.attempt_count, d.primary_object_id,
               d.logical_filename, d.mime_type
        FROM processing_jobs j
        JOIN documents d ON d.id = j.document_id
        WHERE (
          j.status IN ('QUEUED', 'RETRY')
          AND (j.available_after IS NULL OR j.available_after <= ?)
        ) OR (
          j.status = 'PROCESSING'
          AND j.lease_expires_at IS NOT NULL AND j.lease_expires_at <= ?
        )
        ORDER BY j.priority ASC, j.created_at ASC
        LIMIT 1
        ''',
            variables: <Variable<Object>>[
              Variable<int>(timestamp),
              Variable<int>(timestamp),
            ],
          )
          .getSingleOrNull();
      if (row == null) return null;
      final jobId = row.read<String>('id');
      final leaseExpiresAt = now.toUtc().add(leaseDuration);
      final updated = await database.customUpdate(
        '''
        UPDATE processing_jobs
        SET status = 'PROCESSING', lease_owner = ?, lease_expires_at = ?,
            attempt_count = attempt_count + 1, updated_at = ?,
            available_after = NULL
        WHERE id = ? AND (
          (status IN ('QUEUED', 'RETRY')
            AND (available_after IS NULL OR available_after <= ?))
          OR (status = 'PROCESSING' AND lease_expires_at <= ?)
        )
        ''',
        variables: <Variable<Object>>[
          Variable<String>(workerId),
          Variable<int>(leaseExpiresAt.millisecondsSinceEpoch),
          Variable<int>(timestamp),
          Variable<String>(jobId),
          Variable<int>(timestamp),
          Variable<int>(timestamp),
        ],
        updates: <TableInfo<Table, Object?>>{database.processingJobs},
      );
      if (updated != 1) return null;
      return IngestionJobLease(
        jobId: jobId,
        documentId: row.read<String>('document_id'),
        originalObjectId: ObjectId.parse(
          row.read<String>('primary_object_id'),
        ),
        logicalFilename: row.read<String>('logical_filename'),
        mimeType: row.read<String>('mime_type'),
        workerId: workerId,
        attemptCount: row.read<int>('attempt_count') + 1,
        leaseExpiresAt: leaseExpiresAt,
      );
    }),
  );

  /// Whether an idempotent step already committed before a process death.
  Future<bool> isThumbnailComplete(IngestionJobLease lease) => _session.read(
    (database) async {
      final row = await database
          .customSelect(
            'SELECT status FROM processing_job_steps WHERE job_id = ? '
            "AND step_name = 'THUMBNAIL' AND step_version = 1",
            variables: <Variable<Object>>[Variable<String>(lease.jobId)],
          )
          .getSingle();
      return row.read<String>('status') == 'COMPLETED' ||
          row.read<String>('status') == 'SKIPPED';
    },
  );

  /// Whether a durable stage has already committed or intentionally skipped.
  Future<bool> isStepComplete(
    IngestionJobLease lease,
    String stepName,
  ) => _session.read((database) async {
    final row = await database
        .customSelect(
          'SELECT status FROM processing_job_steps WHERE job_id = ? '
          'AND step_name = ? AND step_version = 1',
          variables: <Variable<Object>>[
            Variable<String>(lease.jobId),
            Variable<String>(stepName),
          ],
        )
        .getSingle();
    return const <String>{
      'COMPLETED',
      'SKIPPED',
    }.contains(row.read<String>('status'));
  });

  /// Extends an owned lease between bounded processing stages.
  Future<IngestionJobLease> renewLease(
    IngestionJobLease lease,
    DateTime now, {
    Duration leaseDuration = const Duration(minutes: 2),
  }) => _session.write((database) async {
    final expires = now.toUtc().add(leaseDuration);
    final updated = await database.customUpdate(
      '''
      UPDATE processing_jobs SET lease_expires_at = ?, updated_at = ?
      WHERE id = ? AND status = 'PROCESSING' AND lease_owner = ?
        AND lease_expires_at >= ?
      ''',
      variables: <Variable<Object>>[
        Variable<int>(expires.millisecondsSinceEpoch),
        Variable<int>(now.toUtc().millisecondsSinceEpoch),
        Variable<String>(lease.jobId),
        Variable<String>(lease.workerId),
        Variable<int>(now.toUtc().millisecondsSinceEpoch),
      ],
      updates: <TableInfo<Table, Object?>>{database.processingJobs},
    );
    if (updated != 1) throw const IngestionLeaseFailure();
    return IngestionJobLease(
      jobId: lease.jobId,
      documentId: lease.documentId,
      originalObjectId: lease.originalObjectId,
      logicalFilename: lease.logicalFilename,
      mimeType: lease.mimeType,
      workerId: lease.workerId,
      attemptCount: lease.attemptCount,
      leaseExpiresAt: expires,
    );
  });

  /// Atomically attaches a committed thumbnail and completes its step.
  Future<void> completeThumbnail({
    required IngestionJobLease lease,
    required ObjectId thumbnailObjectId,
    required EncryptedObjectWriteResult thumbnail,
    required DateTime now,
  }) => _session.write(
    (database) => database.transaction(() async {
      if (thumbnail.objectId != thumbnailObjectId) {
        throw StateError('Thumbnail result identifier mismatch');
      }
      await _assertLease(database, lease, now);
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      final step = await database
          .customSelect(
            'SELECT status FROM processing_job_steps WHERE job_id = ? '
            "AND step_name = 'THUMBNAIL' AND step_version = 1",
            variables: <Variable<Object>>[Variable<String>(lease.jobId)],
          )
          .getSingle();
      if (step.read<String>('status') == 'COMPLETED') return;
      await database.customStatement(
        '''
        INSERT INTO document_assets(
          id, document_id, object_id, asset_type, mime_type,
          pipeline_version, created_at
        ) SELECT ?, ?, ?, 'THUMBNAIL', 'image/jpeg', pipeline_version, ?
          FROM processing_jobs WHERE id = ?
        ''',
        <Object>[
          '${lease.documentId}-thumbnail-v1',
          lease.documentId,
          thumbnailObjectId.value,
          timestamp,
          lease.jobId,
        ],
      );
      await database.customStatement(
        'UPDATE object_references SET reference_count = 1, '
        'last_referenced_at = ? WHERE object_id = ?',
        <Object>[timestamp, thumbnailObjectId.value],
      );
      await database.customStatement(
        '''
        UPDATE processing_job_steps
        SET status = 'COMPLETED', output_reference = ?, attempt_count = ?,
            error_code = NULL, error_message = NULL, completed_at = ?
        WHERE job_id = ? AND step_name = 'THUMBNAIL' AND step_version = 1
        ''',
        <Object>[
          thumbnailObjectId.value,
          lease.attemptCount,
          timestamp,
          lease.jobId,
        ],
      );
    }),
  );

  /// Marks the thumbnail step intentionally skipped for non-image originals.
  Future<void> skipThumbnail(
    IngestionJobLease lease,
    DateTime now,
  ) => _session.write((database) async {
    await _assertLease(database, lease, now);
    await database.customStatement(
      '''
      UPDATE processing_job_steps SET status = 'SKIPPED',
        attempt_count = ?, completed_at = ?
      WHERE job_id = ? AND step_name = 'THUMBNAIL' AND step_version = 1
      ''',
      <Object>[
        lease.attemptCount,
        now.toUtc().millisecondsSinceEpoch,
        lease.jobId,
      ],
    );
  });

  /// Atomically attaches encrypted layout and persists searchable page text.
  Future<void> completeOcr({
    required IngestionJobLease lease,
    required ObjectId layoutObjectId,
    required EncryptedObjectWriteResult layout,
    required OcrResult result,
    required DateTime now,
  }) => _session.write(
    (database) => database.transaction(() async {
      if (layout.objectId != layoutObjectId) {
        throw StateError('OCR layout result identifier mismatch');
      }
      await _assertLease(database, lease, now);
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      if (await _stepIsComplete(database, lease.jobId, 'OCR')) return;
      await database.customStatement(
        '''
        INSERT INTO document_assets(
          id, document_id, object_id, asset_type, mime_type,
          pipeline_version, created_at
        ) SELECT ?, ?, ?, 'OCR_LAYOUT',
          'application/vnd.citizen-vault.ocr-layout+json',
          pipeline_version, ? FROM processing_jobs WHERE id = ?
        ''',
        <Object>[
          '${lease.documentId}-ocr-layout-v1',
          lease.documentId,
          layoutObjectId.value,
          timestamp,
          lease.jobId,
        ],
      );
      await database.customStatement(
        'UPDATE object_references SET reference_count = 1, '
        'last_referenced_at = ? WHERE object_id = ?',
        <Object>[timestamp, layoutObjectId.value],
      );
      await database.customStatement(
        'DELETE FROM document_text WHERE document_id = ? '
        'AND ocr_pipeline_version = 1',
        <Object>[lease.documentId],
      );
      final textPages = result.pages.isNotEmpty
          ? result.pages
                .map(
                  (page) => (
                    pageNumber: page.pageNumber,
                    text: page.text,
                  ),
                )
                .toList(growable: false)
          : result.rawText.trim().isEmpty
          ? const <({int pageNumber, String text})>[]
          : <({int pageNumber, String text})>[
              (pageNumber: 1, text: result.rawText.trim()),
            ];
      for (final page in textPages) {
        await database.customStatement(
          '''
          INSERT INTO document_text(
            id, document_id, page_number, raw_text, normalized_text,
            ocr_engine_id, ocr_engine_version, ocr_pipeline_version,
            language_codes, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
          ''',
          <Object?>[
            '${lease.documentId}-text-v1-${page.pageNumber}',
            lease.documentId,
            page.pageNumber,
            page.text,
            _normalizeText(page.text),
            result.engineId,
            result.engineVersion,
            jsonEncode(result.detectedLanguages),
            timestamp,
          ],
        );
      }
      await _completeStep(
        database,
        lease: lease,
        stepName: 'OCR',
        outputReference: layoutObjectId.value,
        timestamp: timestamp,
      );
    }),
  );

  /// Returns the encrypted OCR-layout object for idempotent resume.
  Future<ObjectId?> ocrLayoutObjectId(String documentId) =>
      _session.read((database) async {
        final row = await database
            .customSelect(
              '''
              SELECT object_id FROM document_assets
              WHERE document_id = ? AND asset_type = 'OCR_LAYOUT'
                AND deleted_at IS NULL
              ORDER BY created_at DESC LIMIT 1
              ''',
              variables: <Variable<Object>>[
                Variable<String>(documentId),
              ],
            )
            .getSingleOrNull();
        return switch (row?.readNullable<String>('object_id')) {
          final String value => ObjectId.parse(value),
          null => null,
        };
      });

  /// Returns the encrypted thumbnail object for safe detail presentation.
  Future<ObjectId?> thumbnailObjectId(String documentId) =>
      _session.read((database) async {
        final row = await database
            .customSelect(
              '''
              SELECT object_id FROM document_assets
              WHERE document_id = ? AND asset_type = 'THUMBNAIL'
                AND deleted_at IS NULL
              ORDER BY created_at DESC LIMIT 1
              ''',
              variables: <Variable<Object>>[
                Variable<String>(documentId),
              ],
            )
            .getSingleOrNull();
        return switch (row?.readNullable<String>('object_id')) {
          final String value => ObjectId.parse(value),
          null => null,
        };
      });

  /// Returns the immutable encrypted original for explicit foreground access.
  Future<ObjectId?> originalObjectId(String documentId) =>
      _session.read((database) async {
        final row = await database
            .customSelect(
              '''
              SELECT primary_object_id FROM documents
              WHERE id = ? AND deleted_at IS NULL
              ''',
              variables: <Variable<Object>>[
                Variable<String>(documentId),
              ],
            )
            .getSingleOrNull();
        return switch (row?.readNullable<String>('primary_object_id')) {
          final String value => ObjectId.parse(value),
          null => null,
        };
      });

  /// Persists a non-authoritative classification and its rule evidence.
  Future<void> completeClassification({
    required IngestionJobLease lease,
    required DocumentClassificationSuggestion suggestion,
    required DateTime now,
  }) => _session.write(
    (database) => database.transaction(() async {
      await _assertLease(database, lease, now);
      if (await _stepIsComplete(database, lease.jobId, 'CLASSIFY')) return;
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      await database.customStatement(
        '''
        INSERT INTO document_classifications(
          id, document_id, document_type, confidence, classifier_id,
          classifier_version, evidence_json, confirmed_by_user,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
        ''',
        <Object>[
          '${lease.jobId}-classification-v1',
          lease.documentId,
          suggestion.type.storageValue,
          suggestion.confidence,
          suggestion.classifierId,
          suggestion.classifierVersion,
          jsonEncode(suggestion.evidence),
          timestamp,
          timestamp,
        ],
      );
      await _completeStep(
        database,
        lease: lease,
        stepName: 'CLASSIFY',
        outputReference: suggestion.type.storageValue,
        timestamp: timestamp,
      );
    }),
  );

  /// Loads the current machine suggestion for resume and extraction.
  Future<DocumentClassificationSuggestion> classificationFor(
    String documentId,
  ) => _session.read((database) async {
    final row = await database
        .customSelect(
          '''
          SELECT document_type, confidence, classifier_id, classifier_version,
                 evidence_json
          FROM document_classifications WHERE document_id = ?
          ORDER BY confirmed_by_user DESC, updated_at DESC LIMIT 1
          ''',
          variables: <Variable<Object>>[Variable<String>(documentId)],
        )
        .getSingle();
    return DocumentClassificationSuggestion(
      type: DocumentType.fromStorage(row.read<String>('document_type')),
      confidence: row.readNullable<double>('confidence') ?? 0,
      evidence: _decodeEvidence(row.readNullable<String>('evidence_json')),
      classifierId: row.read<String>('classifier_id'),
      classifierVersion: row.read<String>('classifier_version'),
    );
  });

  /// Replaces unconfirmed deterministic candidates for this pipeline version.
  Future<void> completeExtraction({
    required IngestionJobLease lease,
    required List<ExtractedFieldCandidate> candidates,
    required DateTime now,
  }) => _session.write(
    (database) => database.transaction(() async {
      await _assertLease(database, lease, now);
      if (await _stepIsComplete(database, lease.jobId, 'EXTRACT')) return;
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      await database.customStatement(
        'DELETE FROM extracted_fields WHERE document_id = ? '
        'AND confirmed_by_user = 0',
        <Object>[lease.documentId],
      );
      for (var index = 0; index < candidates.length; index += 1) {
        final candidate = candidates[index];
        await database.customStatement(
          '''
          INSERT INTO extracted_fields(
            id, document_id, field_type, raw_value, normalized_value,
            confidence, source_page, source_block_id, extractor_id,
            extractor_version, confirmed_by_user, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
          ''',
          <Object?>[
            '${lease.jobId}-field-v1-${index + 1}',
            lease.documentId,
            candidate.type.storageValue,
            candidate.rawValue,
            candidate.normalizedValue,
            candidate.confidence,
            candidate.sourcePage,
            candidate.sourceBlockId,
            candidate.extractorId,
            candidate.extractorVersion,
            timestamp,
            timestamp,
          ],
        );
      }
      await _completeStep(
        database,
        lease: lease,
        stepName: 'EXTRACT',
        outputReference: candidates.length.toString(),
        timestamp: timestamp,
      );
    }),
  );

  /// Builds derived FTS and releases the worker for explicit user review.
  Future<void> indexAndAwaitReview(
    IngestionJobLease lease,
    DateTime now,
  ) => _session.write(
    (database) => database.transaction(() async {
      await _assertLease(database, lease, now);
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      if (!await _stepIsComplete(database, lease.jobId, 'INDEX')) {
        await database.indexDocument(lease.documentId);
        await _completeStep(
          database,
          lease: lease,
          stepName: 'INDEX',
          outputReference: lease.documentId,
          timestamp: timestamp,
        );
      }
      await database.customStatement(
        '''
        UPDATE processing_jobs SET status = 'AWAITING_REVIEW',
          updated_at = ?, lease_owner = NULL, lease_expires_at = NULL
        WHERE id = ?
        ''',
        <Object>[timestamp, lease.jobId],
      );
      await database.customStatement(
        "UPDATE documents SET status = 'NEEDS_REVIEW', updated_at = ? "
        'WHERE id = ?',
        <Object>[timestamp, lease.documentId],
      );
    }),
  );

  /// Returns newest-first documents awaiting human confirmation.
  Future<List<DocumentReviewView>> listReviews() => _session.read(
    (database) async {
      final documents = await database.customSelect('''
        SELECT d.id, d.logical_filename,
          c.document_type, c.confidence, c.evidence_json,
          COALESCE((
            SELECT group_concat(COALESCE(t.normalized_text, t.raw_text), ' ')
            FROM document_text t WHERE t.document_id = d.id
          ), '') AS ocr_text
        FROM documents d
        JOIN processing_jobs j ON j.document_id = d.id
        LEFT JOIN document_classifications c ON c.id = (
          SELECT c2.id FROM document_classifications c2
          WHERE c2.document_id = d.id
          ORDER BY c2.confirmed_by_user DESC, c2.updated_at DESC LIMIT 1
        )
        WHERE j.status = 'AWAITING_REVIEW' AND d.deleted_at IS NULL
        ORDER BY d.imported_at DESC
      ''').get();
      final output = <DocumentReviewView>[];
      for (final document in documents) {
        final documentId = document.read<String>('id');
        final fieldRows = await database
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
        output.add(
          DocumentReviewView(
            documentId: documentId,
            logicalFilename: document.read<String>('logical_filename'),
            suggestedType: DocumentType.fromStorage(
              document.readNullable<String>('document_type') ?? 'UNKNOWN',
            ),
            classificationConfidence: document.readNullable<double>(
              'confidence',
            ),
            classificationEvidence: _decodeEvidence(
              document.readNullable<String>('evidence_json'),
            ),
            fields: fieldRows
                .map(_mapField)
                .whereType<ExtractedFieldView>()
                .toList(growable: false),
            ocrTextPreview: _preview(document.read<String>('ocr_text')),
          ),
        );
      }
      return output;
    },
  );

  /// Confirms/edits suggestions, completes review, and refreshes FTS.
  Future<void> confirmReview({
    required String documentId,
    required DocumentType documentType,
    required List<ConfirmedFieldEdit> fields,
    required DateTime now,
  }) => _session.write(
    (database) => database.transaction(() async {
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      final job = await database
          .customSelect(
            '''
            SELECT id FROM processing_jobs WHERE document_id = ?
              AND status = 'AWAITING_REVIEW'
            ''',
            variables: <Variable<Object>>[Variable<String>(documentId)],
          )
          .getSingleOrNull();
      if (job == null) {
        throw const IngestionFailure(
          code: 'review_not_available',
          disposition: IngestionFailureDisposition.permanent,
        );
      }
      final jobId = job.read<String>('id');
      await database.customStatement(
        '''
        INSERT OR REPLACE INTO document_classifications(
          id, document_id, document_type, confidence, classifier_id,
          classifier_version, evidence_json, confirmed_by_user,
          created_at, updated_at
        ) VALUES (?, ?, ?, 1.0, 'USER', '1', '["user_confirmed"]', 1, ?, ?)
        ''',
        <Object>[
          '$jobId-classification-user',
          documentId,
          documentType.storageValue,
          timestamp,
          timestamp,
        ],
      );
      await database.customStatement(
        'UPDATE documents SET document_type = ?, updated_at = ? WHERE id = ?',
        <Object>[documentType.storageValue, timestamp, documentId],
      );
      for (final field in fields) {
        final value = field.value.trim();
        if (value.isEmpty) {
          await database.customStatement(
            'DELETE FROM extracted_fields WHERE id = ? AND document_id = ?',
            <Object>[field.fieldId, documentId],
          );
        } else {
          await database.customStatement(
            '''
            UPDATE extracted_fields SET normalized_value = ?,
              confirmed_by_user = 1, updated_at = ?
            WHERE id = ? AND document_id = ?
            ''',
            <Object>[value, timestamp, field.fieldId, documentId],
          );
        }
      }
      await database.customStatement(
        '''
        UPDATE processing_job_steps SET status = 'COMPLETED',
          output_reference = ?, attempt_count = attempt_count + 1,
          completed_at = ?
        WHERE job_id = ? AND step_name = 'REVIEW' AND step_version = 1
        ''',
        <Object>[documentType.storageValue, timestamp, jobId],
      );
      await database.customStatement(
        '''
        UPDATE processing_jobs SET status = 'COMPLETED', completed_at = ?,
          updated_at = ? WHERE id = ?
        ''',
        <Object>[timestamp, timestamp, jobId],
      );
      await database.customStatement(
        "UPDATE documents SET status = 'READY', updated_at = ? WHERE id = ?",
        <Object>[timestamp, documentId],
      );
      await database.indexDocument(documentId);
    }),
  );

  /// Requeues local derivation while preserving the encrypted original,
  /// user metadata, tags, links, and processing history.
  Future<List<ObjectId>> reprocessDocument(String documentId, DateTime now) =>
      _session.write(
        (database) => database.transaction(() async {
          final timestamp = now.toUtc().millisecondsSinceEpoch;
          final job = await database
              .customSelect(
                'SELECT id FROM processing_jobs WHERE document_id = ?',
                variables: [Variable<String>(documentId)],
              )
              .getSingleOrNull();
          if (job == null) {
            throw const IngestionFailure(
              code: 'document_not_processable',
              disposition: IngestionFailureDisposition.permanent,
            );
          }
          final jobId = job.read<String>('id');
          final derivedObjects = await database
              .customSelect(
                "SELECT object_id FROM document_assets WHERE document_id = ? "
                "AND asset_type IN ('THUMBNAIL', 'OCR_LAYOUT') "
                'AND deleted_at IS NULL',
                variables: <Variable<Object>>[
                  Variable<String>(documentId),
                ],
              )
              .get();
          final replacedObjectIds = derivedObjects
              .map((row) => ObjectId.parse(row.read<String>('object_id')))
              .toList(growable: false);
          await database.customStatement(
            'DELETE FROM document_text WHERE document_id = ?',
            <Object>[documentId],
          );
          await database.customStatement(
            "DELETE FROM document_assets WHERE document_id = ? "
            "AND asset_type IN ('THUMBNAIL', 'OCR_LAYOUT')",
            <Object>[documentId],
          );
          for (final objectId in replacedObjectIds) {
            await database.customStatement(
              'UPDATE object_references SET reference_count = '
              'MAX(reference_count - 1, 0), last_referenced_at = ? '
              'WHERE object_id = ?',
              <Object>[timestamp, objectId.value],
            );
          }
          await database.customStatement(
            'DELETE FROM extracted_fields WHERE document_id = ?',
            <Object>[documentId],
          );
          await database.customStatement(
            'DELETE FROM document_classifications WHERE document_id = ?',
            <Object>[documentId],
          );
          await database.customStatement(
            "UPDATE processing_job_steps SET status = 'PENDING', "
            'attempt_count = 0, output_reference = NULL, error_code = NULL, '
            "started_at = NULL, completed_at = NULL WHERE job_id = ? "
            "AND step_name != 'ORIGINAL_STORE'",
            <Object>[jobId],
          );
          await database.customStatement(
            "UPDATE processing_jobs SET status = 'QUEUED', attempt_count = 0, "
            'available_after = NULL, lease_owner = NULL, '
            'lease_expires_at = NULL, completed_at = NULL, '
            'updated_at = ? WHERE id = ?',
            <Object>[timestamp, jobId],
          );
          await database.customStatement(
            "UPDATE documents SET status = 'PROCESSING', updated_at = ? "
            'WHERE id = ? AND deleted_at IS NULL',
            <Object>[timestamp, documentId],
          );
          await database.indexDocument(documentId);
          return replacedObjectIds;
        }),
      );

  /// Queries the local FTS index with a literal bounded phrase.
  Future<List<DocumentSearchResult>> search(
    String query, {
    int limit = 25,
  }) => _session.read((database) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const <DocumentSearchResult>[];
    if (normalized.length > 200 || limit < 1 || limit > 100) {
      throw const IngestionFailure(
        code: 'search_query_invalid',
        disposition: IngestionFailureDisposition.permanent,
      );
    }
    final terms = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    )
        .allMatches(normalized)
        .map((match) => match.group(0)!.toLowerCase())
        .take(16)
        .toList();
    if (terms.isEmpty) return const <DocumentSearchResult>[];
    final ftsQuery = terms
        .map((term) => '"${term.replaceAll('"', '""')}"*')
        .join(' AND ');
    final rows = await database
        .customSelect(
          '''
          SELECT f.document_id, d.logical_filename,
                 COALESCE(d.document_type, 'UNKNOWN') AS document_type,
                 bm25(document_fts) AS relevance
          FROM document_fts f
          JOIN documents d ON d.id = f.document_id
          WHERE document_fts MATCH ? AND d.deleted_at IS NULL
          ORDER BY relevance LIMIT ?
          ''',
          variables: <Variable<Object>>[
            Variable<String>(ftsQuery),
            Variable<int>(limit),
          ],
        )
        .get();
    return rows
        .map(
          (row) => DocumentSearchResult(
            documentId: row.read<String>('document_id'),
            logicalFilename: row.read<String>('logical_filename'),
            documentType: DocumentType.fromStorage(
              row.read<String>('document_type'),
            ),
            relevance: row.read<double>('relevance'),
          ),
        )
        .toList(growable: false);
  });

  /// Marks a document as corrupt without persisting sensitive error details.
  Future<void> markIntegrityFailure(String documentId) => _session.write(
    (database) => database.customStatement(
      '''
      UPDATE documents SET integrity_status = 'CORRUPT', updated_at = ?
      WHERE id = ? AND deleted_at IS NULL
      ''',
      <Object>[
        DateTime.now().toUtc().millisecondsSinceEpoch,
        documentId,
      ],
    ),
  );

  /// Records a classified failure with bounded exponential retry.
  Future<void> recordFailure({
    required IngestionJobLease lease,
    required IngestionFailure failure,
    required DateTime now,
  }) => _session.write(
    (database) => database.transaction(() async {
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      final mayRetry =
          failure.disposition == IngestionFailureDisposition.transient &&
          lease.attemptCount < _retrySchedule.length;
      final available = mayRetry
          ? now
                .toUtc()
                .add(_retrySchedule[lease.attemptCount - 1])
                .millisecondsSinceEpoch
          : null;
      final status = mayRetry ? 'RETRY' : 'FAILED';
      final updated = await database.customUpdate(
        '''
        UPDATE processing_jobs SET status = ?, available_after = ?,
          updated_at = ?, completed_at = ?, lease_owner = NULL,
          lease_expires_at = NULL WHERE id = ? AND lease_owner = ?
        ''',
        variables: <Variable<Object>>[
          Variable<String>(status),
          Variable<int>(available),
          Variable<int>(timestamp),
          Variable<int>(mayRetry ? null : timestamp),
          Variable<String>(lease.jobId),
          Variable<String>(lease.workerId),
        ],
        updates: <TableInfo<Table, Object?>>{database.processingJobs},
      );
      if (updated != 1) throw const IngestionLeaseFailure();
      await database.customStatement(
        '''
        UPDATE processing_job_steps SET status = ?, attempt_count = ?,
          error_code = ?, error_message = NULL
        WHERE id = (
          SELECT id FROM processing_job_steps
          WHERE job_id = ? AND status NOT IN ('COMPLETED', 'SKIPPED')
          ORDER BY CASE step_name
            WHEN 'THUMBNAIL' THEN 1
            WHEN 'OCR' THEN 2
            WHEN 'CLASSIFY' THEN 3
            WHEN 'EXTRACT' THEN 4
            WHEN 'INDEX' THEN 5
            WHEN 'REVIEW' THEN 6
            ELSE 99 END
          LIMIT 1
        )
        ''',
        <Object>[
          if (mayRetry) 'RETRY' else 'FAILED',
          lease.attemptCount,
          failure.code,
          lease.jobId,
        ],
      );
      if (!mayRetry) {
        await database.customStatement(
          "UPDATE documents SET status = 'FAILED', updated_at = ? "
          'WHERE id = ?',
          <Object>[timestamp, lease.documentId],
        );
      }
    }),
  );

  /// Makes expired leases immediately eligible after startup/process recovery.
  Future<int> recoverExpiredLeases(DateTime now) => _session.write(
    (database) => database.customUpdate(
      '''
      UPDATE processing_jobs SET status = 'RETRY', available_after = ?,
        lease_owner = NULL, lease_expires_at = NULL, updated_at = ?
      WHERE status = 'PROCESSING' AND lease_expires_at <= ?
      ''',
      variables: <Variable<Object>>[
        Variable<int>(now.toUtc().millisecondsSinceEpoch),
        Variable<int>(now.toUtc().millisecondsSinceEpoch),
        Variable<int>(now.toUtc().millisecondsSinceEpoch),
      ],
      updates: <TableInfo<Table, Object?>>{database.processingJobs},
    ),
  );

  /// Returns newest-first UI-safe durable job views.
  Future<List<DocumentProcessingView>> listJobs() => _session.read(
    (database) async {
      final rows = await database.customSelect('''
        SELECT j.id, j.document_id, j.status, j.attempt_count,
               j.available_after, j.created_at, j.updated_at,
               d.logical_filename, d.mime_type, d.source_type,
               (SELECT error_code FROM processing_job_steps s
                WHERE s.job_id = j.id AND s.error_code IS NOT NULL
                ORDER BY s.rowid DESC LIMIT 1) AS error_code,
               (SELECT object_id FROM document_assets a
                WHERE a.document_id = d.id AND a.asset_type = 'THUMBNAIL'
                  AND a.deleted_at IS NULL LIMIT 1) AS thumbnail_object_id
        FROM processing_jobs j JOIN documents d ON d.id = j.document_id
        ORDER BY j.created_at DESC
      ''').get();
      return rows.map(_mapView).toList(growable: false);
    },
  );

  /// Finds newly orphaned committed objects that are not already tombstoned.
  Future<List<ObjectId>> findUnmarkedOrphans() => _session.read(
    (database) async {
      final rows = await database.customSelect('''
        SELECT r.object_id FROM object_references r
        WHERE r.reference_count = 0
          AND NOT EXISTS (SELECT 1 FROM documents d
            WHERE d.primary_object_id = r.object_id AND d.deleted_at IS NULL)
          AND NOT EXISTS (SELECT 1 FROM document_assets a
            WHERE a.object_id = r.object_id AND a.deleted_at IS NULL)
          AND NOT EXISTS (SELECT 1 FROM backup_generation_objects b
            WHERE b.object_id = r.object_id)
          AND NOT EXISTS (SELECT 1 FROM object_tombstones t
            WHERE t.object_id = r.object_id)
        ORDER BY r.object_id
      ''').get();
      return rows
          .map((row) => ObjectId.parse(row.read<String>('object_id')))
          .toList(growable: false);
    },
  );

  /// Finds tombstoned objects whose retention window elapsed.
  Future<List<ObjectId>> findDueOrphans(DateTime now) => _session.read(
    (database) async {
      final rows = await database
          .customSelect(
            '''
        SELECT object_id FROM object_tombstones
        WHERE deleted_at IS NULL AND eligible_for_deletion_at <= ?
        ORDER BY object_id
        ''',
            variables: <Variable<Object>>[
              Variable<int>(now.toUtc().millisecondsSinceEpoch),
            ],
          )
          .get();
      return rows
          .map((row) => ObjectId.parse(row.read<String>('object_id')))
          .toList(growable: false);
    },
  );

  static Future<void> _assertLease(
    CitizenVaultDatabase database,
    IngestionJobLease lease,
    DateTime now,
  ) async {
    final row = await database
        .customSelect(
          'SELECT lease_owner, lease_expires_at, status FROM processing_jobs '
          'WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(lease.jobId)],
        )
        .getSingleOrNull();
    if (row == null ||
        row.read<String>('status') != 'PROCESSING' ||
        row.readNullable<String>('lease_owner') != lease.workerId ||
        (row.readNullable<int>('lease_expires_at') ?? 0) <
            now.toUtc().millisecondsSinceEpoch) {
      throw const IngestionLeaseFailure();
    }
  }

  static Future<bool> _stepIsComplete(
    CitizenVaultDatabase database,
    String jobId,
    String stepName,
  ) async {
    final row = await database
        .customSelect(
          'SELECT status FROM processing_job_steps WHERE job_id = ? '
          'AND step_name = ? AND step_version = 1',
          variables: <Variable<Object>>[
            Variable<String>(jobId),
            Variable<String>(stepName),
          ],
        )
        .getSingle();
    return row.read<String>('status') == 'COMPLETED';
  }

  static Future<void> _completeStep(
    CitizenVaultDatabase database, {
    required IngestionJobLease lease,
    required String stepName,
    required String outputReference,
    required int timestamp,
  }) => database.customStatement(
    '''
    UPDATE processing_job_steps
    SET status = 'COMPLETED', output_reference = ?, attempt_count = ?,
        error_code = NULL, error_message = NULL, completed_at = ?
    WHERE job_id = ? AND step_name = ? AND step_version = 1
    ''',
    <Object>[
      outputReference,
      lease.attemptCount,
      timestamp,
      lease.jobId,
      stepName,
    ],
  );

  static List<String> _decodeEvidence(String? encoded) {
    if (encoded == null || encoded.length > 8192) return const <String>[];
    try {
      final value = jsonDecode(encoded);
      if (value is! List<Object?> || value.length > 64) {
        return const <String>[];
      }
      return value
          .whereType<String>()
          .where((item) => item.length <= 128)
          .toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
  }

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

  static String _preview(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 500
        ? normalized
        : '${normalized.substring(0, 500)}…';
  }

  static String _normalizeText(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static DocumentProcessingView _mapView(QueryRow row) =>
      DocumentProcessingView(
        jobId: row.read<String>('id'),
        documentId: row.read<String>('document_id'),
        logicalFilename: row.read<String>('logical_filename'),
        mimeType: row.read<String>('mime_type'),
        source: _source(row.read<String>('source_type')),
        status: _status(row.read<String>('status')),
        attemptCount: row.read<int>('attempt_count'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('created_at'),
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('updated_at'),
          isUtc: true,
        ),
        availableAfter: switch (row.readNullable<int>('available_after')) {
          final int value => DateTime.fromMillisecondsSinceEpoch(
            value,
            isUtc: true,
          ),
          null => null,
        },
        safeErrorCode: row.readNullable<String>('error_code'),
        thumbnailObjectId: row.readNullable<String>('thumbnail_object_id'),
      );

  static DocumentImportSource _source(String value) =>
      DocumentImportSource.values.singleWhere(
        (source) => source.storageValue == value,
      );

  static DocumentProcessingStatus _status(String value) => switch (value) {
    'QUEUED' => DocumentProcessingStatus.queued,
    'PROCESSING' => DocumentProcessingStatus.processing,
    'RETRY' => DocumentProcessingStatus.retryScheduled,
    'AWAITING_REVIEW' => DocumentProcessingStatus.awaitingReview,
    'COMPLETED' => DocumentProcessingStatus.ready,
    'FAILED' => DocumentProcessingStatus.failed,
    _ => DocumentProcessingStatus.registering,
  };
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
