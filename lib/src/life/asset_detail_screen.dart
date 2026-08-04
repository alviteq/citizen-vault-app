import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Displays and manages one household asset using the encrypted vault model.
final class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({
    required this.controller,
    required this.assetId,
    super.key,
  });

  final IngestionUiController controller;
  final String assetId;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

final class _AssetDetailScreenState extends State<AssetDetailScreen> {
  HouseholdAssetRecord? get _asset {
    for (final asset in widget.controller.householdEngine.assets) {
      if (asset.id == widget.assetId) return asset;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    if (asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Asset')),
        body: const Center(child: Text('This asset is no longer available.')),
      );
    }

    final engine = widget.controller.householdEngine;
    final events = engine.getEventsForAsset(asset.id);
    final expense = engine.calculateLifetimeExpense(asset.id);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(asset.name),
        actions: [
          PopupMenuButton<HouseholdAssetStatus>(
            tooltip: 'Change status',
            initialValue: asset.status,
            onSelected: (status) {
              widget.controller.updateHouseholdAssetStatus(asset.id, status);
              setState(() {});
            },
            itemBuilder: (context) => [
              for (final status in HouseholdAssetStatus.values)
                PopupMenuItem(value: status, child: Text(status.displayName)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _AssetHeader(asset: asset),
          const SizedBox(height: 16),
          _section(
            title: 'Key information',
            children: [
              _InfoTile(
                icon: Icons.confirmation_number_outlined,
                label: 'Serial / VIN / property ID',
                value: asset.serialOrVinNumber ?? 'Not recorded',
              ),
              _InfoTile(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: asset.location ?? 'Not recorded',
              ),
              _InfoTile(
                icon: Icons.payments_outlined,
                label: 'Purchase price',
                value: asset.purchasePrice == null
                    ? 'Not recorded'
                    : '${asset.currency} ${asset.purchasePrice!.toStringAsFixed(0)}',
              ),
              _InfoTile(
                icon: Icons.verified_user_outlined,
                label: 'Warranty',
                value: _warrantyText(asset),
              ),
              if (asset.notes?.trim().isNotEmpty ?? false)
                _InfoTile(
                  icon: Icons.notes_outlined,
                  label: 'Notes',
                  value: asset.notes!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            title: 'History',
            trailing: Text(
              '${events.length} events • ${asset.currency} ${expense.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: events.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No service, expense, or maintenance events yet.',
                      ),
                    ),
                  ]
                : [
                    for (final event in events)
                      ListTile(
                        leading: CircleAvatar(
                          child: Icon(_eventIcon(event.eventType), size: 20),
                        ),
                        title: Text(event.title),
                        subtitle: Text(
                          [
                            _date(event.eventDate),
                            if (event.serviceProvider != null)
                              event.serviceProvider!,
                          ].join(' • '),
                        ),
                        trailing: event.cost == null
                            ? null
                            : Text(
                                '${asset.currency} ${event.cost!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                  ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_addEvent(asset)),
        icon: const Icon(Icons.add),
        label: const Text('Log event'),
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // ignore: use_null_aware_elements
                if (trailing != null) trailing,
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Future<void> _addEvent(HouseholdAssetRecord asset) async {
    final titleController = TextEditingController();
    final providerController = TextEditingController();
    final costController = TextEditingController();
    var type = HouseholdEventType.maintenance;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log asset event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<HouseholdEventType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: [
                    for (final value in HouseholdEventType.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.displayName),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: providerController,
                  decoration: const InputDecoration(
                    labelText: 'Provider (optional)',
                  ),
                ),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Cost in ${asset.currency} (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                titleController.text.trim().isNotEmpty,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave == true) {
      widget.controller.logHouseholdEvent(
        HouseholdEventRecord(
          id: 'event-${DateTime.now().microsecondsSinceEpoch}',
          assetId: asset.id,
          eventType: type,
          eventDate: DateTime.now().toUtc(),
          title: titleController.text.trim(),
          cost: double.tryParse(costController.text.trim()),
          serviceProvider: providerController.text.trim().isEmpty
              ? null
              : providerController.text.trim(),
        ),
      );
      if (mounted) setState(() {});
    }

    titleController.dispose();
    providerController.dispose();
    costController.dispose();
  }

  static String _warrantyText(HouseholdAssetRecord asset) {
    if (asset.warrantyProvider == null && asset.warrantyEndDate == null) {
      return 'Not recorded';
    }
    return [
      if (asset.warrantyProvider != null) asset.warrantyProvider!,
      if (asset.warrantyEndDate != null)
        'until ${_date(asset.warrantyEndDate!)}',
    ].join(' • ');
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  static IconData _eventIcon(HouseholdEventType type) => switch (type) {
    HouseholdEventType.purchase => Icons.shopping_bag_outlined,
    HouseholdEventType.service => Icons.car_repair_outlined,
    HouseholdEventType.maintenance => Icons.build_outlined,
    HouseholdEventType.repair => Icons.handyman_outlined,
    HouseholdEventType.tyreChange => Icons.tire_repair_outlined,
    HouseholdEventType.taxPayment => Icons.receipt_long_outlined,
    HouseholdEventType.utilityBill => Icons.bolt_outlined,
    HouseholdEventType.warrantyClaim => Icons.verified_outlined,
    HouseholdEventType.accessoryAdd => Icons.add_circle_outline,
    HouseholdEventType.ownershipTransfer => Icons.swap_horiz,
    HouseholdEventType.disposal => Icons.delete_outline,
  };
}

final class _AssetHeader extends StatelessWidget {
  const _AssetHeader({required this.asset});

  final HouseholdAssetRecord asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B4A99),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Icon(
              _categoryIcon(asset.category),
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.category.displayName,
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  asset.status.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _categoryIcon(HouseholdAssetCategory category) =>
      switch (category) {
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

final class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
