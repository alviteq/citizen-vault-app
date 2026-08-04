import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_objects/vault_objects.dart';

/// Re-openable selected source consumed synchronously into encrypted storage.
@immutable
final class IngestionCandidate {
  /// Creates a candidate from validated metadata and a fresh-stream factory.
  const IngestionCandidate({
    required this.logicalFilename,
    required this.mimeType,
    required this.length,
    required this.source,
    required this.openRead,
  });

  /// Display filename only; must not contain a path.
  final String logicalFilename;

  /// Claimed media type checked against the allowed import set.
  final String mimeType;

  /// Declared source length.
  final int length;

  /// Picker/capture source.
  final DocumentImportSource source;

  /// Opens a fresh bounded stream. Absolute source paths are never persisted.
  final Stream<List<int>> Function() openRead;
}

/// Resource and format limits applied before expensive processing.
@immutable
final class IngestionLimits {
  /// Creates reviewed low-spec-device defaults.
  const IngestionLimits({
    this.maximumFileBytes = 512 * 1024 * 1024,
    this.maximumImageBytes = 32 * 1024 * 1024,
    this.maximumImagePixels = 40 * 1000 * 1000,
    this.thumbnailLongestEdge = 384,
    this.thumbnailJpegQuality = 82,
  });

  /// Maximum original size accepted by the ingestion boundary.
  final int maximumFileBytes;

  /// Maximum image size decoded for thumbnail generation.
  final int maximumImageBytes;

  /// Maximum decoded source pixel count.
  final int maximumImagePixels;

  /// Longest thumbnail edge.
  final int thumbnailLongestEdge;

  /// Derived JPEG quality from 1 through 100.
  final int thumbnailJpegQuality;
}

/// A worker-owned durable job lease.
@immutable
final class IngestionJobLease {
  /// Creates a claimed job.
  const IngestionJobLease({
    required this.jobId,
    required this.documentId,
    required this.originalObjectId,
    required this.logicalFilename,
    required this.mimeType,
    required this.workerId,
    required this.attemptCount,
    required this.leaseExpiresAt,
  });

  /// Opaque job identifier.
  final String jobId;

  /// Opaque document identifier.
  final String documentId;

  /// Immutable encrypted original object.
  final ObjectId originalObjectId;

  /// User-visible filename without a physical path.
  final String logicalFilename;

  /// Validated original media type.
  final String mimeType;

  /// Current lease owner.
  final String workerId;

  /// Claim count including this lease.
  final int attemptCount;

  /// Time after which another worker may reclaim the job.
  final DateTime leaseExpiresAt;

  /// Whether an image thumbnail is part of Milestone 6 processing.
  bool get requiresThumbnail => const <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/bmp',
    'image/tiff',
    'application/pdf',
  }.contains(mimeType);
}

/// Output of a successful thumbnail transform.
@immutable
final class GeneratedThumbnail {
  /// Creates JPEG thumbnail bytes with validated dimensions.
  GeneratedThumbnail({
    required List<int> bytes,
    required this.width,
    required this.height,
  }) : bytes = Uint8List.fromList(bytes);

  /// JPEG bytes with source metadata removed by re-encoding.
  final Uint8List bytes;

  /// Derived pixel width.
  final int width;

  /// Derived pixel height.
  final int height;
}

/// Result returned immediately after original registration is durable.
@immutable
final class IngestionRegistration {
  /// Creates a registration result.
  const IngestionRegistration({
    required this.documentId,
    required this.jobId,
    required this.originalObjectId,
  });

  /// Opaque document identifier.
  final String documentId;

  /// Opaque durable job identifier.
  final String jobId;

  /// Opaque immutable original object identifier.
  final ObjectId originalObjectId;
}
