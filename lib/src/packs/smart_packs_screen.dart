import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Versioned, user-customizable organizational packs.
final class SmartPacksScreen extends StatefulWidget {
  /// Creates the encrypted Smart Pack directory.
  const SmartPacksScreen({required this.controller, super.key});

  /// Unlocked vault controller.
  final IngestionUiController controller;

  @override
  State<SmartPacksScreen> createState() => _SmartPacksScreenState();
}

final class _SmartPacksScreenState extends State<SmartPacksScreen> {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        AppStrings.smartPacksTitle.tr,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Color(0xFF0F172A),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'About templates',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppStrings.txtOrganizationalGuidance.tr),
              content: Text(OrganizingPackRegistry.guidanceDisclaimer),
            ),
          ),
          icon: const Icon(Icons.info_outline, color: Color(0xFF64748B)),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: Text(AppStrings.smartPacksTitle.tr),
    ),
    body: widget.controller.smartPacks.isEmpty
        ? _EmptyPacks(onCreate: _create)
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const _SafetyBanner(),
              const SizedBox(height: 12),
              for (final pack in widget.controller.smartPacks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PackCard(
                    pack: pack,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (context) => SmartPackDetailScreen(
                          controller: widget.controller,
                          packId: pack.id,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );

  Future<void> _create() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppStrings.txtCreateASmartPack.tr),
              subtitle: Text(
                AppStrings
                    .txtTemplatesGuideOrganizationAndNeverChangeYourFacts
                    .tr,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(AppStrings.txtUseAnOfflineTemplate.tr),
              onTap: () => Navigator.pop(context, 'preset'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: Text(AppStrings.txtCreateACustomPack.tr),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'preset') await _createPreset();
    if (action == 'custom') await _createCustom();
  }

  Future<void> _createPreset() async {
    var preset = OrganizingPackRegistry.presets.first;
    var includeIndia = false;
    String? entityId;
    final title = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.txtOfflinePackTemplate.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SmartPackPresetDefinition>(
                  initialValue: preset,
                  decoration: const InputDecoration(labelText: 'Template'),
                  items: [
                    for (final candidate in OrganizingPackRegistry.presets)
                      DropdownMenuItem(
                        value: candidate,
                        child: Text(candidate.title),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => preset = value ?? preset),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Custom title (optional)',
                  ),
                ),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Related profile (optional)',
                  ),
                  items: [
                    DropdownMenuItem(child: Text(AppStrings.txtWholeVault.tr)),
                    for (final entity in widget.controller.entities.where(
                      (entity) => entity.status == LifeEntityStatus.active,
                    ))
                      DropdownMenuItem(
                        value: entity.id,
                        child: Text(entity.displayName),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() => entityId = value),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: includeIndia,
                  title: Text(AppStrings.txtAddIndiaPackSuggestions.tr),
                  subtitle: Text(
                    AppStrings
                        .txtOptionalCountrySpecificGuidanceNotLegalAdvice
                        .tr,
                  ),
                  onChanged: (value) =>
                      setDialogState(() => includeIndia = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.btnCancel.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.btnCreate.tr),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await widget.controller.createSmartPack(
        presetId: preset.id,
        title: title.text,
        entityId: entityId,
        includeIndiaPack: includeIndia,
      );
    }
    title.dispose();
  }

  Future<void> _createCustom() async {
    final title = TextEditingController();
    final items = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.txtCustomSmartPack.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Pack title'),
            ),
            TextField(
              controller: items,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Items',
                helperText: 'One organizational item per line',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.btnCancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.btnCreate.tr),
          ),
        ],
      ),
    );
    if (accepted == true &&
        title.text.trim().isNotEmpty &&
        items.text.trim().isNotEmpty) {
      await widget.controller.createCustomSmartPack(
        title: title.text,
        items: items.text.split('\n'),
      );
    }
    title.dispose();
    items.dispose();
  }
}

/// Completeness, customization, linking, and export preparation for one Pack.
final class SmartPackDetailScreen extends StatefulWidget {
  /// Creates a detail view for one encrypted Pack.
  const SmartPackDetailScreen({
    required this.controller,
    required this.packId,
    super.key,
  });

  /// Unlocked vault controller.
  final IngestionUiController controller;

  /// Stable encrypted Pack identifier.
  final String packId;

  @override
  State<SmartPackDetailScreen> createState() => _SmartPackDetailScreenState();
}

