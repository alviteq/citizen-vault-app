// Pack definitions and encrypted views are documented at their type boundary.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';
import 'package:vault_domain/src/graph/graph_models.dart';

enum OrganizingTemplateKind {
  person('PERSON', 'Person'),
  vehicle('VEHICLE', 'Vehicle'),
  property('PROPERTY', 'Property'),
  device('DEVICE', 'Device'),
  health('HEALTH', 'Health'),
  education('EDUCATION', 'Education'),
  travel('TRAVEL', 'Travel'),
  emergency('EMERGENCY', 'Emergency');

  const OrganizingTemplateKind(this.storageValue, this.displayName);

  final String storageValue;
  final String displayName;
}

enum SmartPackType {
  vehicle('VEHICLE', 'Vehicle'),
  home('HOME', 'Home'),
  travel('TRAVEL', 'Travel'),
  health('HEALTH', 'Health'),
  education('EDUCATION', 'Education'),
  emergency('EMERGENCY', 'Emergency'),
  custom('CUSTOM', 'Custom');

  const SmartPackType(this.storageValue, this.displayName);

  final String storageValue;
  final String displayName;

  static SmartPackType fromStorage(String value) => values.firstWhere(
    (type) => type.storageValue == value,
    orElse: () => custom,
  );
}

@immutable
final class PackItemDefinition {
  const PackItemDefinition({
    required this.key,
    required this.label,
    required this.guidance,
    this.claimPredicate,
    this.eventType,
    this.documentType,
    this.isOptional = false,
    this.includeInExport = false,
  });

  final String key;
  final String label;
  final String guidance;
  final String? claimPredicate;
  final String? eventType;
  final String? documentType;
  final bool isOptional;
  final bool includeInExport;
}

@immutable
final class OrganizingTemplateDefinition {
  const OrganizingTemplateDefinition({
    required this.id,
    required this.version,
    required this.kind,
    required this.description,
    required this.suggestedEntityType,
    required this.items,
  });

  final String id;
  final int version;
  final OrganizingTemplateKind kind;
  final String description;
  final LifeEntityType suggestedEntityType;
  final List<PackItemDefinition> items;
}

@immutable
final class CountryGuidanceItem {
  const CountryGuidanceItem({
    required this.templateId,
    required this.item,
  });

  final String templateId;
  final PackItemDefinition item;
}

@immutable
final class CountryPackDefinition {
  const CountryPackDefinition({
    required this.id,
    required this.countryCode,
    required this.label,
    required this.version,
    required this.disclaimer,
    required this.items,
  });

  final String id;
  final String countryCode;
  final String label;
  final int version;
  final String disclaimer;
  final List<CountryGuidanceItem> items;
}

@immutable
final class SmartPackPresetDefinition {
  const SmartPackPresetDefinition({
    required this.id,
    required this.version,
    required this.type,
    required this.title,
    required this.description,
    required this.templateIds,
  });

  final String id;
  final int version;
  final SmartPackType type;
  final String title;
  final String description;
  final List<String> templateIds;
}

abstract final class OrganizingPackRegistry {
  static const String guidanceDisclaimer =
      'Organizational guidance only. Items may not apply to you and are not '
      'legal, medical, financial, or government requirements.';

