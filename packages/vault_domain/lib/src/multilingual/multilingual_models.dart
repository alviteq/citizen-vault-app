import 'package:meta/meta.dart';

/// Supported regional languages in OwnKeep.
enum SupportedLanguage {
  /// English (Default)
  english('en', 'English'),

  /// Hindi
  hindi('hi', 'हिन्दी (Hindi)'),

  /// Telugu
  telugu('te', 'తెలుగు (Telugu)'),

  /// Tamil
  tamil('ta', 'தமிழ் (Tamil)'),

  /// Kannada
  kannada('kn', 'கன்னட (Kannada)'),

  /// Malayalam
  malayalam('ml', 'മലയാളം (Malayalam)'),

  /// Marathi
  marathi('mr', 'मराठी (Marathi)'),

  /// Bengali
  bengali('bn', 'বাংলা (Bengali)');

  const SupportedLanguage(this.code, this.displayName);

  /// ISO language code.
  final String code;

  /// Human readable display name.
  final String displayName;
}

/// OCR language pack tracking separate from UI locale.
@immutable
final class OcrLanguageTrack {
  /// Creates an OCR language track entry.
  const OcrLanguageTrack({
    required this.code,
    required this.displayName,
    this.isInstalled = true,
  });

  /// Language ISO code.
  final String code;

  /// Display name.
  final String displayName;

  /// Whether local OCR model pack is installed.
  final bool isInstalled;
}

/// Language preferences state.
@immutable
final class LanguagePreferences {
  /// Creates language preferences.
  const LanguagePreferences({
    this.uiLanguage = SupportedLanguage.english,
    this.ocrLanguage = 'en',
  });

  /// Active UI localization language.
  final SupportedLanguage uiLanguage;

  /// Active OCR language pack code.
  final String ocrLanguage;
}
