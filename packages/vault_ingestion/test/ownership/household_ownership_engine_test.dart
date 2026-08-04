import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('HouseholdOwnershipEngine', () {
    late HouseholdOwnershipEngine engine;

    setUp(() {
      engine = HouseholdOwnershipEngine();
    });

    test('initializes default seed assets and events', () {
      expect(engine.assets, isNotEmpty);
      expect(engine.events, isNotEmpty);

      final summary = engine.getSummary(DateTime.utc(2026, 7, 26));
      expect(summary.totalAssetCount, equals(4));
      expect(summary.activeAssetCount, equals(3));
      expect(summary.totalValuation, greaterThan(10000000));
      expect(summary.totalLifetimeExpenses, equals(40850));
    });

    test('preserves full history trail after asset status change', () {
      final carEventsBefore = engine.getEventsForAsset('asset-car-1');
      expect(carEventsBefore.length, equals(2));

      // Transition vehicle status to REPLACED (Milestone 17 Gate)
      engine.updateAssetStatus('asset-car-1', HouseholdAssetStatus.replaced);

      final updated = engine.assets.firstWhere((a) => a.id == 'asset-car-1');
      expect(updated.status, equals(HouseholdAssetStatus.replaced));

      // Historical cost and evidence trail must remain 100% intact
      final carEventsAfter = engine.getEventsForAsset('asset-car-1');
      expect(carEventsAfter.length, equals(2));

      final lifetimeSpend = engine.calculateLifetimeExpense('asset-car-1');
      expect(lifetimeSpend, equals(26650));
    });

    test('filters assets by category and status cleanly', () {
      final vehicles = engine.queryAssets(
        category: HouseholdAssetCategory.vehicle,
      );
      expect(vehicles.length, equals(1));
      expect(vehicles.first.name, equals('Honda City ZX'));

      final activeOnly = engine.queryAssets(includeInactive: false);
      expect(activeOnly.length, equals(3));
    });

    test('logs new maintenance event and updates summary metrics', () {
      final initial = engine.calculateLifetimeExpense('asset-macbook-1');

      engine.logEvent(
        HouseholdEventRecord(
          id: 'event-macbook-battery-1',
          assetId: 'asset-macbook-1',
          eventType: HouseholdEventType.maintenance,
          eventDate: DateTime.utc(2026, 5, 20),
          title: 'Battery Diagnostics & Cleaning',
          cost: 2500,
          serviceProvider: 'Apple Authorized Service',
        ),
      );

      final updated = engine.calculateLifetimeExpense('asset-macbook-1');
      expect(updated, equals(initial + 2500));
    });
  });
}
