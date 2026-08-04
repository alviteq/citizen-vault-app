import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:vault_domain/vault_domain.dart';

/// Flattens and permanently redacts image/document bytes.
final class FlattenedRedactor {
  /// Creates a redactor.
  const FlattenedRedactor();

  /// Applies [options] redactions and watermark to [inputBytes].
  ///
  /// Returns flattened, non-layered image bytes with metadata stripped.
  Uint8List redactAndFlatten({
    required Uint8List inputBytes,
    required PrivacyExportOptions options,
    List<RedactionRect>? detectedFieldRects,
  }) {
    img.Image? image;
    try {
      image = img.decodeImage(inputBytes);
    } on Object {
      throw const UnsupportedRedactionInputFailure();
    }
    if (image == null) {
      throw const UnsupportedRedactionInputFailure();
    }

    final canvas = img.Image.from(image);
    final rectsToRedact = <RedactionRect>[...options.customRedactionRects];

    if (detectedFieldRects != null && detectedFieldRects.isNotEmpty) {
      if (options.redactIdNumbers ||
          options.redactAddress ||
          options.redactDateOfBirth ||
          options.redactQrBarcodes ||
          options.redactSignatures) {
        rectsToRedact.addAll(detectedFieldRects);
      }
    } else {
      if (options.redactIdNumbers) {
        rectsToRedact.add(
          const RedactionRect(left: 0.1, top: 0.2, width: 0.8, height: 0.08),
        );
      }
      if (options.redactAddress) {
        rectsToRedact.add(
          const RedactionRect(left: 0.1, top: 0.35, width: 0.8, height: 0.12),
        );
      }
      if (options.redactDateOfBirth) {
        rectsToRedact.add(
          const RedactionRect(left: 0.1, top: 0.5, width: 0.4, height: 0.06),
        );
      }
      if (options.redactSignatures) {
        rectsToRedact.add(
          const RedactionRect(left: 0.5, top: 0.75, width: 0.4, height: 0.15),
        );
      }
    }

    final black = img.ColorRgb8(0, 0, 0);
    for (final rect in rectsToRedact) {
      final x1 = (rect.left * canvas.width).round().clamp(0, canvas.width - 1);
      final y1 = (rect.top * canvas.height).round().clamp(0, canvas.height - 1);
      final x2 = ((rect.left + rect.width) * canvas.width).round().clamp(
        0,
        canvas.width,
      );
      final y2 = ((rect.top + rect.height) * canvas.height).round().clamp(
        0,
        canvas.height,
      );
      if (x2 > x1 && y2 > y1) {
        img.fillRect(
          canvas,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          color: black,
        );
      }
    }

    if (options.watermarkText.isNotEmpty) {
      final watermarkColor = img.ColorRgba8(220, 20, 20, 220);
      final bannerHeight = (canvas.height * 0.06).round().clamp(24, 60);
      img.fillRect(
        canvas,
        x1: 0,
        y1: canvas.height - bannerHeight,
        x2: canvas.width,
        y2: canvas.height,
        color: img.ColorRgba8(0, 0, 0, 180),
      );
      img.drawString(
        canvas,
        options.watermarkText,
        font: img.arial14,
        x: 12,
        y: canvas.height - bannerHeight + 6,
        color: watermarkColor,
      );
    }

    return Uint8List.fromList(img.encodePng(canvas));
  }
}

/// Raised when bytes cannot be decoded and therefore cannot be safely
/// flattened. Callers must never fall back to exporting the original bytes.
final class UnsupportedRedactionInputFailure implements Exception {
  /// Creates a stable, non-sensitive redaction failure.
  const UnsupportedRedactionInputFailure();

  @override
  String toString() => 'unsupported_redaction_input';
}
