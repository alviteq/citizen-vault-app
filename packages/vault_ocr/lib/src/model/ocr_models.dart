// Immutable OCR value fields are documented by their containing model.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';

/// Co-operative cancellation checked around OCR boundaries.
final class OcrCancellationSignal {
  var _cancelled = false;

  /// Whether cancellation was requested.
  bool get isCancelled => _cancelled;

  /// Requests cancellation without racing platform resource cleanup.
  void cancel() => _cancelled = true;

  /// Throws a stable cancellation failure.
  void throwIfCancelled() {
    if (_cancelled) throw const OcrFailure('ocr_cancelled', transient: false);
  }
}

/// Safe OCR failure classification.
final class OcrFailure implements Exception {
  /// Creates a non-sensitive provider failure.
  const OcrFailure(this.code, {required this.transient, this.cause});

  final String code;
  final bool transient;
  final Object? cause;
}

/// Capabilities claimed by one tested provider configuration.
@immutable
final class OcrCapabilities {
  /// Creates provider capabilities.
  OcrCapabilities({
    required Set<String> supportedMimeTypes,
    required Set<String> supportedScripts,
    required Set<String> supportedLanguages,
    required this.supportsLayout,
    required this.supportsTables,
  }) : supportedMimeTypes = Set.unmodifiable(supportedMimeTypes),
       supportedScripts = Set.unmodifiable(supportedScripts),
       supportedLanguages = Set.unmodifiable(supportedLanguages);

  final Set<String> supportedMimeTypes;
  final Set<String> supportedScripts;
  final Set<String> supportedLanguages;
  final bool supportsLayout;
  final bool supportsTables;

  /// Whether this provider can process the validated original MIME type.
  bool supportsMimeType(String mimeType) =>
      supportedMimeTypes.contains(mimeType.toLowerCase());
}

/// Narrow access to one app-private decrypted input.
// The lease prevents wider plaintext-path exposure by design.
// ignore: one_member_abstracts
abstract interface class DecryptedAssetInput {
  /// Runs [action] while this live lease owns the opaque private file.
  Future<T> usePrivatePath<T>(Future<T> Function(String path) action);
}

/// Input for one OCR attempt.
@immutable
final class OcrRequest {
  /// Creates a request without exposing an arbitrary plaintext path.
  const OcrRequest({
    required this.encryptedAssetReference,
    required this.input,
    required this.mimeType,
    required this.preferredLanguages,
    required this.preferredScripts,
    required this.detectLayout,
    required this.detectTables,
    required this.cancellation,
  });

  final String encryptedAssetReference;
  final DecryptedAssetInput input;
  final String mimeType;
  final List<String> preferredLanguages;
  final List<String> preferredScripts;
  final bool detectLayout;
  final bool detectTables;
  final OcrCancellationSignal cancellation;
}

/// Replaceable OCR provider contract.
abstract interface class OcrEngine {
  String get engineId;
  String get engineVersion;
  Future<OcrCapabilities> capabilities();
  Future<OcrResult> recognize(OcrRequest request);
}

/// Honest default for compositions that have no tested native OCR provider.
final class DisabledOcrEngine implements OcrEngine {
  /// Creates the disabled provider.
  const DisabledOcrEngine();

  @override
  String get engineId => 'ocr-disabled';

  @override
  String get engineVersion => '1';

  @override
  Future<OcrCapabilities> capabilities() async => OcrCapabilities(
    supportedMimeTypes: const <String>{},
    supportedScripts: const <String>{},
    supportedLanguages: const <String>{},
    supportsLayout: false,
    supportsTables: false,
  );

  @override
  Future<OcrResult> recognize(OcrRequest request) {
    throw const OcrFailure('ocr_provider_disabled', transient: false);
  }
}

/// Pixel coordinate supplied by an OCR engine.
@immutable
final class OcrPoint {
  /// Creates one finite point.
  const OcrPoint(this.x, this.y);

  final double x;
  final double y;
}

