// Enum values and immutable view fields are documented at their type boundary.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';

/// User-reviewable document type suggestions.
enum DocumentType {
  aadhaar('AADHAAR', 'Aadhaar'),
  pan('PAN', 'PAN card'),
  passport('PASSPORT', 'Passport'),
  drivingLicence('DRIVING_LICENCE', 'Driving licence'),
  voterId('VOTER_ID', 'Voter ID'),
  electricityBill('ELECTRICITY_BILL', 'Electricity bill'),
  waterBill('WATER_BILL', 'Water bill'),
  gasBill('GAS_BILL', 'Gas bill'),
  propertyTax('PROPERTY_TAX', 'Property tax'),
  bankStatement('BANK_STATEMENT', 'Bank statement'),
  insurancePolicy('INSURANCE_POLICY', 'Insurance policy'),
  medicalReport('MEDICAL_REPORT', 'Medical report'),
  prescription('PRESCRIPTION', 'Prescription'),
  educationCertificate('EDUCATION_CERTIFICATE', 'Education certificate'),
  vehicleDocument('VEHICLE_DOCUMENT', 'Vehicle document'),
  receipt('RECEIPT', 'Receipt'),
  invoice('INVOICE', 'Invoice'),
  generalDocument('GENERAL_DOCUMENT', 'General document'),
  unknown('UNKNOWN', 'Unknown');

  const DocumentType(this.storageValue, this.displayName);

  /// Stable encrypted-database value.
  final String storageValue;

  /// Localized-ready English presentation label.
  final String displayName;

  /// Parses a database value without silently inventing a type.
  static DocumentType fromStorage(String value) => values.singleWhere(
    (type) => type.storageValue == value,
    orElse: () => unknown,
  );
}

/// Deterministically extracted field categories.
enum ExtractedFieldType {
  date('DATE', 'Date'),
  expiryDate('EXPIRY_DATE', 'Expiry date'),
  dueDate('DUE_DATE', 'Due date'),
  amount('AMOUNT', 'Amount'),
  documentNumber('DOCUMENT_NUMBER', 'Document number'),
  issuer('ISSUER', 'Issuer'),
  email('EMAIL', 'Email'),
  phone('PHONE', 'Phone'),
  maskedAccountNumber('MASKED_ACCOUNT_NUMBER', 'Masked account'),
  address('ADDRESS', 'Address'),
  firstName('FIRST_NAME', 'First name'),
  lastName('LAST_NAME', 'Last name'),
  fullName('FULL_NAME', 'Full name'),
  relativeName('RELATIVE_NAME', "Relative's name"),
  age('AGE', 'Age'),
  gender('GENDER', 'Gender'),
  state('STATE', 'State'),
  parliamentaryConstituency(
    'PARLIAMENTARY_CONSTITUENCY',
    'Parliamentary constituency',
  ),
  assemblyConstituency('ASSEMBLY_CONSTITUENCY', 'Assembly constituency'),
  pollingStation('POLLING_STATION', 'Polling station'),
  partNumber('PART_NUMBER', 'Part number'),
  serialNumber('SERIAL_NUMBER', 'Serial number'),
  pollingDate('POLLING_DATE', 'Polling date'),
  nationality('NATIONALITY', 'Nationality'),
  placeOfBirth('PLACE_OF_BIRTH', 'Place of birth'),
  policyholder('POLICYHOLDER', 'Policyholder'),
  consumerNumber('CONSUMER_NUMBER', 'Consumer number'),
  billingPeriod('BILLING_PERIOD', 'Billing period'),
  patientName('PATIENT_NAME', 'Patient name'),
  merchant('MERCHANT', 'Merchant'),
  taxAmount('TAX_AMOUNT', 'Tax amount'),
  totalAmount('TOTAL_AMOUNT', 'Total amount');

  const ExtractedFieldType(this.storageValue, this.displayName);

  /// Stable encrypted-database value.
  final String storageValue;

  /// User-facing field label.
  final String displayName;

  /// Parses a database value.
  static ExtractedFieldType? tryFromStorage(String value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }
    return null;
  }
}

/// One field candidate presented for local user verification.
@immutable
final class ExtractedFieldView {
  /// Creates a field view.
  const ExtractedFieldView({
    required this.id,
    required this.type,
    required this.rawValue,
    required this.normalizedValue,
    required this.extractorId,
    required this.extractorVersion,
    required this.confirmedByUser,
    this.confidence,
    this.sourcePage,
    this.sourceBlockId,
  });

  final String id;
  final ExtractedFieldType type;
  final String? rawValue;
  final String? normalizedValue;
  final double? confidence;
  final int? sourcePage;
  final String? sourceBlockId;
  final String extractorId;
  final String extractorVersion;
  final bool confirmedByUser;

  /// Best available editable value.
  String get effectiveValue => normalizedValue ?? rawValue ?? '';
}

/// A document waiting for confirmation of local machine suggestions.
@immutable
final class DocumentReviewView {
  /// Creates an immutable review view.
  const DocumentReviewView({
    required this.documentId,
    required this.logicalFilename,
    required this.suggestedType,
    required this.classificationEvidence,
    required this.fields,
    required this.ocrTextPreview,
    this.classificationConfidence,
  });

  final String documentId;
  final String logicalFilename;
  final DocumentType suggestedType;
  final double? classificationConfidence;
  final List<String> classificationEvidence;
  final List<ExtractedFieldView> fields;
  final String ocrTextPreview;
}

/// User-approved edit for one candidate field.
@immutable
final class ConfirmedFieldEdit {
  /// Creates an edit bound to an existing encrypted-database row.
  const ConfirmedFieldEdit({required this.fieldId, required this.value});

  final String fieldId;
  final String value;
}

/// Minimal local FTS result for later document-list presentation.
@immutable
final class DocumentSearchResult {
  /// Creates a safe search result.
  const DocumentSearchResult({
    required this.documentId,
    required this.logicalFilename,
    required this.documentType,
    required this.relevance,
  });

  final String documentId;
  final String logicalFilename;
  final DocumentType documentType;
  final double relevance;
}
