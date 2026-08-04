import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('FlattenedRedactor', () {
    late Uint8List testImageBytes;

    setUp(() {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.fillRect(
        image,
        x1: 20,
        y1: 20,
        x2: 80,
        y2: 80,
        color: img.ColorRgb8(255, 0, 0),
      );
      testImageBytes = Uint8List.fromList(img.encodePng(image));
    });

    test('redacts region and burns watermark without mutating original', () {
      const redactor = FlattenedRedactor();
      final options = PrivacyExportOptions.defaultFor(
        recipient: 'HDFC Bank',
        purpose: 'Loan Application',
        date: DateTime.utc(2026, 7, 26),
      );

      final originalCopy = Uint8List.fromList(testImageBytes);

      final outputBytes = redactor.redactAndFlatten(
        inputBytes: testImageBytes,
        options: options,
        detectedFieldRects: const [
          RedactionRect(left: 0.2, top: 0.2, width: 0.6, height: 0.6),
        ],
      );

      expect(outputBytes, isNotEmpty);
      expect(testImageBytes, equals(originalCopy));

      final decodedOutput = img.decodeImage(outputBytes);
      expect(decodedOutput, isNotNull);

      final pixel = decodedOutput!.getPixel(50, 50);
      expect(pixel.r, equals(0));
      expect(pixel.g, equals(0));
      expect(pixel.b, equals(0));
    });

    test('applies custom redaction rects correctly', () {
      const redactor = FlattenedRedactor();
      const options = PrivacyExportOptions(
        recipient: 'Landlord',
        purpose: 'Rental Agreement',
        watermarkText: 'FOR LANDLORD - RENTAL - 2026-07-26',
        customRedactionRects: [
          RedactionRect(left: 0, top: 0, width: 0.5, height: 0.5),
        ],
      );

      final outputBytes = redactor.redactAndFlatten(
        inputBytes: testImageBytes,
        options: options,
      );

      final decodedOutput = img.decodeImage(outputBytes)!;
      final topLeftPixel = decodedOutput.getPixel(10, 10);
      expect(topLeftPixel.r, equals(0));
      expect(topLeftPixel.g, equals(0));
      expect(topLeftPixel.b, equals(0));
    });

    test('fails closed when source bytes cannot be flattened', () {
      const redactor = FlattenedRedactor();
      const options = PrivacyExportOptions(
        recipient: 'Recipient',
        purpose: 'Verification',
        watermarkText: 'PRIVATE COPY',
      );
      final undecodable = Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46]);

      expect(
        () => redactor.redactAndFlatten(
          inputBytes: undecodable,
          options: options,
        ),
        throwsA(isA<UnsupportedRedactionInputFailure>()),
      );
      expect(undecodable, <int>[0x25, 0x50, 0x44, 0x46]);
    });
  });
}