/// Ordered polygon around a recognized item.
@immutable
final class OcrPolygon {
  /// Creates a bounded polygon.
  OcrPolygon(List<OcrPoint> points) : points = List.unmodifiable(points) {
    if (this.points.length < 2 || this.points.length > 8) {
      throw ArgumentError.value(points.length, 'points');
    }
  }

  final List<OcrPoint> points;
}

/// One recognized word or word-like element.
@immutable
final class OcrWord {
  /// Creates a word.
  const OcrWord({
    required this.id,
    required this.text,
    this.polygon,
    this.rotationDegrees,
    this.confidence,
    this.languageCode,
  });

  final String id;
  final String text;
  final OcrPolygon? polygon;
  final double? rotationDegrees;
  final double? confidence;
  final String? languageCode;
}

/// One OCR line.
@immutable
final class OcrLine {
  /// Creates a line and its words.
  OcrLine({
    required this.id,
    required this.text,
    required List<OcrWord> words,
    this.polygon,
    this.rotationDegrees,
    this.confidence,
    this.languageCode,
  }) : words = List.unmodifiable(words);

  final String id;
  final String text;
  final List<OcrWord> words;
  final OcrPolygon? polygon;
  final double? rotationDegrees;
  final double? confidence;
  final String? languageCode;
}

/// One OCR block.
@immutable
final class OcrBlock {
  /// Creates a block and its lines.
  OcrBlock({
    required this.id,
    required this.text,
    required List<OcrLine> lines,
    this.polygon,
    this.languageCode,
  }) : lines = List.unmodifiable(lines);

  final String id;
  final String text;
  final List<OcrLine> lines;
  final OcrPolygon? polygon;
  final String? languageCode;
}

/// One page of recognized layout.
@immutable
final class OcrPage {
  /// Creates a page.
  OcrPage({
    required this.pageNumber,
    required List<OcrBlock> blocks,
    this.width,
    this.height,
    this.rotationDegrees = 0,
  }) : blocks = List.unmodifiable(blocks);

  final int pageNumber;
  final int? width;
  final int? height;
  final double rotationDegrees;
  final List<OcrBlock> blocks;

  /// Page text in reading order.
  String get text => blocks.map((block) => block.text).join('\n');
}

/// Complete bounded OCR result.
@immutable
final class OcrResult {
  /// Creates an OCR result.
  OcrResult({
    required this.engineId,
    required this.engineVersion,
    required List<String> detectedLanguages,
    required List<String> detectedScripts,
    required List<OcrPage> pages,
    required List<String> warnings,
    required this.rawText,
  }) : detectedLanguages = List.unmodifiable(detectedLanguages),
       detectedScripts = List.unmodifiable(detectedScripts),
       pages = List.unmodifiable(pages),
       warnings = List.unmodifiable(warnings);

  /// Creates an intentionally empty result for an unsupported source type.
  factory OcrResult.empty({
    required String engineId,
    required String engineVersion,
    String warning = 'ocr_not_supported_for_source',
  }) => OcrResult(
    engineId: engineId,
    engineVersion: engineVersion,
    detectedLanguages: const <String>[],
    detectedScripts: const <String>[],
    pages: const <OcrPage>[],
    warnings: <String>[warning],
    rawText: '',
  );

  final String engineId;
  final String engineVersion;
  final List<String> detectedLanguages;
  final List<String> detectedScripts;
  final List<OcrPage> pages;
  final List<String> warnings;
  final String rawText;

  /// Finds the smallest layout item containing [match] on a page.
  ({int page, String blockId})? locate(String match) {
    final normalized = match.toLowerCase();
    for (final page in pages) {
      for (final block in page.blocks) {
        for (final line in block.lines) {
          if (line.text.toLowerCase().contains(normalized)) {
            return (page: page.pageNumber, blockId: line.id);
          }
        }
        if (block.text.toLowerCase().contains(normalized)) {
          return (page: page.pageNumber, blockId: block.id);
        }
      }
    }
    return null;
  }
}