final class _SmartPackDetailScreenState extends State<SmartPackDetailScreen> {
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

  SmartPack? get _pack => widget.controller.smartPacks
      .where((pack) => pack.id == widget.packId)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    if (pack == null) {
      return Scaffold(
        body: Center(child: Text(AppStrings.txtPackIsArchived.tr)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          pack.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Color(0xFF64748B)),
            onSelected: (value) {
              if (value == 'add') unawaited(_addItem(pack));
              if (value == 'archive') unawaited(_archive(pack));
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add',
                child: Text(AppStrings.txtAddCustomItem.tr),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text(AppStrings.txtArchivePack.tr),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${pack.completenessPercent}% organized',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text('${pack.satisfiedCount}/${pack.applicableCount}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: pack.applicableCount == 0
                        ? 0
                        : pack.satisfiedCount / pack.applicableCount,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Template ${pack.templateId} v${pack.templateVersion}'
                    '${pack.countryCode == null ? '' : ' · '
                              '${pack.countryCode}'}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(AppStrings.txtGuidanceNotARequirement.tr),
              subtitle: Text(pack.guidanceDisclaimer),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text(
              AppStrings.txtORGANIZATIONALITEMS.tr,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final item in pack.items)
            _PackItemCard(
              item: item,
              onCustomize: () => _customize(item),
              onLink: () => _link(item),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _prepareExport(pack),
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(AppStrings.txtReviewExportPreparation.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _customize(SmartPackItem item) async {
    final label = TextEditingController(text: item.label);
    var enabled = item.isEnabled;
    var optional = item.isOptional;
    var export = item.includeInExport;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.txtCustomizeItem.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  title: Text(AppStrings.txtAppliesToMe.tr),
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: optional,
                  title: Text(AppStrings.txtOptional.tr),
                  onChanged: (value) => setDialogState(() => optional = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: export,
                  title: Text(AppStrings.txtPrepareEvidenceForExport.tr),
                  subtitle: Text(
                    AppStrings.txtDoesNotCreateAPlaintextExport.tr,
                  ),
                  onChanged: (value) => setDialogState(() => export = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.btnCancel.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.btnSave.tr),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && label.text.trim().isNotEmpty) {
      await widget.controller.customizeSmartPackItem(
        itemId: item.id,
        label: label.text,
        isEnabled: enabled,
        isOptional: optional,
        includeInExport: export,
      );
    }
    label.dispose();
  }

  Future<void> _link(SmartPackItem item) async {
    final selection = await showModalBottomSheet<({String type, String id})>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(AppStrings.txtLinkExistingInformation.tr),
              subtitle: Text(
                AppStrings
                    .txtLinksSupportOrganizationTheyDoNotChangeTheSource
                    .tr,
              ),
            ),
            for (final document in widget.controller.dashboardDocuments)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(document.logicalFilename),
                subtitle: Text(AppStrings.txtEncryptedEvidence.tr),
                onTap: () =>
                    Navigator.pop(context, (type: 'document', id: document.id)),
              ),
            for (final event in widget.controller.events)
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(event.title),
                subtitle: Text(AppStrings.txtLifeEvent.tr),
                onTap: () =>
                    Navigator.pop(context, (type: 'event', id: event.id)),
              ),
            for (final task in widget.controller.tasks)
              ListTile(
                leading: const Icon(Icons.task_alt_outlined),
                title: Text(task.title),
                subtitle: Text(AppStrings.btnTask.tr),
                onTap: () =>
                    Navigator.pop(context, (type: 'task', id: task.id)),
              ),
            if (widget.controller.dashboardDocuments.isEmpty &&
                widget.controller.events.isEmpty &&
                widget.controller.tasks.isEmpty)
              ListTile(title: Text(AppStrings.txtNoLinkableInformationYet.tr)),
          ],
        ),
      ),
    );
    if (selection == null) return;
    await widget.controller.linkSmartPackItem(
      itemId: item.id,
      documentId: selection.type == 'document' ? selection.id : null,
      eventId: selection.type == 'event' ? selection.id : null,
      taskId: selection.type == 'task' ? selection.id : null,
    );
  }

  Future<void> _addItem(SmartPack pack) async {
    final label = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.txtAddCustomItem.tr),
        content: TextField(
          controller: label,
          decoration: const InputDecoration(labelText: 'Organizational item'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.btnCancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.btnAdd.tr),
          ),
        ],
      ),
    );
    if (accepted == true && label.text.trim().isNotEmpty) {
      await widget.controller.addSmartPackItem(
        packId: pack.id,
        label: label.text,
      );
    }
    label.dispose();
  }

  Future<void> _prepareExport(SmartPack pack) async {
    final ids = await widget.controller.smartPackExportDocuments(pack.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.txtExportPreparation.tr),
        content: Text(
          '${ids.length} encrypted record${ids.length == 1 ? '' : 's'} '
          'selected.\n\nNo plaintext copy was created. Privacy-aware export '
          'and redaction are delivered in a later milestone.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.btnDone.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _archive(SmartPack pack) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.btnArchiveThisPack.tr),
        content: Text(
          AppStrings.btnLinkedClaimsEventsTasksAndEvidenceRemainUnchanged.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.btnCancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.btnArchive.tr),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await widget.controller.archiveSmartPack(pack.id);
      if (mounted) Navigator.pop(context);
    }
  }
}

