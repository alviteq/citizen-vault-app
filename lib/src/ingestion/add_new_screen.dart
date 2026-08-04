import 'dart:convert';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/ingestion/document_scanner_screen.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/life/entity_directory_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

class AddNewScreen extends StatelessWidget {
  const AddNewScreen({required this.controller, super.key});

  final IngestionUiController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Add New'.tr),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.txtWhatWouldYouLikeToAdd.tr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 4 : 2;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: columns == 2 ? 1.45 : 1.35,
                    children: [
                      _AddOptionCard(
                        title: 'Scan Document',
                        icon: Icons.document_scanner_outlined,
                        iconColor: const Color(0xFF2563EB),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                DocumentScannerScreen(controller: controller),
                          ),
                        ),
                      ),
                      _AddOptionCard(
                        title: 'Camera',
                        icon: Icons.camera_alt_outlined,
                        iconColor: const Color(0xFF0F172A),
                        onTap: controller.captureImage,
                      ),
                      _AddOptionCard(
                        title: 'From Files',
                        icon: Icons.folder_outlined,
                        iconColor: const Color(0xFF2563EB),
                        onTap: controller.importFile,
                      ),
                      _AddOptionCard(
                        title: 'Person',
                        icon: Icons.person_outline,
                        iconColor: const Color(0xFF2563EB),
                        onTap: () => _openEntityDirectory(context, {
                          LifeEntityType.person,
                        }, 'People'),
                      ),
                      _AddOptionCard(
                        title: 'Vehicle',
                        icon: Icons.directions_car_outlined,
                        iconColor: const Color(0xFFEF4444),
                        onTap: () => _openEntityDirectory(context, {
                          LifeEntityType.vehicle,
                        }, 'Vehicles'),
                      ),
                      _AddOptionCard(
                        title: 'Property',
                        icon: Icons.home_outlined,
                        iconColor: const Color(0xFFF97316),
                        onTap: () => _openEntityDirectory(context, {
                          LifeEntityType.property,
                        }, 'Properties'),
                      ),
                      _AddOptionCard(
                        title: 'Policy / Insurance',
                        icon: Icons.shield_outlined,
                        iconColor: const Color(0xFF10B981),
                        onTap: () => _openEntityDirectory(context, {
                          LifeEntityType.organisation,
                        }, 'Insurance'),
                      ),
                      _AddOptionCard(
                        title: 'Other',
                        icon: Icons.more_horiz,
                        iconColor: const Color(0xFF64748B),
                        onTap: () =>
                            _openEntityDirectory(context, null, 'Records'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(
                'More ways'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.photo_library_outlined,
                        color: Color(0xFF10B981),
                      ),
                      title: Text('From Gallery'.tr),
                      subtitle: Text('Import existing images'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: controller.importGalleryImage,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.edit_note,
                        color: Color(0xFF8B5CF6),
                      ),
                      title: Text('Encrypted Note'.tr),
                      subtitle: Text('Create a private text record'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _createNote(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _openEntityDirectory(
    BuildContext context,
    Set<LifeEntityType>? types,
    String title,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EntityDirectoryScreen(
          controller: controller,
          initialTypes: types,
          title: title,
        ),
      ),
    );
  }

  Future<void> _createNote(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create encrypted note'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: InputDecoration(labelText: 'Title'.tr),
            ),
            TextField(
              controller: body,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(labelText: 'Note'.tr),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
    if (shouldSave != true || body.text.trim().isEmpty) {
      title.dispose();
      body.dispose();
      return;
    }
    final bytes = utf8.encode(body.text.trim());
    final safeTitle = title.text.trim().isEmpty
        ? 'Note-${DateTime.now().millisecondsSinceEpoch}'
        : title.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '');
    await controller.importCandidate(
      IngestionCandidate(
        logicalFilename: '$safeTitle.txt',
        mimeType: 'text/plain',
        length: bytes.length,
        source: DocumentImportSource.filePicker,
        openRead: () => Stream<List<int>>.value(bytes),
      ),
    );
    title.dispose();
    body.dispose();
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _AddOptionCard extends StatelessWidget {
  const _AddOptionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: iconColor),
                const SizedBox(height: 10),
                Text(
                  title.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
