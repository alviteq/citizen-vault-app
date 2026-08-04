/// Replaceable, bounded, offline OCR and deterministic intelligence contracts.
library;

export 'src/classification/deterministic_document_classifier.dart';
export 'src/extraction/deterministic_field_extractors.dart';
export 'src/lease/decrypted_asset_lease.dart';
export 'src/model/ocr_models.dart';
export 'src/serialization/ocr_result_codec.dart';

/// Package metadata for the Milestone 7 OCR boundary.
abstract final class VaultOcrPackage {
  /// Public API version.
  static const String apiVersion = '0.8.0';
}