final class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack, required this.onTap});

  final SmartPack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF1F5F9)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // Soft Grey
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon(pack.type), color: const Color(0xFF0F172A)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pack.type.displayName} · '
                        '${pack.completenessPercent}% organized',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pack.applicableCount == 0
                    ? 0
                    : pack.satisfiedCount / pack.applicableCount,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF10B981),
                ), // Emerald Green
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${pack.satisfiedCount} of ${pack.applicableCount} applicable '
              'items linked or found',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    ),
  );

  static IconData _icon(SmartPackType type) => switch (type) {
    SmartPackType.vehicle => Icons.directions_car_outlined,
    SmartPackType.home => Icons.home_outlined,
    SmartPackType.travel => Icons.flight_outlined,
    SmartPackType.health => Icons.health_and_safety_outlined,
    SmartPackType.education => Icons.school_outlined,
    SmartPackType.emergency => Icons.emergency_outlined,
    SmartPackType.custom => Icons.inventory_2_outlined,
  };
}

final class _PackItemCard extends StatelessWidget {
  const _PackItemCard({
    required this.item,
    required this.onCustomize,
    required this.onLink,
  });

  final SmartPackItem item;
  final VoidCallback onCustomize;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF1F5F9)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              !item.isEnabled
                  ? Icons.remove_circle_outline
                  : item.isSatisfied
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 22,
              color: !item.isEnabled
                  ? const Color(0xFF94A3B8)
                  : item.isSatisfied
                  ? const Color(0xFF10B981)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: !item.isEnabled
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0F172A),
                    decoration: !item.isEnabled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !item.isEnabled
                      ? 'Not applicable'
                      : item.isSatisfied
                      ? 'Linked or found'
                      : item.isOptional
                      ? 'Optional · not found'
                      : 'Not found',
                  style: TextStyle(
                    fontSize: 12,
                    color: item.isSatisfied
                        ? const Color(0xFF10B981)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.guidance,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                if (item.linkedDocumentId != null ||
                    item.linkedEventId != null ||
                    item.linkedTaskId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (item.linkedDocumentId != null)
                          Chip(
                            label: Text(
                              AppStrings.txtEvidence.tr,
                              style: TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (item.linkedEventId != null)
                          Chip(
                            label: Text(
                              AppStrings.txtEvent.tr,
                              style: TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (item.linkedTaskId != null)
                          Chip(
                            label: Text(
                              AppStrings.btnTask.tr,
                              style: TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
            onSelected: (value) => value == 'link' ? onLink() : onCustomize(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'link',
                child: Text(AppStrings.txtLinkInformation.tr),
              ),
              PopupMenuItem(
                value: 'customize',
                child: Text(AppStrings.txtCustomize.tr),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF), // Soft Blue
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFBFDBFE)),
    ),
    child: Row(
      children: [
        const Icon(Icons.verified_user_outlined, color: Color(0xFF1D4ED8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.txtYourFactsRemainYours.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings
                    .txtChangingATemplateOnlyChangesThisChecklistItNeverChangesConfirmedFactsOrClaimsThatAnItemIsLegallyRequired
                    .tr,
                style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _EmptyPacks extends StatelessWidget {
  const _EmptyPacks({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            AppStrings.txtNoSmartPacksYet.tr,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings
                .txtCreateAPrivateOrganizationalChecklistFromAnOfflineTemplateOrMakeYourOwn
                .tr,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(AppStrings.txtCreateSmartPack.tr),
          ),
        ],
      ),
    ),
  );
}
