import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:pdfrx/pdfrx.dart';
import 'package:vault_ocr/vault_ocr.dart';

/// Bundled native Latin-script provider.
///
/// Android uses ML Kit. Apple platforms use Vision through one private channel.
final class MlKitLatinOcrEngine implements OcrEngine {
  const MlKitLatinOcrEngine();

  static const _channel = MethodChannel('app.citizenvault/ocr');

  @override
  String get engineId => 'google-mlkit-text-recognition-latin-bundled';

  @override
  String get engineVersion => '16.0.1';

  @override
  Future<OcrCapabilities> capabilities() async => OcrCapabilities(
    supportedMimeTypes: const <String>{
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/bmp',
      'image/heic',
      'image/heif',
      'application/pdf',
      'text/plain',
      'text/csv',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    },
    supportedScripts: const <String>{'Latn'},
    supportedLanguages: const <String>{'en'},
    supportsLayout: false,
    supportsTables: false,
  );

  @override
  Future<OcrResult> recognize(OcrRequest request) async {
    request.cancellation.throwIfCancelled();
    if (!Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isMacOS &&
        !Platform.isWindows &&
        !Platform.isLinux) {
      throw const OcrFailure('ocr_provider_unavailable', transient: false);
    }
    try {
      final language = request.preferredLanguages.firstOrNull ?? 'en';
      final rawText = await request.input.usePrivatePath(
        (path) => switch (request.mimeType.toLowerCase()) {
          'application/pdf' => _recognizePdf(
            path,
            language,
            request.cancellation,
          ),
          'text/plain' || 'text/csv' => File(path).readAsString(),
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
          'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
            _recognizeOpenXml(path, request.mimeType),
          _ => _recognizeImage(path, language),
        },
      );
      request.cancellation.throwIfCancelled();
      return OcrResult(
        engineId: engineId,
        engineVersion: engineVersion,
        detectedLanguages: const <String>[],
        detectedScripts: const <String>['Latn'],
        pages: const <OcrPage>[],
        warnings: const <String>[],
        rawText: rawText,
      );
    } on OcrFailure {
      rethrow;
    } on PlatformException catch (error) {
      final invalid = error.code == 'INVALID_SOURCE';
      throw OcrFailure(
        invalid ? 'ocr_source_unsupported' : 'ocr_provider_unavailable',
        transient: !invalid,
        cause: error,
      );
    } on Object catch (error) {
      throw OcrFailure(
        'ocr_recognition_failed',
        transient: false,
        cause: error,
      );
    }
  }

  Future<String> _recognizePdf(
    String path,
    String language,
    OcrCancellationSignal cancellation,
  ) async {
    PdfDocument? document;
    Directory? temporary;
    try {
      document = await PdfDocument.openFile(path);
      if (document.pages.isEmpty) return '';
      if (document.pages.length > 100) {
        throw const OcrFailure('pdf_page_limit_exceeded', transient: false);
      }
      temporary = await Directory.systemTemp.createTemp('ownkeep_pdf_ocr_');
      final output = <String>[];
      for (final page in document.pages) {
        cancellation.throwIfCancelled();
        final embedded = await page.loadText();
        final embeddedText = embedded?.fullText.trim() ?? '';
        if (embeddedText.length >= 120) {
          output.add(embeddedText);
          continue;
        }

        final longest = page.width >= page.height ? page.width : page.height;
        final scale = 1800 / longest;
        final width = (page.width * scale).round().clamp(1, 2400);
        final height = (page.height * scale).round().clamp(1, 2400);
        final rendered = await page.render(
          fullWidth: width.toDouble(),
          fullHeight: height.toDouble(),
          backgroundColor: 0xffffffff,
        );
        if (rendered == null) continue;
        try {
          final decoded = image.Image.fromBytes(
            width: rendered.width,
            height: rendered.height,
            bytes: rendered.pixels.buffer,
            numChannels: 4,
            order: image.ChannelOrder.bgra,
          );
          final pageFile = File(
            '${temporary.path}/page-${page.pageNumber}.jpg',
          );
          await pageFile.writeAsBytes(
            image.encodeJpg(decoded, quality: 92),
            flush: true,
          );
          final recognized = await _recognizeImage(pageFile.path, language);
          final pageText = <String>{
            if (embeddedText.isNotEmpty) embeddedText,
            if (recognized.trim().isNotEmpty) recognized.trim(),
          }.join('\n');
          if (pageText.isNotEmpty) output.add(pageText);
        } finally {
          rendered.dispose();
        }
      }
      return output.join('\n\n');
    } on OcrFailure {
      rethrow;
    } on Object catch (error) {
      throw OcrFailure('pdf_ocr_failed', transient: false, cause: error);
    } finally {
      await document?.dispose();
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  Future<String> _recognizeImage(String path, String language) async =>
      await _channel.invokeMethod<String>('recognizeText', <String, String>{
        'path': path,
        'language': language,
      }) ??
      '';

  Future<String> _recognizeOpenXml(String path, String mimeType) async {
    try {
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final prefixes = switch (mimeType.toLowerCase()) {
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
          const <String>['word/document.xml', 'word/header', 'word/footer'],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
          const <String>['xl/sharedStrings.xml', 'xl/worksheets/sheet'],
        _ => const <String>['ppt/slides/slide', 'ppt/notesSlides/notesSlide'],
      };
      final files =
          archive.files
              .where(
                (entry) =>
                    entry.isFile &&
                    entry.name.endsWith('.xml') &&
                    prefixes.any(entry.name.startsWith),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final output = <String>[];
      for (final entry in files) {
        final xml = String.fromCharCodes(entry.content as List<int>);
        final text = xml
            .replaceAll(RegExp(r'<w:tab\s*/>'), '\t')
            .replaceAll(RegExp(r'</(?:w:p|a:p|row)>'), '\n')
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&apos;', "'")
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .replaceAll(RegExp(r'\n\s+'), '\n')
            .trim();
        if (text.isNotEmpty) output.add(text);
      }
      return output.join('\n');
    } on Object catch (error) {
      throw OcrFailure(
        'office_text_extraction_failed',
        transient: false,
        cause: error,
      );
    }
  }
}