  static const List<OrganizingTemplateDefinition> templates = [
    OrganizingTemplateDefinition(
      id: 'core.person',
      version: 1,
      kind: OrganizingTemplateKind.person,
      description: 'Identity and contact facts for one person.',
      suggestedEntityType: LifeEntityType.person,
      items: [
        PackItemDefinition(
          key: 'identity',
          label: 'Identity record',
          guidance: 'Keep a record you choose to use for identity reference.',
          claimPredicate: 'DOCUMENT_NUMBER',
          includeInExport: true,
        ),
        PackItemDefinition(
          key: 'contact',
          label: 'Contact details',
          guidance: 'Add current contact details if useful to you.',
          claimPredicate: 'PHONE_NUMBER',
          isOptional: true,
        ),
      ],
    ),
    OrganizingTemplateDefinition(
      id: 'core.vehicle',
      version: 1,
      kind: OrganizingTemplateKind.vehicle,
      description: 'Ownership, insurance, service, and vehicle evidence.',
      suggestedEntityType: LifeEntityType.vehicle,
      items: [
        PackItemDefinition(
          key: 'registration',
          label: 'Registration details',
          guidance: 'Organize the registration evidence you rely on.',
          claimPredicate: 'VEHICLE_REGISTRATION_NUMBER',
          documentType: 'VEHICLE_DOCUMENT',
          includeInExport: true,
        ),
        PackItemDefinition(
          key: 'insurance',
          label: 'Insurance',
          guidance: 'Keep current policy evidence when it applies.',
          documentType: 'INSURANCE_POLICY',
          includeInExport: true,
        ),
        PackItemDefinition(
          key: 'service',
          label: 'Service history',
          guidance: 'Service evidence can help preserve a maintenance history.',
          eventType: 'SERVICE',
          isOptional: true,
        ),
      ],
    ),
    OrganizingTemplateDefinition(
      id: 'core.property',
      version: 1,
      kind: OrganizingTemplateKind.property,
      description: 'Home, address, utilities, tax, and maintenance evidence.',
      suggestedEntityType: LifeEntityType.property,
      items: [
        PackItemDefinition(
          key: 'address',
          label: 'Address details',
          guidance: 'Save the address fact you use for this property.',
          claimPredicate: 'ADDRESS',
        ),
        PackItemDefinition(
          key: 'utility',
          label: 'Utility record',
          guidance: 'Choose a recent utility record if useful.',
          documentType: 'ELECTRICITY_BILL',
          isOptional: true,
          includeInExport: true,
        ),
        PackItemDefinition(
          key: 'property_tax',
          label: 'Property tax record',
          guidance: 'Organize tax evidence when it applies to this property.',
          documentType: 'PROPERTY_TAX',
          isOptional: true,
        ),
      ],
    ),
    OrganizingTemplateDefinition(
      id: 'core.device',
      version: 1,
      kind: OrganizingTemplateKind.device,
      description: 'Purchase, serial number, warranty, and repair history.',
      suggestedEntityType: LifeEntityType.device,
      items: [
        PackItemDefinition(
          key: 'serial',
          label: 'Serial number',
          guidance: 'Record the manufacturer identifier if available.',
          claimPredicate: 'DEVICE_SERIAL_NUMBER',
        ),
        PackItemDefinition(
          key: 'purchase',
          label: 'Purchase evidence',
          guidance: 'A receipt or invoice can support ownership history.',
          eventType: 'PURCHASE',
          documentType: 'INVOICE',
          isOptional: true,
        ),
        PackItemDefinition(
          key: 'warranty',
          label: 'Warranty',
          guidance: 'Track warranty evidence when provided.',
          eventType: 'WARRANTY',
          isOptional: true,
        ),
      ],
    ),
    OrganizingTemplateDefinition(
      id: 'core.health',
      version: 1,
      kind: OrganizingTemplateKind.health,
      description: 'Selected medical records and care history.',
      suggestedEntityType: LifeEntityType.person,
      items: [
        PackItemDefinition(
          key: 'medical_record',
          label: 'Medical record',
          guidance: 'Include only health information you choose to organize.',
          documentType: 'MEDICAL_REPORT',
          isOptional: true,
          includeInExport: true,
        ),
        PackItemDefinition(
          key: 'prescription',
          label: 'Prescription',
          guidance: 'Keep current prescription evidence when useful.',
          documentType: 'PRESCRIPTION',
          isOptional: true,
        ),
      ],
    ),
    OrganizingTemplateDefinition(
      id: 'core.education',
      version: 1,
      kind: OrganizingTemplateKind.education,
      description: 'Qualifications, certificates, and education events.',
      suggestedEntityType: LifeEntityType.person,
      items: [
        PackItemDefinition(
          key: 'certificate',
          label: 'Education certificate',
          guidance: 'Organize certificates relevant to your own purpose.',
          documentType: 'EDUCATION_CERTIFICATE',
          includeInExport: true,
        ),
        PackItemDefinition(
          key: 'education_event',
          label: 'Education history',
          guidance: 'Add an education event if useful for your timeline.',
          eventType: 'EDUCATION',
          isOptional: true,
        ),
      ],
    ),
    OrganizingTemplateDefinition(
      id: 'core.travel',
      version: 1,
      kind: OrganizingTemplateKind.travel,
      description: 'Selected identity, booking, and insurance records.',
      suggestedEntityType: LifeEntityType.person,
      items: [
        PackItemDefinition(
          key: 'passport',
          label: 'Passport',
          guidance: 'Include a passport only when relevant to your travel.',
          documentType: 'PASSPORT',
          includeInExport: true,
        ),
        PackItemDefinition(
          key: 'travel_insurance',
          label: 'Travel insurance',
          guidance: 'Include insurance evidence if you obtained a policy.',
          documentType: 'INSURANCE_POLICY',
          isOptional: true,
          includeInExport: true,
        ),
      ],
    ),
    OrganizingTemplateDefinition(
      id: 'core.emergency',
      version: 1,
      kind: OrganizingTemplateKind.emergency,
      description: 'Preparation checklist inside the encrypted vault.',
      suggestedEntityType: LifeEntityType.person,
      items: [
        PackItemDefinition(
          key: 'emergency_contact',
          label: 'Emergency contact',
          guidance: 'Choose a contact you want available inside OwnKeep.',
          claimPredicate: 'PHONE_NUMBER',
        ),
        PackItemDefinition(
          key: 'insurance',
          label: 'Selected insurance evidence',
          guidance: 'Include a policy only when useful to your plan.',
          documentType: 'INSURANCE_POLICY',
          isOptional: true,
          includeInExport: true,
        ),
      ],
    ),
  ];

