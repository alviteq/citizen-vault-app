// Graph fields are documented at their public type boundaries.
// ignore_for_file: public_member_api_docs
// ignore_for_file: avoid_positional_boolean_parameters

import 'package:meta/meta.dart';

/// Extensible entity categories in the encrypted Life Graph.
enum LifeEntityType {
  person('PERSON'),
  family('FAMILY'),
  pet('PET'),
  vehicle('VEHICLE'),
  property('PROPERTY'),
  place('PLACE'),
  device('DEVICE'),
  appliance('APPLIANCE'),
  organisation('ORGANISATION'),
  account('ACCOUNT'),
  policy('POLICY'),
  subscription('SUBSCRIPTION'),
  warranty('WARRANTY'),
  other('OTHER');

  const LifeEntityType(this.storageValue);

  final String storageValue;

  static LifeEntityType fromStorage(String value) => values.firstWhere(
    (type) => type.storageValue == value,
    orElse: () => other,
  );
}

/// Lifecycle state for an entity; archive preserves graph history.
enum LifeEntityStatus {
  active('ACTIVE'),
  archived('ARCHIVED');

  const LifeEntityStatus(this.storageValue);

  final String storageValue;

  static LifeEntityStatus fromStorage(String value) => values.firstWhere(
    (status) => status.storageValue == value,
    orElse: () => active,
  );
}

/// Relationship vocabulary shared by graph repositories and UI.
enum LifeRelationshipType {
  owns('OWNS'),
  belongsTo('BELONGS_TO'),
  covers('COVERS'),
  insures('INSURES'),
  issuedBy('ISSUED_BY'),
  relatedTo('RELATED_TO'),
  purchasedFrom('PURCHASED_FROM'),
  locatedAt('LOCATED_AT'),
  warrantyFor('WARRANTY_FOR'),
  parentOf('PARENT_OF'),
  dependentOf('DEPENDENT_OF');

  const LifeRelationshipType(this.storageValue);

  final String storageValue;

  static LifeRelationshipType fromStorage(String value) => values.firstWhere(
    (type) => type.storageValue == value,
    orElse: () => relatedTo,
  );
}

/// Claim confirmation state.
enum ClaimStatus {
  suggested('SUGGESTED'),
  confirmed('CONFIRMED'),
  rejected('REJECTED'),
  superseded('SUPERSEDED');

  const ClaimStatus(this.storageValue);

  final String storageValue;

  static ClaimStatus fromStorage(String value) => values.firstWhere(
    (status) => status.storageValue == value,
    orElse: () => suggested,
  );
}

/// Claim predicate cardinality policy.
enum ClaimCardinality {
  singleCurrent('SINGLE_CURRENT'),
  multipleCurrent('MULTIPLE_CURRENT'),
  historical('HISTORICAL');

  const ClaimCardinality(this.storageValue);

  final String storageValue;

  static ClaimCardinality fromStorage(String value) => values.firstWhere(
    (cardinality) => cardinality.storageValue == value,
    orElse: () => singleCurrent,
  );
}

/// Typed Claim value categories. Display formatting is never authoritative.
enum ClaimValueType {
  string('STRING'),
  integer('INTEGER'),
  decimal('DECIMAL'),
  boolean('BOOLEAN'),
  date('DATE'),
  datetime('DATETIME'),
  money('MONEY'),
  identifier('IDENTIFIER'),
  uri('URI'),
  entityReference('ENTITY_REFERENCE');

  const ClaimValueType(this.storageValue);

  final String storageValue;
}

/// Provenance source for imported, extracted, calculated, or user-entered data.
enum ProvenanceSourceType {
  userEntered('USER_ENTERED'),
  ocrExtracted('OCR_EXTRACTED'),
  documentExtracted('DOCUMENT_EXTRACTED'),
  ruleDerived('RULE_DERIVED'),
  calculated('CALCULATED'),
  imported('IMPORTED'),
  system('SYSTEM');

  const ProvenanceSourceType(this.storageValue);

  final String storageValue;
}

/// One normalized monetary value in minor currency units.
@immutable
final class ClaimMoney {
  const ClaimMoney({required this.amountMinorUnits, required this.currency});

  final int amountMinorUnits;
  final String currency;
}

/// A typed, storage-ready Claim value.
@immutable
final class ClaimValue {
  const ClaimValue._({required this.type, this.value});

