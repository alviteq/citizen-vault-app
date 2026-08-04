import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:pdfrx/pdfrx.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

/// Generates image thumbnails normally and renders the first page of PDFs.
final class PdfAwareThumbnailGenerator implements ThumbnailGenerator {
  const PdfAwareThumbnailGenerator();

  static const _images = IsolateThumbnailGenerator();

  @override
  Future<GeneratedThumbnail> generate(
    Uint8List original,
    IngestionLimits limits,
  ) async {
    if (!_isPdf(original)) return _images.generate(original, limits);
    if (original.isEmpty || original.length > limits.maximumFileBytes) {
      throw const ThumbnailFailure(
        code: 'pdf_size_unsupported',
        disposition: IngestionFailureDisposition.permanent,
      );
    }

    PdfDocument? document;
    PdfImage? rendered;
    try {
      document = await PdfDocument.openData(
        original,
        sourceName: 'ownkeep-thumbnail',
      );
      if (document.pages.isEmpty) {
        throw const ThumbnailFailure(
          code: 'pdf_has_no_pages',
          disposition: IngestionFailureDisposition.permanent,
        );
      }
      final page = document.pages.first;
      final scale =
          limits.thumbnailLongestEdge /
          (page.width >= page.height ? page.width : page.height);
      final width = (page.width * scale).round().clamp(1, 2048);
      final height = (page.height * scale).round().clamp(1, 2048);
      rendered = await page.render(
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        backgroundColor: 0xffffffff,
      );
      if (rendered == null) {
        throw const ThumbnailFailure(
          code: 'pdf_render_failed',
          disposition: IngestionFailureDisposition.transient,
        );
      }
      final decoded = image.Image.fromBytes(
        width: rendered.width,
        height: rendered.height,
        bytes: rendered.pixels.buffer,
        numChannels: 4,
        order: image.ChannelOrder.bgra,
      );
      return GeneratedThumbnail(
        bytes: image.encodeJpg(decoded, quality: limits.thumbnailJpegQuality),
        width: rendered.width,
        height: rendered.height,
      );
    } on IngestionFailure {
      rethrow;
    } on Object catch (error) {
      throw ThumbnailFailure(
        code: 'pdf_render_failed',
        disposition: IngestionFailureDisposition.permanent,
        cause: error,
      );
    } finally {
      rendered?.dispose();
      await document?.dispose();
    }
  }

  static bool _isPdf(Uint8List bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46 &&
      bytes[4] == 0x2d;
}
