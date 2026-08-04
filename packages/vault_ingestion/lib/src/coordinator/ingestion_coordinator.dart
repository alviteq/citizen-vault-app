// Named public dependencies intentionally initialize private owned fields.
// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/src/errors/ingestion_failure.dart';
import 'package:vault_ingestion/src/model/ingestion_models.dart';
import 'package:vault_ingestion/src/repository/ingestion_job_repository.dart';
import 'package:vault_ingestion/src/thumbnail/thumbnail_generator.dart';
import 'package:vault_objects/vault_objects.dart';
import 'package:vault_ocr/vault_ocr.dart';

/// Durable coordinator that preserves originals and idempotently derives
/// assets.
final class IngestionCoordinator {
  /// Creates a coordinator for one unlocked vault.
  IngestionCoordinator({
    required IngestionJobRepository jobs,
    required EncryptedObjectStore objectStore,
    required VaultFileRootKey fileRootKey,
    required CryptographicRandom random,
    ThumbnailGenerator thumbnails = const IsolateThumbnailGenerator(),
    OcrEngine ocrEngine = const DisabledOcrEngine(),
    DecryptedAssetLeaseManager? decryptedAssets,
    DocumentClassifier classifier = const DeterministicDocumentClassifier(),
    DeterministicExtractionPipeline? extraction,
    List<String> Function()? preferredOcrLanguages,
    this.limits = const IngestionLimits(),
    this.pipelineVersion = 2,
    DateTime Function()? clock,
  }) : _jobs = jobs,
       _objectStore = objectStore,
       _fileRootKey = fileRootKey,
       _random = random,
       _thumbnails = thumbnails,
       _ocrEngine = ocrEngine,
       _decryptedAssets = decryptedAssets,
       _classifier = classifier,
       _extraction = extraction ?? DeterministicExtractionPipeline(),
       _preferredOcrLanguages =
           preferredOcrLanguages ?? (() => const <String>['en']),
       _clock = clock ?? DateTime.now;

  final IngestionJobRepository _jobs;
  final EncryptedObjectStore _objectStore;
  final VaultFileRootKey _fileRootKey;
  final CryptographicRandom _random;
  final ThumbnailGenerator _thumbnails;
  final OcrEngine _ocrEngine;
  final DecryptedAssetLeaseManager? _decryptedAssets;
  final DocumentClassifier _classifier;
  final DeterministicExtractionPipeline _extraction;
  final List<String> Function() _preferredOcrLanguages;
  final DateTime Function() _clock;

  /// Reviewed import/thumbnail resource limits.
  final IngestionLimits limits;

  /// Active deterministic pipeline version.
  final int pipelineVersion;