  const ClaimValue.string(String value)
    : this._(type: ClaimValueType.string, value: value);
  const ClaimValue.integer(int value)
    : this._(type: ClaimValueType.integer, value: value);
  const ClaimValue.decimal(double value)
    : this._(type: ClaimValueType.decimal, value: value);
  const ClaimValue.boolean(bool value)
    : this._(type: ClaimValueType.boolean, value: value);
  const ClaimValue.date(DateTime value)
    : this._(type: ClaimValueType.date, value: value);
  const ClaimValue.datetime(DateTime value)
    : this._(type: ClaimValueType.datetime, value: value);
  const ClaimValue.money(ClaimMoney value)
    : this._(type: ClaimValueType.money, value: value);
  const ClaimValue.identifier(String value)
    : this._(type: ClaimValueType.identifier, value: value);
  const ClaimValue.uri(String value)
    : this._(type: ClaimValueType.uri, value: value);
  const ClaimValue.entityReference(String value)
    : this._(type: ClaimValueType.entityReference, value: value);

  final ClaimValueType type;
  final Object? value;

  String get stringValue => value! as String;
  int get integerValue => value! as int;
  double get decimalValue => value! as double;
  bool get booleanValue => value! as bool;
  DateTime get dateTimeValue => value! as DateTime;
  ClaimMoney get moneyValue => value! as ClaimMoney;
}

/// Generic encrypted graph entity.
@immutable
final class LifeEntity {
  const LifeEntity({
    required this.id,
    required this.type,
    required this.displayName,
    this.subtype,
    this.status = LifeEntityStatus.active,
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final LifeEntityType type;
  final String? subtype;
  final String displayName;
  final LifeEntityStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;
}

/// One encrypted, typed profile attribute that is not asserted as a Claim.
@immutable
final class LifeEntityAttribute {
  const LifeEntityAttribute({
    required this.id,
    required this.entityId,
    required this.key,
    required this.value,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String entityId;
  final String key;
  final ClaimValue value;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// Auditable profile lifecycle entry.
@immutable
final class LifeEntityHistoryEvent {
  const LifeEntityHistoryEvent({
    required this.id,
    required this.entityId,
    required this.eventType,
    required this.createdAt,
    this.payloadJson,
  });

  final String id;
  final String entityId;
  final String eventType;
  final String? payloadJson;
  final DateTime createdAt;
}

/// A relationship between two entities.
@immutable
final class LifeRelationship {
  const LifeRelationship({
    required this.id,
    required this.fromEntityId,
    required this.toEntityId,
    required this.type,
    required this.status,
    this.validFrom,
    this.validUntil,
    this.supersedesId,
    this.provenanceId,
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
  });

  final String id;
  final String fromEntityId;
  final String toEntityId;
  final LifeRelationshipType type;
  final ClaimStatus status;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? supersedesId;
  final String? provenanceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
}

/// An asserted fact with typed value, evidence, and temporal history.
@immutable
final class LifeClaim {
  const LifeClaim({
    required this.id,
    required this.subjectEntityId,
    required this.predicate,
    required this.value,
    required this.status,
    required this.cardinality,
    this.validFrom,
    this.validUntil,
    this.supersedesId,
    this.provenanceId,
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.rejectedAt,
  });

  final String id;
  final String subjectEntityId;
  final String predicate;
  final ClaimValue value;
  final ClaimStatus status;
  final ClaimCardinality cardinality;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? supersedesId;
  final String? provenanceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final DateTime? rejectedAt;
}

/// Evidence location for a Claim or Relationship.
@immutable
final class EvidenceLink {
  const EvidenceLink({
    required this.id,
    required this.documentId,
    required this.evidenceRole,
    this.assetId,
    this.claimId,
    this.relationshipId,
    this.pageNumber,
    this.boundingPolygonJson,
    this.textFragmentHash,
    this.provenanceId,
    this.createdAt,
  });

  final String id;
  final String documentId;
  final String? assetId;
  final String? claimId;
  final String? relationshipId;
  final String evidenceRole;
  final int? pageNumber;
  final String? boundingPolygonJson;
  final List<int>? textFragmentHash;
  final String? provenanceId;
  final DateTime? createdAt;
}

/// Provenance metadata for a graph assertion or derived value.
@immutable
final class GraphProvenance {
  const GraphProvenance({
    required this.id,
    required this.sourceType,
    this.sourceDocumentId,
    this.extractorId,
    this.extractorVersion,
    this.ruleId,
    this.ruleVersion,
    this.confidence,
    this.confidenceSource,
    this.createdAt,
  });

  final String id;
  final ProvenanceSourceType sourceType;
  final String? sourceDocumentId;
  final String? extractorId;
  final String? extractorVersion;
  final String? ruleId;
  final String? ruleVersion;
  final double? confidence;
  final String? confidenceSource;
  final DateTime? createdAt;
}
