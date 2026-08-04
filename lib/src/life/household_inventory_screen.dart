import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/life/asset_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen presenting household inventory, vehicle, and device tracking.
final class HouseholdInventoryScreen extends StatefulWidget {
  /// Creates the household inventory and ownership tracking screen.
  const HouseholdInventoryScreen({required this.controller, super.key});

  /// Ingestion and presentation controller.
  final IngestionUiController controller;

  @override
  State<HouseholdInventoryScreen> createState() =>
      _HouseholdInventoryScreenState();
}

final class _HouseholdInventoryScreenState
    extends State<HouseholdInventoryScreen> {
  HouseholdAssetCategory? _selectedCategory;
  var _searchQuery = '';
  var _showInactive = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  IconData _iconForCategory(HouseholdAssetCategory category) {
    return switch (category) {
      HouseholdAssetCategory.vehicle => Icons.directions_car,
      HouseholdAssetCategory.property => Icons.home_work,
      HouseholdAssetCategory.device => Icons.laptop_mac,
      HouseholdAssetCategory.appliance => Icons.kitchen,
      HouseholdAssetCategory.electronics => Icons.tv,
      HouseholdAssetCategory.jewellery => Icons.diamond,
      HouseholdAssetCategory.furniture => Icons.chair,
      HouseholdAssetCategory.other => Icons.inventory_2,
    };
  }

  Color _colorForStatus(HouseholdAssetStatus status) {
    return switch (status) {
      HouseholdAssetStatus.active => Colors.green,
      HouseholdAssetStatus.repaired => Colors.orange,
      HouseholdAssetStatus.replaced => Colors.blueGrey,
      HouseholdAssetStatus.sold => Colors.purple,
      HouseholdAssetStatus.disposed => Colors.redAccent,
      HouseholdAssetStatus.archived => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.controller.householdEngine;
    final summary = engine.getSummary();
    final allAssets = engine.queryAssets(
      category: _selectedCategory,
      includeInactive: _showInactive,
    );

    final filteredAssets = allAssets.where((asset) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatch = asset.name.toLowerCase().contains(q);
      final idMatch =
          asset.serialOrVinNumber?.toLowerCase().contains(q) ?? false;
      final locMatch = asset.location?.toLowerCase().contains(q) ?? false;
      return nameMatch || idMatch || locMatch;
    }).toList();

    final valuationText = '₹${summary.totalValuation.toStringAsFixed(0)}';
    final lifetimeExpenseText =
        '₹${summary.totalLifetimeExpenses.toStringAsFixed(0)}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          AppStrings.txtHouseholdOwnership.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            icon: Icon(
              _showInactive ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF64748B),
            ),
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4), // Soft Green
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.txtActiveValuation.tr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  valuationText,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF14532D),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${summary.activeAssetCount} Active Items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED), // Soft Orange
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.lifetimeSpendLabel.tr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9A3412),
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  lifetimeExpenseText,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C2D12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${summary.totalEventCount} Service/Tax Logs',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9A3412),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText:
                          'Search vehicles, devices, properties, serials...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0B4A99),
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          selected: _selectedCategory == null,
                          label: Text(AppStrings.txtAllCategories.tr),
                          onSelected: (_) =>
                              setState(() => _selectedCategory = null),
                        ),
                        const SizedBox(width: 8),
                        ...HouseholdAssetCategory.values.map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: _selectedCategory == cat,
                              avatar: Icon(_iconForCategory(cat), size: 16),
                              label: Text(cat.displayName),
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = cat),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (filteredAssets.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(AppStrings.noMatchingAssets.tr)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final asset = filteredAssets[index];
                  final lifetimeSpend = engine.calculateLifetimeExpense(
                    asset.id,
                  );
                  final eventCount = engine.getEventsForAsset(asset.id).length;
                  final priceStr = asset.purchasePrice?.toStringAsFixed(0);
                  final spendStr = lifetimeSpend.toStringAsFixed(0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF), // Soft Blue
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _iconForCategory(asset.category),
                          color: const Color(0xFF0B4A99),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              asset.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _colorForStatus(
                                asset.status,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _colorForStatus(
                                  asset.status,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              asset.status.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _colorForStatus(asset.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (asset.serialOrVinNumber != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'ID/VIN: ${asset.serialOrVinNumber}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                if (priceStr != null)
                                  Text(
                                    'Price: ₹$priceStr',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                if (lifetimeSpend > 0) ...[
                                  const Text(
                                    ' • ',
                                    style: TextStyle(color: Color(0xFFCBD5E1)),
                                  ),
                                  Text(
                                    'Spend: ₹$spendStr',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (eventCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '$eventCount service & maintenance events',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF94A3B8),
                      ),
                      onTap: () {
                        unawaited(
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AssetDetailScreen(
                                controller: widget.controller,
                                assetId: asset.id,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }, childCount: filteredAssets.length),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(AppStrings.btnAddItem.tr),
        onPressed: () => unawaited(_showAddAssetDialog(context)),
      ),
    );
  }

  Future<void> _showAddAssetDialog(BuildContext dialogContext) async {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    var category = HouseholdAssetCategory.device;

    await showDialog<void>(
      context: dialogContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(AppStrings.txtAddHouseholdItem.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    hintText: 'e.g. Sony Bravia 55" OLED',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<HouseholdAssetCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: HouseholdAssetCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => category = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Serial / VIN / Tax ID',
                    hintText: 'e.g. SN-99218201',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Purchase Price (₹)',
                    hintText: 'e.g. 75000',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g. Living Room',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppStrings.btnCancel.tr),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final price = double.tryParse(priceCtrl.text.trim());
                final newAsset = HouseholdAssetRecord(
                  id: 'asset-${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  category: category,
                  status: HouseholdAssetStatus.active,
                  serialOrVinNumber: idCtrl.text.trim().isEmpty
                      ? null
                      : idCtrl.text.trim(),
                  purchasePrice: price,
                  location: locationCtrl.text.trim().isEmpty
                      ? null
                      : locationCtrl.text.trim(),
                  purchaseDate: DateTime.now(),
                );
                widget.controller.addOrUpdateHouseholdAsset(newAsset);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('$name added to household inventory.'),
                  ),
                );
              },
              child: Text(AppStrings.txtSaveItem.tr),
            ),
          ],
        ),
      ),
    );
  }
}
