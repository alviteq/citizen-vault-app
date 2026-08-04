import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:vault_ingestion/src/errors/ingestion_failure.dart';
import 'package:vault_ingestion/src/model/ingestion_models.dart';

/// Replaceable image preprocessing boundary for derived thumbnails.
// The interface remains injectable for platform or future pipeline variants.
// ignore: one_member_abstracts
abstract interface class ThumbnailGenerator {
  /// Generates metadata-stripped derived JPEG bytes.
  Future<GeneratedThumbnail> generate(
    Uint8List original,
    IngestionLimits limits,
  );
}

/// Pure-Dart thumbnail generation isolated from the UI thread.
final class IsolateThumbnailGenerator implements ThumbnailGenerator {
  /// Creates the default thumbnail generator.
  const IsolateThumbnailGenerator();

  @override
  Future<GeneratedThumbnail> generate(
    Uint8List original,
    IngestionLimits limits,
  ) async {
    if (original.isEmpty || original.length > limits.maximumImageBytes) {
      throw const ThumbnailFailure(
        code: 'image_size_unsupported',
        disposition: IngestionFailureDisposition.permanent,
      );
    }
    try {
      final result = await Isolate.run(
        () => _generateThumbnail(
          original,
          limits.maximumImagePixels,
          limits.thumbnailLongestEdge,
          limits.thumbnailJpegQuality,
        ),
      );
      final failureCode = result.failureCode;
      if (failureCode != null) {
        throw ThumbnailFailure(
          code: failureCode,
          disposition: IngestionFailureDisposition.permanent,
        );
      }
      return GeneratedThumbnail(
        bytes: result.bytes!,
        width: result.width!,
        height: result.height!,
      );
    } on IngestionFailure {
      rethrow;
    } on Object catch (error) {
      throw ThumbnailFailure(
        code: 'thumbnail_generation_failed',
        disposition: IngestionFailureDisposition.transient,
        cause: error,
      );
    }
  }
}

({
  Uint8List? bytes,
  int? width,
  int? height,
  String? failureCode,
})
_generateThumbnail(
  Uint8List bytes,
  int maximumPixels,
  int longestEdge,
  int jpegQuality,
) {
  image.Image? decoded;
  try {
    decoded = image.decodeImage(bytes);
  } on Object {
    return (
      bytes: null,
      width: null,
      height: null,
      failureCode: 'image_format_unsupported',
    );
  }
  if (decoded == null) {
    return (
      bytes: null,
      width: null,
      height: null,
      failureCode: 'image_format_unsupported',
    );
  }
  if (decoded.width * decoded.height > maximumPixels) {
    return (
      bytes: null,
      width: null,
      height: null,
      failureCode: 'image_dimensions_unsupported',
    );
  }
  final oriented = image.bakeOrientation(decoded);
  final resized = oriented.width >= oriented.height
      ? image.copyResize(oriented, width: longestEdge)
      : image.copyResize(oriented, height: longestEdge);
  final encoded = image.encodeJpg(resized, quality: jpegQuality);
  return (
    bytes: encoded,
    width: resized.width,
    height: resized.height,
    failureCode: null,
  );
}
