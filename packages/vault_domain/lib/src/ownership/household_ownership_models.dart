import 'package:meta/meta.dart';

/// Categories of physical household assets and personal property.
enum HouseholdAssetCategory {
  /// Motorized vehicles (cars, motorcycles, scooters).
  vehicle('VEHICLE', 'Vehicle'),

  /// Residential or commercial real estate and property.
  property('PROPERTY', 'Property'),

  /// Personal computing devices (laptops, phones, tablets).
  device('DEVICE', 'Device'),

  /// Home appliances (refrigerators, washing machines, ACs).
  appliance('APPLIANCE', 'Appliance'),

  /// Home electronics, audio/video equipment, cameras.
  electronics('ELECTRONICS', 'Electronics'),

  /// Precious jewellery, watches, and valuables.
  jewellery('JEWELLERY', 'Jewellery'),

  /// Furniture and fixtures.
  furniture('FURNITURE', 'Furniture'),

  /// Other valuable assets or household items.
  other('OTHER', 'Other');

  const HouseholdAssetCategory(this.storageValue, this.displayName);

  /// Storage string representation.
  final String storageValue;

  /// Human-readable label.
  final String displayName;

  /// Resolves storage string value into [HouseholdAssetCategory].
  static HouseholdAssetCategory fromStorage(String value) => values.firstWhere(
    (category) => category.storageValue == value,
    orElse: () => other,
  );
}

/// Operational status of a household asset.
enum HouseholdAssetStatus {
  /// Currently active and operational in household.
  active('ACTIVE', 'Active'),

  /// Under repair or servicing.
  repaired('REPAIRED', 'In Repair'),

  /// Replaced by a newer asset or model.
  replaced('REPLACED', 'Replaced'),

  /// Sold or transferred to another owner.
  sold('SOLD', 'Sold'),

  /// Disposed or written off.
  disposed('DISPOSED', 'Disposed'),

  /// Archived historical record.
  archived('ARCHIVED', 'Archived');

  const HouseholdAssetStatus(this.storageValue, this.displayName);

  /// Storage string representation.
  final String storageValue;

  /// Display string.
  final String displayName;

  /// Resolves storage string value into [HouseholdAssetStatus].
  static HouseholdAssetStatus fromStorage(String value) => values.firstWhere(
    (status) => status.storageValue == value,
    orElse: () => active,
  );
}

/// Categories of maintenance, cost, service, and ownership events.
enum HouseholdEventType {
  /// Initial acquisition or purchase.
  purchase('PURCHASE', 'Purchase'),

  /// Scheduled or routine maintenance.
  maintenance('MAINTENANCE', 'Maintenance'),

  /// Unscheduled repair or replacement of broken parts.
  repair('REPAIR', 'Repair'),

  /// Tyre change, rotation, or balancing for vehicles.
  tyreChange('TYRE_CHANGE', 'Tyres'),

  /// Authorized service centre visit.
  service('SERVICE', 'Service'),

  /// Property tax or local municipal tax payment.
  taxPayment('TAX_PAYMENT', 'Tax Payment'),

  /// Utility connection or bill payment.
  utilityBill('UTILITY_BILL', 'Utility'),

  /// Warranty registration, extension, or claim.
  warrantyClaim('WARRANTY_CLAIM', 'Warranty'),

  /// Addition of accessories or upgrades.
  accessoryAdd('ACCESSORY_ADD', 'Accessory'),

  /// Change of ownership or title transfer.
  ownershipTransfer('OWNERSHIP_TRANSFER', 'Ownership Change'),

  /// Retirement, sale, or disposal.
  disposal('DISPOSAL', 'Disposal');

  const HouseholdEventType(this.storageValue, this.displayName);

  /// Storage string representation.
  final String storageValue;

  /// Display string.
  final String displayName;

  /// Resolves storage string value into [HouseholdEventType].
  static HouseholdEventType fromStorage(String value) => values.firstWhere(
    (type) => type.storageValue == value,
    orElse: () => maintenance,
  );
}

/// Representation of a household asset or property item.
@immutable
final class HouseholdAssetRecord {
  /// Creates a household asset record.
  const HouseholdAssetRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    this.serialOrVinNumber,
    this.location,
    this.purchaseDate,
    this.purchasePrice,
    this.currency = 'INR',
    this.warrantyProvider,
    this.warrantyEndDate,
    this.notes,
  });

  /// Unique asset ID.
  final String id;

  /// Item name (e.g. "Honda City", "MacBook Pro 16"", "Apartment 302").
  final String name;

  /// Primary category.
  final HouseholdAssetCategory category;

  /// Current operational status.
  final HouseholdAssetStatus status;

  /// Serial number, vehicle VIN, or property tax ID.
  final String? serialOrVinNumber;

  /// Physical location in household (e.g., "Garage", "Living Room").
  final String? location;

  /// Acquisition / purchase date.
  final DateTime? purchaseDate;

  /// Purchase price.
  final double? purchasePrice;

  /// Currency ISO code.
  final String currency;

  /// Provider of active warranty or insurance.
  final String? warrantyProvider;

  /// Warranty expiration date.
  final DateTime? warrantyEndDate;

  /// Optional notes.
  final String? notes;

  /// Whether warranty is currently active based on [asOf].
  bool isWarrantyActive([DateTime? asOf]) {
    if (warrantyEndDate == null) return false;
    final now = asOf ?? DateTime.now();
    return warrantyEndDate!.isAfter(now);
  }
}

/// Cost, service, tax, or repair event record linked to a household asset.
@immutable
final class HouseholdEventRecord {
  /// Creates a household asset event record.
  const HouseholdEventRecord({
    required this.id,
    required this.assetId,
    required this.eventType,
    required this.eventDate,
    required this.title,
    this.cost,
    this.serviceProvider,
    this.evidenceDocumentId,
    this.notes,
  });

  /// Unique event ID.
  final String id;

  /// Linked household asset ID.
  final String assetId;

  /// Event type classification.
  final HouseholdEventType eventType;

  /// Date when event occurred.
  final DateTime eventDate;

  /// Short title (e.g., "Tyre Replacement", "Property Tax Q2").
  final String title;

  /// Financial cost incurred.
  final double? cost;

  /// Service provider or merchant name.
  final String? serviceProvider;

  /// Linked document evidence ID in vault storage.
  final String? evidenceDocumentId;

  /// Additional event notes.
  final String? notes;
}

/// Summary metrics for household assets and history.
@immutable
final class HouseholdOwnershipSummary {
  /// Creates ownership summary.
  const HouseholdOwnershipSummary({
    required this.totalAssetCount,
    required this.activeAssetCount,
    required this.totalValuation,
    required this.totalLifetimeExpenses,
    required this.activeWarrantyCount,
    required this.totalEventCount,
  });

  /// Total number of tracked items (including replaced & archived).
  final int totalAssetCount;

  /// Count of currently active operational items.
  final int activeAssetCount;

  /// Combined purchase valuation of active assets.
  final double totalValuation;

  /// Combined lifetime spend across all service, repair, and tax events.
  final double totalLifetimeExpenses;

  /// Count of items under active warranty.
  final int activeWarrantyCount;

  /// Total number of logged service/maintenance/tax events.
  final int totalEventCount;
}
