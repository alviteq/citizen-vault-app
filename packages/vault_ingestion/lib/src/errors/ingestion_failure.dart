/// Whether a processing failure may be retried automatically.
enum IngestionFailureDisposition {
  /// Retry according to the bounded backoff policy.
  transient,

  /// Do not retry without a new user action or implementation change.
  permanent,
}

/// Safe ingestion failure that never includes paths, content, or credentials.
class IngestionFailure implements Exception {
  /// Creates a classified failure.
  const IngestionFailure({
    required this.code,
    required this.disposition,
    this.cause,
  });

  /// Stable non-sensitive code suitable for persistence and UI mapping.
  final String code;

  /// Retry classification.
  final IngestionFailureDisposition disposition;

  /// In-memory cause for diagnostics; never persist or show directly.
  final Object? cause;

  @override
  String toString() => 'IngestionFailure($code)';
}

/// The selected source violates import policy.
final class InvalidImportFailure extends IngestionFailure {
  /// Creates a permanent invalid-source failure.
  const InvalidImportFailure(String code, {super.cause})
    : super(
        code: code,
        disposition: IngestionFailureDisposition.permanent,
      );
}

/// A durable job lease was lost or belongs to another worker.
final class IngestionLeaseFailure extends IngestionFailure {
  /// Creates a transient lease failure.
  const IngestionLeaseFailure({super.cause})
    : super(
        code: 'job_lease_lost',
        disposition: IngestionFailureDisposition.transient,
      );
}

/// Thumbnail decoding or production cannot support the image.
final class ThumbnailFailure extends IngestionFailure {
  /// Creates a classified thumbnail failure.
  const ThumbnailFailure({
    required super.code,
    required super.disposition,
    super.cause,
  });
}
