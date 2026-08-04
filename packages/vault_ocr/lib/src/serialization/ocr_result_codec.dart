import 'dart:convert';
import 'dart:typed_data';

import 'package:vault_ocr/src/model/ocr_models.dart';

/// Bounded versioned JSON codec stored only inside encrypted object storage.
abstract final class OcrResultCodec {
  /// Current layout format version.
  static const int formatVersion = 1;

  /// Maximum encrypted-layout plaintext accepted by the decoder.
  static const int maximumBytes = 8 * 1024 * 1024;

  /// Encodes the complete OCR layout.
  static Uint8List encode(OcrResult result) {
    final bytes = utf8.encode(
      jsonEncode(<String, Object>{
        'format_version': formatVersion,
        'engine_id': result.engineId,
        'engine_version': result.engineVersion,
        'detected_languages': result.detectedLanguages,
        'detected_scripts': result.detectedScripts,
        'warnings': result.warnings,
        'raw_text': result.rawText,
        'pages': result.pages.map(_pageToJson).toList(growable: false),
      }),
    );
    if (bytes.length > maximumBytes) {
      throw const OcrFailure('ocr_layout_too_large', transient: false);
    }
    return Uint8List.fromList(bytes);
  }

  /// Decodes an authenticated layout with allocation bounds.
  static OcrResult decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maximumBytes) {
      throw const OcrFailure('ocr_layout_invalid', transient: false);
    }
    try {
      final root = jsonDecode(utf8.decode(bytes));
      if (root is! Map<String, Object?> ||
          root['format_version'] != formatVersion) {
        throw const FormatException('root');
      }
      final pagesJson = _list(root, 'pages', maximum: 1000);
      return OcrResult(
        engineId: _string(root, 'engine_id', maximum: 128),
        engineVersion: _string(root, 'engine_version', maximum: 64),
        detectedLanguages: _strings(
          root,
          'detected_languages',
          maximumItems: 64,
        ),
        detectedScripts: _strings(
          root,
          'detected_scripts',
          maximumItems: 32,
        ),
        warnings: _strings(root, 'warnings', maximumItems: 64),
        rawText: _string(root, 'raw_text', maximum: 4 * 1024 * 1024),
        pages: pagesJson
            .map((value) => _page(_map(value)))
            .toList(growable: false),
      );
    } on OcrFailure {
      rethrow;
    } on Object catch (error) {
      throw OcrFailure('ocr_layout_invalid', transient: false, cause: error);
    }
  }

  static Map<String, Object> _pageToJson(OcrPage page) => <String, Object>{
    'page_number': page.pageNumber,
    if (page.width != null) 'width': page.width!,
    if (page.height != null) 'height': page.height!,
    'rotation': page.rotationDegrees,
    'blocks': page.blocks.map(_blockToJson).toList(growable: false),
  };

  static Map<String, Object> _blockToJson(OcrBlock block) => <String, Object>{
    'id': block.id,
    'text': block.text,
    if (block.languageCode != null) 'language': block.languageCode!,
    if (block.polygon != null) 'polygon': _polygonToJson(block.polygon!),
    'lines': block.lines.map(_lineToJson).toList(growable: false),
  };

  static Map<String, Object> _lineToJson(OcrLine line) => <String, Object>{
    'id': line.id,
    'text': line.text,
    if (line.languageCode != null) 'language': line.languageCode!,
    if (line.rotationDegrees != null) 'rotation': line.rotationDegrees!,
    if (line.confidence != null) 'confidence': line.confidence!,
    if (line.polygon != null) 'polygon': _polygonToJson(line.polygon!),
    'words': line.words.map(_wordToJson).toList(growable: false),
  };

  static Map<String, Object> _wordToJson(OcrWord word) => <String, Object>{
    'id': word.id,
    'text': word.text,
    if (word.languageCode != null) 'language': word.languageCode!,
    if (word.rotationDegrees != null) 'rotation': word.rotationDegrees!,
    if (word.confidence != null) 'confidence': word.confidence!,
    if (word.polygon != null) 'polygon': _polygonToJson(word.polygon!),
  };

  static List<List<double>> _polygonToJson(OcrPolygon polygon) => polygon.points
      .map((point) => <double>[point.x, point.y])
      .toList(growable: false);

  static OcrPage _page(Map<String, Object?> json) => OcrPage(
    pageNumber: _integer(json, 'page_number', minimum: 1, maximum: 1000),
    width: _optionalInteger(json, 'width', minimum: 1, maximum: 100000),
    height: _optionalInteger(json, 'height', minimum: 1, maximum: 100000),
    rotationDegrees: _number(json, 'rotation', minimum: -360, maximum: 360),
    blocks: _list(
      json,
      'blocks',
      maximum: 10000,
    ).map((value) => _block(_map(value))).toList(growable: false),
  );

  static OcrBlock _block(Map<String, Object?> json) => OcrBlock(
    id: _string(json, 'id', maximum: 128),
    text: _string(json, 'text', maximum: 1024 * 1024),
    languageCode: _optionalString(json, 'language', maximum: 32),
    polygon: _optionalPolygon(json),
    lines: _list(
      json,
      'lines',
      maximum: 10000,
    ).map((value) => _line(_map(value))).toList(growable: false),
  );

  static OcrLine _line(Map<String, Object?> json) => OcrLine(
    id: _string(json, 'id', maximum: 128),
    text: _string(json, 'text', maximum: 256 * 1024),
    languageCode: _optionalString(json, 'language', maximum: 32),
    rotationDegrees: _optionalNumber(
      json,
      'rotation',
      minimum: -360,
      maximum: 360,
    ),
    confidence: _optionalNumber(
      json,
      'confidence',
      minimum: 0,
      maximum: 1,
    ),
    polygon: _optionalPolygon(json),
    words: _list(
      json,
      'words',
      maximum: 10000,
    ).map((value) => _word(_map(value))).toList(growable: false),
  );

  static OcrWord _word(Map<String, Object?> json) => OcrWord(
    id: _string(json, 'id', maximum: 128),
    text: _string(json, 'text', maximum: 65536),
    languageCode: _optionalString(json, 'language', maximum: 32),
    rotationDegrees: _optionalNumber(
      json,
      'rotation',
      minimum: -360,
      maximum: 360,
    ),
    confidence: _optionalNumber(
      json,
      'confidence',
      minimum: 0,
      maximum: 1,
    ),
    polygon: _optionalPolygon(json),
  );

  static OcrPolygon? _optionalPolygon(Map<String, Object?> json) {
    final value = json['polygon'];
    if (value == null) return null;
    if (value is! List<Object?> || value.length < 2 || value.length > 8) {
      throw const FormatException('polygon');
    }
    return OcrPolygon(
      value
          .map((point) {
            if (point is! List<Object?> || point.length != 2) {
              throw const FormatException('point');
            }
            final x = point[0];
            final y = point[1];
            if (x is! num || y is! num || !x.isFinite || !y.isFinite) {
              throw const FormatException('point coordinate');
            }
            return OcrPoint(x.toDouble(), y.toDouble());
          })
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw const FormatException('map');
  }

  static List<Object?> _list(
    Map<String, Object?> json,
    String key, {
    required int maximum,
  }) {
    final value = json[key];
    if (value is! List<Object?> || value.length > maximum) {
      throw FormatException(key);
    }
    return value;
  }

  static List<String> _strings(
    Map<String, Object?> json,
    String key, {
    required int maximumItems,
  }) => _list(json, key, maximum: maximumItems)
      .map((value) {
        if (value is! String || value.length > 128) {
          throw FormatException(key);
        }
        return value;
      })
      .toList(growable: false);

  static String _string(
    Map<String, Object?> json,
    String key, {
    required int maximum,
  }) {
    final value = json[key];
    if (value is! String || value.length > maximum) {
      throw FormatException(key);
    }
    return value;
  }

  static String? _optionalString(
    Map<String, Object?> json,
    String key, {
    required int maximum,
  }) {
    if (json[key] == null) return null;
    return _string(json, key, maximum: maximum);
  }

  static int _integer(
    Map<String, Object?> json,
    String key, {
    required int minimum,
    required int maximum,
  }) {
    final value = json[key];
    if (value is! int || value < minimum || value > maximum) {
      throw FormatException(key);
    }
    return value;
  }

  static int? _optionalInteger(
    Map<String, Object?> json,
    String key, {
    required int minimum,
    required int maximum,
  }) {
    if (json[key] == null) return null;
    return _integer(json, key, minimum: minimum, maximum: maximum);
  }

  static double _number(
    Map<String, Object?> json,
    String key, {
    required double minimum,
    required double maximum,
  }) {
    final value = json[key];
    if (value is! num ||
        !value.isFinite ||
        value < minimum ||
        value > maximum) {
      throw FormatException(key);
    }
    return value.toDouble();
  }

  static double? _optionalNumber(
    Map<String, Object?> json,
    String key, {
    required double minimum,
    required double maximum,
  }) {
    if (json[key] == null) return null;
    return _number(json, key, minimum: minimum, maximum: maximum);
  }
}
