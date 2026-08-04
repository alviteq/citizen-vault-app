// Template fields are documented at their public type boundaries.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';
import 'package:vault_domain/src/graph/graph_models.dart';

/// One reusable field in an entity profile template.
@immutable
final class EntityTemplateField {
  const EntityTemplateField({
    required this.key,
    required this.label,
    required this.valueType,
    this.cardinality = ClaimCardinality.singleCurrent,
  });

  final String key;
  final String label;
  final ClaimValueType valueType;
  final ClaimCardinality cardinality;
}

/// Presentation and claim guidance for one generic entity type.
@immutable
final class EntityTemplateDefinition {
  const EntityTemplateDefinition({
    required this.type,
    required this.singularLabel,
    required this.pluralLabel,
    required this.fields,
  });

  final LifeEntityType type;
  final String singularLabel;
  final String pluralLabel;
  final List<EntityTemplateField> fields;
}

/// Versioned built-in templates. They guide entry but never alter facts.
abstract final class EntityTemplateRegistry {
  static const int version = 1;

  static const List<EntityTemplateDefinition> templates = [
    EntityTemplateDefinition(
      type: LifeEntityType.person,
      singularLabel: 'Person',
      pluralLabel: 'People',
      fields: [
        EntityTemplateField(
          key: 'DATE_OF_BIRTH',
          label: 'Date of birth',
          valueType: ClaimValueType.date,
        ),
        EntityTemplateField(
          key: 'PHONE_NUMBER',
          label: 'Phone',
          valueType: ClaimValueType.string,
          cardinality: ClaimCardinality.multipleCurrent,
        ),
        EntityTemplateField(
          key: 'EMAIL_ADDRESS',
          label: 'Email',
          valueType: ClaimValueType.string,
          cardinality: ClaimCardinality.multipleCurrent,
        ),
      ],
    ),
    EntityTemplateDefinition(
      type: LifeEntityType.family,
      singularLabel: 'Family',
      pluralLabel: 'Families',
      fields: [],
    ),
    EntityTemplateDefinition(
      type: LifeEntityType.pet,
      singularLabel: 'Pet',
      pluralLabel: 'Pets',
      fields: [
        EntityTemplateField(
          key: 'SPECIES',
          label: 'Species',
          valueType: ClaimValueType.string,
        ),
        EntityTemplateField(
          key: 'DATE_OF_BIRTH',
          label: 'Date of birth',
          valueType: ClaimValueType.date,
        ),
      ],
    ),
    EntityTemplateDefinition(
      type: LifeEntityType.vehicle,
      singularLabel: 'Vehicle',
      pluralLabel: 'Vehicles',
      fields: [
        EntityTemplateField(
          key: 'VEHICLE_REGISTRATION_NUMBER',
          label: 'Registration number',
          valueType: ClaimValueType.identifier,
        ),
        EntityTemplateField(
          key: 'MAKE_MODEL',
          label: 'Make and model',
          valueType: ClaimValueType.string,
        ),
        EntityTemplateField(
          key: 'MODEL_YEAR',
          label: 'Year',
          valueType: ClaimValueType.integer,
        ),
      ],
    ),
    EntityTemplateDefinition(
      type: LifeEntityType.property,
      singularLabel: 'Property',
      pluralLabel: 'Properties',
      fields: [
        EntityTemplateField(
          key: 'ADDRESS',
          label: 'Address',
          valueType: ClaimValueType.string,
        ),
      ],
    ),
    EntityTemplateDefinition(
      type: LifeEntityType.place,
      singularLabel: 'Place',
      pluralLabel: 'Places',
      fields: [
        EntityTemplateField(
          key: 'ADDRESS',
          label: 'Address',
          valueType: ClaimValueType.string,
        ),
      ],
    ),
    EntityTemplateDefinition(
      type: LifeEntityType.device,
      singularLabel: 'Device',
      pluralLabel: 'Devices',
      fields: [
        EntityTemplateField(
          key: 'DEVICE_SERIAL_NUMBER',
          label: 'Serial number',
          valueType: ClaimValueType.identifier,
        ),
        EntityTemplateField(
          key: 'MAKE_MODEL',
          label: 'Make and model',
          valueType: ClaimValueType.string,
        ),
      ],
    ),
    EntityTemplateDefinition(
      type: LifeEntityType.appliance,
      singularLabel: 'Appliance',
      pluralLabel: 'Appliances',
      fields: [
        EntityTemplateField(
          key: 'DEVICE_SERIAL_NUMBER',
          label: 'Serial number',
          valueType: ClaimValueType.identifier,
        ),
      ],
    ),
    EntityTemplateDefinition(
      type: LifeEntityType.organisation,
      singularLabel: 'Organisation',
      pluralLabel: 'Organisations',
      fields: [
        EntityTemplateField(
          key: 'WEBSITE',
          label: 'Website',
          valueType: ClaimValueType.uri,
        ),
      ],
    ),
  ];

  static EntityTemplateDefinition forType(LifeEntityType type) =>
      templates.firstWhere(
        (template) => template.type == type,
        orElse: () => EntityTemplateDefinition(
          type: type,
          singularLabel: 'Item',
          pluralLabel: 'Items',
          fields: const [],
        ),
      );
}
