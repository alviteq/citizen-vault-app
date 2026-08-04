import 'package:meta/meta.dart';

/// How an original document entered the local vault.
enum DocumentImportSource {
  /// Captured with the device camera.
  camera('CAMERA'),

  /// Selected from the device image library.
  gallery('GALLERY'),

  /// Selected from the operating-system file picker.
  filePicker('FILE_PICKER'),

  /// Received from an operating-system share intent.
  shareIntent('SHARE_INTENT');

  const DocumentImportSource(this.storageValue);

  /// Stable database representation.
  final String storageValue;
}

/// Durable state of one imported document's processing job.
enum DocumentProcessingStatus {
  /// Original registration is being committed.
  registering,

  /// Durable work is waiting for a worker.
  queued,

  /// A worker currently owns a valid lease.
  processing,

  /// A bounded retry is scheduled.
  retryScheduled,

  /// Milestone-six processing completed.
  ready,

  /// Machine suggestions are waiting for explicit local confirmation.
  awaitingReview,

  /// Processing ended with a permanent or exhausted failure.
  failed;

  /// Coarse progress used by presentation without inventing per-byte progress.
  double get progress => switch (this) {
    registering => 0.05,
    queued => 0.2,
    processing => 0.6,
    retryScheduled => 0.35,
    awaitingReview => 0.9,
    ready || failed => 1,
  };

  /// Whether no automatic state transition remains.
  bool get isTerminal =>
      this == awaitingReview || this == ready || this == failed;
}

/// Immutable UI-safe view of one durable ingestion job.
@immutable
final class DocumentProcessingView {
  /// Creates a processing view without exposing filesystem paths or contents.
  const DocumentProcessingView({
    required this.jobId,
    required this.documentId,
    required this.logicalFilename,
    required this.mimeType,
    required this.source,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.availableAfter,
    this.safeErrorCode,
    this.thumbnailObjectId,
  });

  /// Opaque durable job identifier.
  final String jobId;

  /// Opaque document identifier.
  final String documentId;

  /// User-visible logical filename, never an absolute path.
  final String logicalFilename;

  /// Validated media type.
  final String mimeType;

  /// Original import source.
  final DocumentImportSource source;

  /// Durable processing state.
  final DocumentProcessingStatus status;

  /// Number of worker claims so far.
  final int attemptCount;

  /// Durable creation time.
  final DateTime createdAt;

  /// Last durable transition time.
  final DateTime updatedAt;

  /// Earliest retry time when [status] is
  /// [DocumentProcessingStatus.retryScheduled].
  final DateTime? availableAfter;

  /// Stable non-sensitive error code for failed/retrying work.
  final String? safeErrorCode;

  /// Opaque derived thumbnail object identifier, when available.
  final String? thumbnailObjectId;
}