  static const Set<String> _supportedMimeTypes = <String>{
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/bmp',
    'image/tiff',
    'image/heic',
    'image/heif',
    'text/plain',
    'text/csv',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  /// Streams an immutable original into authenticated storage, then queues
  /// work.
  Future<IngestionRegistration> import(IngestionCandidate candidate) async {
    _validate(candidate);
    final originalObjectId = await ObjectId.generate(_random);
    final documentId = (await ObjectId.generate(_random)).value;
    final jobId = (await ObjectId.generate(_random)).value;
    EncryptedObjectWriteResult? original;
    try {
      original = await _objectStore.put(
        plaintext: _countedStream(candidate),
        objectId: originalObjectId,
        fileRootKey: _fileRootKey,
      );
      if (original.plaintextSize != candidate.length) {
        throw const InvalidImportFailure('source_length_mismatch');
      }
      await _jobs.registerOriginal(
        documentId: documentId,
        jobId: jobId,
        candidate: candidate,
        original: original,
        pipelineVersion: pipelineVersion,
        now: _clock().toUtc(),
      );
      return IngestionRegistration(
        documentId: documentId,
        jobId: jobId,
        originalObjectId: originalObjectId,
      );
    } on IngestionFailure {
      rethrow;
    } on ObjectWriteFailure catch (error) {
      final cause = error.cause;
      if (cause is IngestionFailure) throw cause;
      throw IngestionFailure(
        code: 'original_store_failed',
        disposition: IngestionFailureDisposition.transient,
        cause: error,
      );
    } on Object catch (error) {
      throw IngestionFailure(
        code: original == null
            ? 'original_store_failed'
            : 'document_registration_failed',
        disposition: IngestionFailureDisposition.transient,
        cause: error,
      );
    }
  }

  /// Processes one eligible job. Returns false when the queue is idle.
  Future<bool> runNext({required String workerId}) async {
    final claimed = await _jobs.claimNext(
      workerId: workerId,
      now: _clock().toUtc(),
    );
    if (claimed == null) return false;
    var lease = claimed;
    try {
      if (!await _jobs.isThumbnailComplete(lease)) {
        if (lease.requiresThumbnail) {
          final original = await _readBoundedOriginal(lease);
          lease = await _jobs.renewLease(lease, _clock().toUtc());
          GeneratedThumbnail? generated;
          try {
            generated = await _thumbnails.generate(original, limits);
          } on ThumbnailFailure catch (failure) {
            if (lease.mimeType == 'application/pdf' &&
                failure.code == 'image_format_unsupported') {
              await _jobs.skipThumbnail(lease, _clock().toUtc());
            } else {
              rethrow;
            }
          }
          if (generated == null) {
            lease = await _jobs.renewLease(lease, _clock().toUtc());
          } else {
            lease = await _jobs.renewLease(lease, _clock().toUtc());
            final thumbnailId = await ObjectId.generate(_random);
            final thumbnail = await _objectStore.put(
              plaintext: Stream<List<int>>.value(generated.bytes),
              objectId: thumbnailId,
              fileRootKey: _fileRootKey,
              chunkSize: 64 * 1024,
            );
            lease = await _jobs.renewLease(lease, _clock().toUtc());
            await _jobs.completeThumbnail(
              lease: lease,
              thumbnailObjectId: thumbnailId,
              thumbnail: thumbnail,
              now: _clock().toUtc(),
            );
          }
        } else {
          await _jobs.skipThumbnail(lease, _clock().toUtc());
        }
      }
      lease = await _jobs.renewLease(
        lease,
        _clock().toUtc(),
        leaseDuration: const Duration(minutes: 10),
      );
      final ocr = await _loadOrCreateOcr(lease);
      lease = await _jobs.renewLease(lease, _clock().toUtc());
      if (!await _jobs.isStepComplete(lease, 'CLASSIFY')) {
        await _jobs.completeClassification(
          lease: lease,
          suggestion: _classifier.classify(ocr),
          now: _clock().toUtc(),
        );
      }
      final classification = await _jobs.classificationFor(lease.documentId);
      lease = await _jobs.renewLease(lease, _clock().toUtc());
      if (!await _jobs.isStepComplete(lease, 'EXTRACT')) {
        final candidates = await _extraction.extract(
          ExtractionContext(
            documentType: classification.type,
            ocr: ocr,
          ),
        );
        await _jobs.completeExtraction(
          lease: lease,
          candidates: candidates,
          now: _clock().toUtc(),
        );
      }
      lease = await _jobs.renewLease(lease, _clock().toUtc());
      await _jobs.indexAndAwaitReview(lease, _clock().toUtc());
      return true;
    } on IngestionFailure catch (failure) {
      await _jobs.recordFailure(
        lease: lease,
        failure: failure,
        now: _clock().toUtc(),
      );
      return true;
    } on OcrFailure catch (failure) {
      await _jobs.recordFailure(
        lease: lease,
        failure: IngestionFailure(
          code: failure.code,
          disposition: failure.transient
              ? IngestionFailureDisposition.transient
              : IngestionFailureDisposition.permanent,
          cause: failure,
        ),
        now: _clock().toUtc(),
      );
      return true;
    } on Object catch (error) {
      await _jobs.recordFailure(
        lease: lease,
        failure: IngestionFailure(
          code: 'processing_temporarily_unavailable',
          disposition: IngestionFailureDisposition.transient,
          cause: error,
        ),
        now: _clock().toUtc(),
      );
      return true;
    }
  }

  /// Drains currently eligible work without assuming permanent background life.
  Future<int> processUntilIdle({
    required String workerId,
    int maximumJobs = 100,
  }) async {
    if (maximumJobs < 1 || maximumJobs > 1000) {
      throw RangeError.range(maximumJobs, 1, 1000, 'maximumJobs');
    }
    var processed = 0;
    while (processed < maximumJobs && await runNext(workerId: workerId)) {
      processed += 1;
    }
    return processed;
  }

  /// Re-runs bounded local derivation for an existing encrypted original.
  Future<void> reprocessDocument({
    required String documentId,
    required String workerId,
  }) async {
    final replacedObjects = await _jobs.reprocessDocument(
      documentId,
      _clock().toUtc(),
    );
    for (final objectId in replacedObjects) {
      await _objectStore.markForDeletion(objectId);
    }
    await processUntilIdle(workerId: workerId);
  }

  /// Recovers expired jobs and advances orphan retention after process startup.
  Future<void> recover() async {
    final now = _clock().toUtc();
    await _decryptedAssets?.cleanupExpired();
    await _objectStore.cleanupInterruptedWrites();
    await _jobs.recoverExpiredLeases(now);
    for (final objectId in await _jobs.findUnmarkedOrphans()) {
      await _objectStore.markForDeletion(objectId);
    }
    for (final objectId in await _jobs.findDueOrphans(now)) {
      try {
        await _objectStore.deleteWhenUnreferenced(objectId);
      } on ObjectStoreFailure {
        // It became referenced or was already handled; a later pass rechecks.
      }
    }
  }

  /// Current durable jobs for presentation.
  Future<List<DocumentProcessingView>> listJobs() => _jobs.listJobs();

  /// Current documents waiting for local human verification.
  Future<List<DocumentReviewView>> listReviews() => _jobs.listReviews();

  /// Confirms local suggestions and completes the durable review stage.
  Future<void> confirmReview({
    required String documentId,
    required DocumentType documentType,
    required List<ConfirmedFieldEdit> fields,
  }) => _jobs.confirmReview(
    documentId: documentId,
    documentType: documentType,
    fields: fields,
    now: _clock().toUtc(),
  );

  /// Searches the local derived FTS index.
  Future<List<DocumentSearchResult>> search(
    String query, {
    int limit = 25,
  }) => _jobs.search(query, limit: limit);

  /// Decrypts only a bounded metadata-free thumbnail for foreground preview.
  Future<Uint8List?> preview(String documentId) async {
    final objectId = await _jobs.thumbnailObjectId(documentId);
    if (objectId == null) return null;
    try {
      final output = BytesBuilder(copy: false);
      var total = 0;
      await for (final bytes in _objectStore.read(
        objectId: objectId,
        fileRootKey: _fileRootKey,
      )) {
        total += bytes.length;
        if (total > 2 * 1024 * 1024) {
          throw const IngestionFailure(
            code: 'preview_size_unsupported',
            disposition: IngestionFailureDisposition.permanent,
          );
        }
        output.add(bytes);
      }
      return output.takeBytes();
    } on ObjectStoreFailure {
      await _jobs.markIntegrityFailure(documentId);
      rethrow;
    }
  }

  /// Authenticates the complete original into an expiring app-private lease.
  Future<DecryptedAssetLease> originalLease(
    String documentId, {
    required String suffix,
  }) async {
    final leases = _decryptedAssets;
    if (leases == null) {
      throw const IngestionFailure(
        code: 'document_access_unavailable',
        disposition: IngestionFailureDisposition.permanent,
      );
    }
    final objectId = await _jobs.originalObjectId(documentId);
    if (objectId == null) {
      throw const IngestionFailure(
        code: 'document_original_missing',
        disposition: IngestionFailureDisposition.permanent,
      );
    }
    try {
      return await leases.create(
        plaintext: _objectStore.read(
          objectId: objectId,
          fileRootKey: _fileRootKey,
        ),
        suffix: suffix,
      );
    } on ObjectStoreFailure {
      await _jobs.markIntegrityFailure(documentId);
      rethrow;
    }
  }

  Future<OcrResult> _loadOrCreateOcr(IngestionJobLease lease) async {
    if (await _jobs.isStepComplete(lease, 'OCR')) {
      final existing = await _jobs.ocrLayoutObjectId(lease.documentId);
      if (existing == null) {
        throw const IngestionFailure(
          code: 'ocr_layout_missing',
          disposition: IngestionFailureDisposition.permanent,
        );
      }
      return OcrResultCodec.decode(await _readBoundedLayout(existing));
    }

    final capabilities = await _ocrEngine.capabilities();
    OcrResult result;
    if (capabilities.supportsMimeType(lease.mimeType)) {
      final leases = _decryptedAssets;
      if (leases == null) {
        throw const IngestionFailure(
          code: 'ocr_pipeline_invalid',
          disposition: IngestionFailureDisposition.permanent,
        );
      }
      final input = await leases.create(
        plaintext: _objectStore.read(
          objectId: lease.originalObjectId,
          fileRootKey: _fileRootKey,
        ),
        suffix: _suffixFor(lease.mimeType),
      );
      try {
        final cancellation = OcrCancellationSignal();
        result = await _ocrEngine.recognize(
          OcrRequest(
            encryptedAssetReference: lease.originalObjectId.value,
            input: input,
            mimeType: lease.mimeType,
            preferredLanguages: _preferredOcrLanguages(),
            preferredScripts: const <String>[],
            detectLayout: true,
            detectTables: false,
            cancellation: cancellation,
          ),
        );
      } finally {
        await input.close();
      }
    } else {
      result = OcrResult.empty(
        engineId: _ocrEngine.engineId,
        engineVersion: _ocrEngine.engineVersion,
      );
    }
    if (result.engineId != _ocrEngine.engineId ||
        result.engineVersion != _ocrEngine.engineVersion) {
      throw const IngestionFailure(
        code: 'ocr_provider_identity_mismatch',
        disposition: IngestionFailureDisposition.permanent,
      );
    }
    final encoded = OcrResultCodec.encode(result);
    final layoutObjectId = await ObjectId.generate(_random);
    final layout = await _objectStore.put(
      plaintext: Stream<List<int>>.value(encoded),
      objectId: layoutObjectId,
      fileRootKey: _fileRootKey,
      chunkSize: 64 * 1024,
    );
    await _jobs.completeOcr(
      lease: lease,
      layoutObjectId: layoutObjectId,
      layout: layout,
      result: result,
      now: _clock().toUtc(),
    );
    return result;
  }

  Future<Uint8List> _readBoundedLayout(ObjectId objectId) async {
    final output = BytesBuilder(copy: false);
    var total = 0;
    await for (final bytes in _objectStore.read(
      objectId: objectId,
      fileRootKey: _fileRootKey,
    )) {
      total += bytes.length;
      if (total > OcrResultCodec.maximumBytes) {
        throw const IngestionFailure(
          code: 'ocr_layout_too_large',
          disposition: IngestionFailureDisposition.permanent,
        );
      }
      output.add(bytes);
    }
    return output.takeBytes();
  }

  static String _suffixFor(String mimeType) => switch (mimeType) {
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/webp' => '.webp',
    'image/bmp' => '.bmp',
    'image/heic' => '.heic',
    'image/heif' => '.heif',
    'application/pdf' => '.pdf',
    'text/plain' => '.txt',
    'text/csv' => '.csv',
    'application/msword' => '.doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
      '.docx',
    'application/vnd.ms-excel' => '.xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
      '.xlsx',
    'application/vnd.ms-powerpoint' => '.ppt',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
      '.pptx',
    _ => throw const IngestionFailure(
      code: 'ocr_source_unsupported',
      disposition: IngestionFailureDisposition.permanent,
    ),
  };

  Stream<List<int>> _countedStream(IngestionCandidate candidate) async* {
    var total = 0;
    await for (final bytes in candidate.openRead()) {
      total += bytes.length;
      if (total > candidate.length || total > limits.maximumFileBytes) {
        throw const InvalidImportFailure('source_length_mismatch');
      }
      yield bytes;
    }
    if (total != candidate.length) {
      throw const InvalidImportFailure('source_length_mismatch');
    }
  }

  Future<Uint8List> _readBoundedOriginal(IngestionJobLease lease) async {
    final output = BytesBuilder(copy: false);
    var total = 0;
    await for (final bytes in _objectStore.read(
      objectId: lease.originalObjectId,
      fileRootKey: _fileRootKey,
    )) {
      total += bytes.length;
      if (total > limits.maximumImageBytes) {
        throw const ThumbnailFailure(
          code: 'image_size_unsupported',
          disposition: IngestionFailureDisposition.permanent,
        );
      }
      output.add(bytes);
    }
    return output.takeBytes();
  }

  void _validate(IngestionCandidate candidate) {
    if (candidate.logicalFilename.isEmpty ||
        candidate.logicalFilename.length > 255 ||
        candidate.logicalFilename.contains('/') ||
        candidate.logicalFilename.contains(r'\') ||
        candidate.logicalFilename.contains('\u0000')) {
      throw const InvalidImportFailure('invalid_logical_filename');
    }
    if (candidate.length < 1 || candidate.length > limits.maximumFileBytes) {
      throw const InvalidImportFailure('file_size_unsupported');
    }
    if (!_supportedMimeTypes.contains(candidate.mimeType.toLowerCase())) {
      throw const InvalidImportFailure('file_type_unsupported');
    }
    if (candidate.mimeType.startsWith('image/') &&
        candidate.length > limits.maximumImageBytes) {
      throw const InvalidImportFailure('image_size_unsupported');
    }
  }
}
