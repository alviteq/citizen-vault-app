import 'package:vault_domain/vault_domain.dart';

/// Pure, offline engine managing household inventory, vehicle history,
/// property tax/maintenance logs, and warranty tracking while keeping
/// current state and full historical cost trails distinct and queryable.
final class HouseholdOwnershipEngine {
  /// Creates an ownership engine initialized with optional seed items.
  HouseholdOwnershipEngine({
    List<HouseholdAssetRecord>? initialAssets,
    List<HouseholdEventRecord>? initialEvents,
  }) : _assets = Map<String, HouseholdAssetRecord>.fromEntries(
         (initialAssets ?? _defaultSeedAssets).map((a) => MapEntry(a.id, a)),
       ),
       _events = List<HouseholdEventRecord>.from(
         initialEvents ?? _defaultSeedEvents,
       );

  final Map<String, HouseholdAssetRecord> _assets;
  final List<HouseholdEventRecord> _events;

  /// Returns all tracked household assets.
  List<HouseholdAssetRecord> get assets =>
      List<HouseholdAssetRecord>.unmodifiable(_assets.values);

  /// Returns all logged cost and maintenance events.
  List<HouseholdEventRecord> get events =>
      List<HouseholdEventRecord>.unmodifiable(_events);

  /// Returns assets filtered by category and operational status.
  List<HouseholdAssetRecord> queryAssets({
    HouseholdAssetCategory? category,
    bool includeInactive = true,
  }) {
    return _assets.values
        .where((asset) {
          if (category != null && asset.category != category) return false;
          if (!includeInactive && asset.status != HouseholdAssetStatus.active) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Returns chronological event history for [assetId].
  List<HouseholdEventRecord> getEventsForAsset(String assetId) {
    final list = _events.where((e) => e.assetId == assetId).toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return List<HouseholdEventRecord>.unmodifiable(list);
  }

  /// Calculates total lifetime expenses for [assetId].
  double calculateLifetimeExpense(String assetId) {
    return _events
        .where((e) => e.assetId == assetId && e.cost != null)
        .fold(0, (sum, e) => sum + (e.cost ?? 0));
  }

  /// Calculates ownership summary analytics as of [asOf].
  HouseholdOwnershipSummary getSummary([DateTime? asOf]) {
    final now = asOf ?? DateTime.now();
    var activeCount = 0;
    var totalValuation = 0.0;
    var activeWarranties = 0;

    for (final asset in _assets.values) {
      if (asset.status == HouseholdAssetStatus.active) {
        activeCount++;
        totalValuation += asset.purchasePrice ?? 0;
      }
      if (asset.isWarrantyActive(now)) {
        activeWarranties++;
      }
    }

    final totalLifetimeExpenses = _events.fold<double>(
      0,
      (sum, e) => sum + (e.cost ?? 0),
    );

    return HouseholdOwnershipSummary(
      totalAssetCount: _assets.length,
      activeAssetCount: activeCount,
      totalValuation: totalValuation,
      totalLifetimeExpenses: totalLifetimeExpenses,
      activeWarrantyCount: activeWarranties,
      totalEventCount: _events.length,
    );
  }

  /// Adds or updates a household asset.
  void addOrUpdateAsset(HouseholdAssetRecord asset) {
    _assets[asset.id] = asset;
  }

  /// Updates an asset's operational status without mutating historical events.
  void updateAssetStatus(String assetId, HouseholdAssetStatus newStatus) {
    final existing = _assets[assetId];
    if (existing == null) return;
    _assets[assetId] = HouseholdAssetRecord(
      id: existing.id,
      name: existing.name,
      category: existing.category,
      status: newStatus,
      serialOrVinNumber: existing.serialOrVinNumber,
      location: existing.location,
      purchaseDate: existing.purchaseDate,
      purchasePrice: existing.purchasePrice,
      currency: existing.currency,
      warrantyProvider: existing.warrantyProvider,
      warrantyEndDate: existing.warrantyEndDate,
      notes: existing.notes,
    );
  }

  /// Logs a new maintenance, tax, repair, or service event.
  void logEvent(HouseholdEventRecord event) {
    _events.add(event);
  }

  static final List<HouseholdAssetRecord> _defaultSeedAssets = [
    HouseholdAssetRecord(
      id: 'asset-car-1',
      name: 'Honda City ZX',
      category: HouseholdAssetCategory.vehicle,
      status: HouseholdAssetStatus.active,
      serialOrVinNumber: 'MA3EWB2S00109283',
      location: 'Garage',
      purchaseDate: DateTime.utc(2023, 4, 15),
      purchasePrice: 1650000,
      warrantyProvider: 'Honda Shield Extended Warranty',
      warrantyEndDate: DateTime.utc(2028, 4, 14),
      notes: 'Registration MH-02-CB-4910 with HDFC ERGO.',
    ),
    HouseholdAssetRecord(
      id: 'asset-prop-1',
      name: 'Apartment 302 Green Meadows',
      category: HouseholdAssetCategory.property,
      status: HouseholdAssetStatus.active,
      serialOrVinNumber: 'PROPERTY-TAX-ID-99201',
      location: 'Bengaluru',
      purchaseDate: DateTime.utc(2021, 9),
      purchasePrice: 8500000,
      notes: 'Property Tax PID 102-W0192-302. Bescom 09281726.',
    ),
    HouseholdAssetRecord(
      id: 'asset-macbook-1',
      name: 'MacBook Pro 16" M2 Max',
      category: HouseholdAssetCategory.device,
      status: HouseholdAssetStatus.active,
      serialOrVinNumber: 'C02G9021MD6R',
      location: 'Home Office',
      purchaseDate: DateTime.utc(2023, 2, 10),
      purchasePrice: 309900,
      warrantyProvider: 'AppleCare+',
      warrantyEndDate: DateTime.utc(2026, 2, 9),
      notes: 'Includes AppleCare+ with accident protection.',
    ),
    HouseholdAssetRecord(
      id: 'asset-fridge-1',
      name: 'Samsung 580L Refrigerator',
      category: HouseholdAssetCategory.appliance,
      status: HouseholdAssetStatus.replaced,
      serialOrVinNumber: 'SS-RF580-992182',
      location: 'Kitchen',
      purchaseDate: DateTime.utc(2018, 6, 20),
      purchasePrice: 92000,
      notes: 'Replaced in 2025; preserved for historical cost records.',
    ),
  ];

  static final List<HouseholdEventRecord> _defaultSeedEvents = [
    HouseholdEventRecord(
      id: 'event-car-service-1',
      assetId: 'asset-car-1',
      eventType: HouseholdEventType.service,
      eventDate: DateTime.utc(2024, 4, 10),
      title: '1st Annual Full Service & Synthetic Oil Change',
      cost: 8450,
      serviceProvider: 'Honda Authorized Service (Dakshin Honda)',
      notes: 'Replaced oil filter, pollen filter, and wheel alignment.',
    ),
    HouseholdEventRecord(
      id: 'event-car-tyres-1',
      assetId: 'asset-car-1',
      eventType: HouseholdEventType.tyreChange,
      eventDate: DateTime.utc(2025, 3, 12),
      title: 'Front Michelin Primacy 4 Tyre Replacement',
      cost: 18200,
      serviceProvider: 'Bombay Tyre House',
      notes: 'Replaced 2 front tyres due to sidewall puncture.',
    ),
    HouseholdEventRecord(
      id: 'event-prop-tax-1',
      assetId: 'asset-prop-1',
      eventType: HouseholdEventType.taxPayment,
      eventDate: DateTime.utc(2025, 4, 30),
      title: 'BBMP Property Tax FY 2025-26 Payment',
      cost: 14200,
      serviceProvider: 'Bruhat Bengaluru Mahanagara Palike',
      notes: 'Paid online via BBMP portal with 5% discount.',
    ),
    HouseholdEventRecord(
      id: 'event-macbook-repair-1',
      assetId: 'asset-macbook-1',
      eventType: HouseholdEventType.repair,
      eventDate: DateTime.utc(2024, 11, 5),
      title: 'Liquid Spill Keyboard & Top Case Replacement',
      cost: 0,
      serviceProvider: 'Apple Authorized Service (Imagine)',
      notes: 'Covered 100% under AppleCare+ zero incident fee tier.',
    ),
  ];
}
