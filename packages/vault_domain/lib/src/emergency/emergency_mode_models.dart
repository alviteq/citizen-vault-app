import 'package:meta/meta.dart';

/// An emergency contact person.
@immutable
final class EmergencyContact {
  /// Creates an emergency contact.
  const EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
    this.isPrimary = false,
  });

  /// Contact full name.
  final String name;

  /// Relationship to account holder (e.g. Spouse, Parent, Doctor).
  final String relationship;

  /// Phone number.
  final String phone;

  /// Whether contact is primary emergency responder.
  final bool isPrimary;
}

/// Minimized, emergency-visible medical and responder profile details.
@immutable
final class EmergencyMedicalRecord {
  /// Creates an emergency medical record.
  const EmergencyMedicalRecord({
    required this.fullName,
    required this.bloodGroup,
    required this.allergies,
    required this.medications,
    required this.doctorName,
    required this.doctorPhone,
    required this.insuranceProvider,
    required this.insurancePolicyNumber,
  });

  /// Full legal name.
  final String fullName;

  /// Blood group (e.g. O+ve, A-ve).
  final String bloodGroup;

  /// Known severe allergies (e.g. Penicillin, Peanuts).
  final String allergies;

  /// Active daily medications.
  final String medications;

  /// Primary physician or doctor name.
  final String doctorName;

  /// Primary physician phone number.
  final String doctorPhone;

  /// Selected health insurance provider.
  final String insuranceProvider;

  /// Selected health insurance policy number.
  final String insurancePolicyNumber;
}

/// Storage envelope for Emergency Mode, isolated from primary vault graph.
@immutable
final class EmergencyCardEnvelope {
  /// Creates an emergency storage envelope.
  const EmergencyCardEnvelope({
    required this.medicalRecord,
    required this.contacts,
    required this.lastUpdated,
    this.isEnabled = true,
    this.accessLog = const <String>[],
  });

  /// Medical profile data.
  final EmergencyMedicalRecord medicalRecord;

  /// List of emergency contacts.
  final List<EmergencyContact> contacts;

  /// Timestamp of last configuration.
  final DateTime lastUpdated;

  /// Whether emergency mode accessibility is active.
  final bool isEnabled;

  /// Audit log of emergency access view timestamps.
  final List<String> accessLog;
}