  static const CountryPackDefinition india = CountryPackDefinition(
    id: 'country.in',
    countryCode: 'IN',
    label: 'India Pack',
    version: 1,
    disclaimer:
        'India-specific organizational suggestions only. Availability, '
        'eligibility, acceptance, and legal requirements vary by person, '
        'purpose, state, issuer, and current law.',
    items: [
      CountryGuidanceItem(
        templateId: 'core.person',
        item: PackItemDefinition(
          key: 'india_aadhaar',
          label: 'Aadhaar, if you use it',
          guidance:
              'Optional organizational suggestion; OwnKeep does not require '
              'or validate Aadhaar.',
          documentType: 'AADHAAR',
          isOptional: true,
        ),
      ),
      CountryGuidanceItem(
        templateId: 'core.person',
        item: PackItemDefinition(
          key: 'india_pan',
          label: 'PAN card, if applicable',
          guidance:
              'Optional organizational suggestion; tax applicability differs.',
          documentType: 'PAN',
          isOptional: true,
        ),
      ),
      CountryGuidanceItem(
        templateId: 'core.vehicle',
        item: PackItemDefinition(
          key: 'india_driving_licence',
          label: 'Driving licence, if applicable',
          guidance:
              'Optional suggestion. Verify current requirements with the '
              'relevant authority.',
          documentType: 'DRIVING_LICENCE',
          isOptional: true,
        ),
      ),
      CountryGuidanceItem(
        templateId: 'core.travel',
        item: PackItemDefinition(
          key: 'india_identity_reference',
          label: 'Selected Indian identity reference',
          guidance:
              'Choose only evidence relevant to your trip and destination.',
          documentType: 'AADHAAR',
          isOptional: true,
        ),
      ),
    ],
  );

  static const List<SmartPackPresetDefinition> presets = [
    SmartPackPresetDefinition(
      id: 'preset.vehicle',
      version: 1,
      type: SmartPackType.vehicle,
      title: 'Vehicle Pack',
      description: 'Registration, insurance, service, and ownership evidence.',
      templateIds: ['core.vehicle'],
    ),
    SmartPackPresetDefinition(
      id: 'preset.home',
      version: 1,
      type: SmartPackType.home,
      title: 'Home Pack',
      description: 'Property, utility, tax, and selected home evidence.',
      templateIds: ['core.property', 'core.device'],
    ),
    SmartPackPresetDefinition(
      id: 'preset.travel',
      version: 1,
      type: SmartPackType.travel,
      title: 'Travel Pack',
      description: 'Selected identity and travel-related evidence.',
      templateIds: ['core.travel', 'core.person'],
    ),
    SmartPackPresetDefinition(
      id: 'preset.health',
      version: 1,
      type: SmartPackType.health,
      title: 'Health Pack',
      description: 'Medical records you choose to organize.',
      templateIds: ['core.health'],
    ),
    SmartPackPresetDefinition(
      id: 'preset.education',
      version: 1,
      type: SmartPackType.education,
      title: 'Education Pack',
      description: 'Certificates and education history.',
      templateIds: ['core.education'],
    ),
    SmartPackPresetDefinition(
      id: 'preset.emergency',
      version: 1,
      type: SmartPackType.emergency,
      title: 'Emergency Preparation Pack',
      description: 'A private preparation checklist; not Emergency Mode.',
      templateIds: ['core.emergency'],
    ),
  ];

  static OrganizingTemplateDefinition template(String id) =>
      templates.singleWhere((template) => template.id == id);

  static SmartPackPresetDefinition preset(String id) =>
      presets.singleWhere((preset) => preset.id == id);
}

@immutable
final class SmartPackItem {
  const SmartPackItem({
    required this.id,
    required this.key,
    required this.label,
    required this.guidance,
    required this.position,
    required this.isOptional,
    required this.isEnabled,
    required this.includeInExport,
    required this.isSatisfied,
    this.claimPredicate,
    this.eventType,
    this.documentType,
    this.linkedClaimId,
    this.linkedEventId,
    this.linkedDocumentId,
    this.linkedTaskId,
  });

  final String id;
  final String key;
  final String label;
  final String guidance;
  final int position;
  final bool isOptional;
  final bool isEnabled;
  final bool includeInExport;
  final bool isSatisfied;
  final String? claimPredicate;
  final String? eventType;
  final String? documentType;
  final String? linkedClaimId;
  final String? linkedEventId;
  final String? linkedDocumentId;
  final String? linkedTaskId;
}

@immutable
final class SmartPack {
  const SmartPack({
    required this.id,
    required this.title,
    required this.type,
    required this.templateId,
    required this.templateVersion,
    required this.guidanceDisclaimer,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.countryCode,
    this.entityId,
    this.isArchived = false,
  });

  final String id;
  final String title;
  final SmartPackType type;
  final String templateId;
  final int templateVersion;
  final String? countryCode;
  final String? entityId;
  final String guidanceDisclaimer;
  final bool isArchived;
  final List<SmartPackItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get applicableCount => items.where((item) => item.isEnabled).length;
  int get satisfiedCount =>
      items.where((item) => item.isEnabled && item.isSatisfied).length;
  int get completenessPercent =>
      applicableCount == 0 ? 0 : (satisfiedCount * 100 ~/ applicableCount);
}
