import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/add_new_screen.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/document_detail_screen.dart';
import 'package:citizen_vault_app/src/life/life_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Redesigned Home Screen (Screen 05)
final class LifeDashboardScreen extends StatefulWidget {
  const LifeDashboardScreen({
    required this.controller,
    required this.onOpenRecords,
    required this.onOpenInbox,
    super.key,
  });

  final IngestionUiController controller;
  final VoidCallback onOpenRecords;
  final VoidCallback onOpenInbox;

  @override
  State<LifeDashboardScreen> createState() => _LifeDashboardScreenState();
}

final class _LifeDashboardScreenState extends State<LifeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        widget.controller.loadDocuments(const DocumentLibraryFilter()),
      ); // Ensure we load recent records
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddNewScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.controller.documents;
    final isEmpty = docs.isEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: RefreshIndicator(
              onRefresh: () => widget.controller.loadDocuments(
                const DocumentLibraryFilter(),
              ),
              child: isEmpty ? _buildEmptyState() : _buildPopulatedState(docs),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.shield, size: 80, color: Color(0xFF2563EB)),
        const SizedBox(height: 24),
        Text(
          AppStrings.lblYourPrivateVaultReady.tr,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.msgStartProtectingImportant.tr,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // Quick Actions
        _buildActionCard(Icons.document_scanner, 'Scan a Document', _openAdd),
        const SizedBox(height: 12),
        _buildActionCard(Icons.upload_file, 'Import Files', _openAdd),
        const SizedBox(height: 12),
        _buildActionCard(Icons.photo_library, 'Add from Gallery', _openAdd),

        const SizedBox(height: 32),
        Text(
          AppStrings.msgEmptyVaultExamples.tr,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _openAdd,
          icon: const Icon(Icons.add),
          label: Text(AppStrings.lblAddFirstRecord.tr),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2563EB)),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildPopulatedState(List<dynamic> docs) {
    final upcoming =
        widget.controller.reminders
            .where((reminder) => reminder.isEnabled)
            .toList(growable: false)
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Menu'.tr,
                onPressed: _showHomeMenu,
                icon: const Icon(Icons.menu_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  AppStrings.lblGoodMorningUser.tr,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              CircleAvatar(
                backgroundColor: const Color(0xFFE2E8F0),
                radius: 18,
                child: Text(
                  AppStrings.txtT.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Security Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB7E7CA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Color(0xFF10B981), size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.lblEverythingIsSafe.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF16382A),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      AppStrings.lblOnThisDeviceEncrypted.tr,
                      style: TextStyle(
                        color: const Color(0xFF39725A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Upcoming
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            AppStrings.txtUpcoming.tr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              if (upcoming.isEmpty)
                _buildUpcomingCard(
                  'No upcoming reminders'.tr,
                  'Your confirmed reminders will appear here'.tr,
                  const Color(0xFF10B981),
                )
              else
                for (final reminder in upcoming.take(5))
                  _buildUpcomingCard(
                    reminder.title,
                    _relativeDue(reminder.dueAt),
                    reminder.dueAt.isBefore(DateTime.now())
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B),
                    onTap: () => _openReminderDocument(reminder),
                  ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Recent Records
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.txtRecentRecords.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: widget.onOpenRecords,
                child: Text(AppStrings.btnSeeAll.tr),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (
                    var i = 0;
                    i < (docs.length > 5 ? 5 : docs.length);
                    i++
                  ) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          docs[i].mimeType == 'application/pdf'
                              ? Icons.picture_as_pdf
                              : Icons.image,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      title: Text(
                        docs[i].logicalFilename,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF94A3B8),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DocumentDetailScreen(
                              controller: widget.controller,
                              documentId: docs[i].id,
                            ),
                          ),
                        );
                      },
                    ),
                    if (i < (docs.length > 5 ? 5 : docs.length) - 1)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Vault Summary & Activity
        Center(
          child: Column(
            children: [
              Text(
                '${docs.length} Records • '
                '${docs.map((document) => document.documentType).toSet().length} '
                'Categories',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.controller.attentionItems.length} need attention • '
                '${_backupStatus()}',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LifeTimelineScreen(controller: widget.controller),
                    ),
                  ),
                ),
                child: Text(
                  AppStrings.btnViewActivity.tr,
                  style: TextStyle(color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showHomeMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text('Documents'.tr),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onOpenRecords();
                },
              ),
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: Text(AppStrings.inboxTitle.tr),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onOpenInbox();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text('Add New'.tr),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAdd();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  String _relativeDue(DateTime value) {
    final days = value.difference(DateTime.now()).inDays;
    if (days < 0) return '${-days} days overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  String _backupStatus() {
    final backup = widget.controller.preferences.lastBackupAt;
    if (backup == null) return 'No verified backup yet';
    final local = backup.toLocal();
    return 'Last backup ${local.day}/${local.month}/${local.year}';
  }

  Future<void> _openReminderDocument(ReminderView reminder) async {
    final detail = await widget.controller.document(reminder.documentId);
    if (!mounted || detail == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          controller: widget.controller,
          documentId: reminder.documentId,
        ),
      ),
    );
  }
}
