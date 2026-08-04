import 'package:meta/meta.dart';

/// Normalized 2D bounding rectangle for document redactions (0.0 to 1.0).
@immutable
final class RedactionRect {
  /// Creates a normalized redaction bounding box.
  const RedactionRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Left coordinate (0.0 to 1.0).
  final double left;

  /// Top coordinate (0.0 to 1.0).
  final double top;

  /// Width (0.0 to 1.0).
  final double width;

  /// Height (0.0 to 1.0).
  final double height;
}

/// Target categories for automatic and manual redaction masks.
enum RedactionTargetCategory {
  /// Identification numbers (Aadhaar, PAN, Passport, Driving Licence, SSN).
  idNumber('ID numbers'),

  /// Residential or mailing addresses.
  address('Address'),

  /// Date of birth.
  dateOfBirth('Date of birth'),

  /// QR codes and barcodes.
  qrAndBarcode('QR / Barcode'),

  /// Hand-written or electronic signatures.
  signature('Signature');

  const RedactionTargetCategory(this.displayName);

  /// User-visible label.
  final String displayName;
}

/// Options for privacy-aware sharing and flattened redaction export.
@immutable
final class PrivacyExportOptions {
  /// Creates privacy export options.
  const PrivacyExportOptions({
    required this.recipient,
    required this.purpose,
    required this.watermarkText,
    this.redactIdNumbers = true,
    this.redactAddress = true,
    this.redactDateOfBirth = true,
    this.redactQrBarcodes = true,
    this.redactSignatures = true,
    this.customRedactionRects = const <RedactionRect>[],
    this.selectedPages = const <int>{},
    this.stripMetadata = true,
  });

  /// Creates default options for [recipient] and [purpose].
  factory PrivacyExportOptions.defaultFor({
    required String recipient,
    required String purpose,
    DateTime? date,
  }) {
    final formattedDate = (date ?? DateTime.now())
        .toIso8601String()
        .split('T')
        .first;
    final cleanRecipient = recipient.trim().toUpperCase();
    final cleanPurpose = purpose.trim().toUpperCase();
    final watermark = 'FOR $cleanRecipient - $cleanPurpose - $formattedDate';
    return PrivacyExportOptions(
      recipient: recipient,
      purpose: purpose,
      watermarkText: watermark,
    );
  }

  /// Intended recipient (e.g., "HDFC Bank", "Landlord", "Employer").
  final String recipient;

  /// Purpose of sharing (e.g., "Loan Application", "Rental Agreement").
  final String purpose;

  /// Burned watermark string (e.g., "FOR HDFC BANK - LOAN APPLICATION").
  final String watermarkText;

  /// Whether ID numbers are masked.
  final bool redactIdNumbers;

  /// Whether residential addresses are masked.
  final bool redactAddress;

  /// Whether dates of birth are masked.
  final bool redactDateOfBirth;

  /// Whether QR codes and barcodes are masked.
  final bool redactQrBarcodes;

  /// Whether signatures are masked.
  final bool redactSignatures;

  /// Additional custom bounding boxes to redact.
  final List<RedactionRect> customRedactionRects;

  /// 0-indexed page selection (empty set means all pages).
  final Set<int> selectedPages;

  /// Whether EXIF / document metadata is removed.
  final bool stripMetadata;
}
