import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen presenting desktop Personal Life OS dual-pane layout & bulk import.
final class DesktopLifeOsScreen extends StatefulWidget {
  /// Creates the desktop Personal Life OS screen.
  const DesktopLifeOsScreen({required this.controller, super.key});

  /// Controller instance.
  final IngestionUiController controller;

  @override
  State<DesktopLifeOsScreen> createState() => _DesktopLifeOsScreenState();
}

final class _DesktopLifeOsScreenState extends State<DesktopLifeOsScreen> {
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

  void _triggerBulkImport() {
    widget.controller.processDesktopBulkImport(const <String>[
      '/Users/user/Desktop/tax_invoices_2026.pdf',
      '/Users/user/Desktop/car_service_receipt.jpg',
      '/Users/user/Desktop/passport_scan.pdf',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = widget.controller.desktopEngine;
    final cfg = desktop.windowConfig;
    final bulk = desktop.bulkImportProgress;
    final tr = widget.controller.multilingualEngine.translate;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('OwnKeep Desktop Personal Life OS')),
        actions: [
          IconButton(
            icon: Icon(Icons.view_sidebar),
            onPressed: widget.controller.toggleDesktopSidebar,
          ),
        ],
      ),
      body: Row(
        children: [
          if (cfg.isSidebarExpanded)
            NavigationRail(
              selectedIndex: 0,
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard),
                  label: Text(AppStrings.navLife.tr),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.hub),
                  label: Text(AppStrings.navGraph.tr),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history),
                  label: Text(AppStrings.navTimeline.tr),
                ),
              ],
            ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.withAlpha(200),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.desktop_mac, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppStrings
                                      .txtDesktopMobileGraphCompatibilityVerified
                                      .tr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  AppStrings.txtOwnKeep500Final.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings
                                .txtPreservesCompleteClaimProvenanceHistoryEvidenceAndGraphCompatibilityBetweenMobileAndDesktopWithoutCentralBackends
                                .tr,
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.txtDesktopLayoutModes.tr,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final mode in DesktopLayoutMode.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(mode.displayName),
                              selected: cfg.layoutMode == mode,
                              onSelected: (selected) {
                                if (selected) {
                                  widget.controller.setDesktopLayoutMode(mode);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings
                                .txtDesktopLargeScaleBulkImportDropzone
                                .tr,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings
                                .txtDragDropDirectoriesOrMultipleDocumentFilesForHighThroughputParallelOCRProcessing
                                .tr,
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          if (bulk != null) ...[
                            LinearProgressIndicator(value: bulk.fraction),
                            const SizedBox(height: 8),
                            Text(
                              bulk.statusMessage,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ] else ...[
                            Center(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.file_upload),
                                label: Text(AppStrings.simulateBulkDrop.tr),
                                onPressed: _triggerBulkImport,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
