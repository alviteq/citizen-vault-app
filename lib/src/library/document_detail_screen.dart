import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/full_document_screen.dart';
import 'package:citizen_vault_app/src/library/privacy_sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Redesigned Document Detail (Screen 10)
final class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    required this.controller,
    required this.documentId,
    super.key,
  });

  final IngestionUiController controller;
  final String documentId;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

final class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late Future<DocumentDetailView?> _detail;
  late Future<Uint8List?> _preview;
  late Future<List<LifeEntity>> _linkedEntities;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _detail = widget.controller.document(widget.documentId);
    _preview = widget.controller.documentPreview(widget.documentId);
    _linkedEntities = widget.controller.entitiesForDocument(widget.documentId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentDetailView?>(
      future: _detail,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(elevation: 0),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 12),
                  Text('Document could not be opened.'.tr),
                  TextButton(onPressed: _reload, child: Text('Retry'.tr)),
                ],
              ),
            ),
          );
        }
        if (detail == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(elevation: 0),
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            ),
          );
        }

        final isPdf = detail.summary.mimeType == 'application/pdf';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              detail.summary.logicalFilename,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'rename') {
                    unawaited(_rename(detail));
                  } else if (action == 'trash') {
                    unawaited(_moveToTrash(detail));
                  } else if (action == 'reprocess') {
                    unawaited(_reprocess(detail));
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem(value: 'rename', child: Text('Rename'.tr)),
                  PopupMenuItem(
                    value: 'reprocess',
                    child: Text('Reprocess OCR and details'.tr),
                  ),
                  PopupMenuItem(
                    value: 'trash',
                    child: Text('Move to trash'.tr),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // Preview
                Container(
                  width: double.infinity,
                  height: 280,
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: AspectRatio(
                        aspectRatio: 1 / 1.414,
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FutureBuilder<Uint8List?>(
                            future: _preview,
                            builder: (context, previewSnap) {
                              if (previewSnap.hasData &&
                                  previewSnap.data != null) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    previewSnap.data!,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              }
                              return Center(
                                child: Icon(
                                  isPdf ? Icons.picture_as_pdf : Icons.image,
                                  size: 64,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Actions Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionIcon(
                        Icons.open_in_new,
                        'Open',
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => FullDocumentScreen(
                              controller: widget.controller,
                              detail: detail,
                            ),
                          ),
                        ),
                      ),
                      _buildActionIcon(
                        Icons.share_outlined,
                        'Share',
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => PrivacySharingScreen(
                              controller: widget.controller,
                              detail: detail,
                            ),
                          ),
                        ),
                      ),
                      _buildActionIcon(
                        detail.summary.isFavourite
                            ? Icons.favorite
                            : Icons.favorite_outline,
                        'Favourite',
                        color: detail.summary.isFavourite
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0F172A),
                        onTap: () async {
                          await widget.controller.setFavourite(
                            detail.summary.id,
                            !detail.summary.isFavourite,
                          );
                          if (mounted) {
                            setState(_reload);
                          }
                        },
                      ),
                      _buildActionIcon(
                        Icons.archive_outlined,
                        detail.summary.isArchived ? 'Unarchive' : 'Archive',
                        onTap: () async {
                          await widget.controller.setArchived(
                            detail.summary.id,
                            !detail.summary.isArchived,
                          );
                          if (mounted) {
                            setState(_reload);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // File Information
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.txtFileInformation.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFileInfoStat(isPdf ? 'PDF' : 'Image', 'Type'),
                            _buildFileInfoStat('Encrypted', 'Storage'),
                            _buildFileInfoStat(
                              '${detail.summary.importedAt.day}/${detail.summary.importedAt.month}/${detail.summary.importedAt.year}',
                              'Added',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Tags
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DetailSection(
                    title: 'Tags'.tr,
                    action: TextButton.icon(
                      onPressed: () => _editTags(detail),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text('Edit'.tr),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: detail.summary.tags.isEmpty
                          ? <Widget>[Text('No tags'.tr)]
                          : detail.summary.tags
                                .map((tag) => Chip(label: Text(tag.name)))
                                .toList(growable: false),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Extracted Information
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DetailSection(
                    title: AppStrings.txtExtractedInformation.tr,
                    action: TextButton.icon(
                      onPressed: () => _changeType(detail),
                      icon: const Icon(Icons.category_outlined),
                      label: Text(detail.summary.documentType.displayName),
                    ),
                    child: detail.fields.isEmpty
                        ? Text('No extracted fields'.tr)
                        : Column(
                            children: [
                              for (
                                int i = 0;
                                i < detail.fields.length;
                                i++
                              ) ...[
                                _buildFieldRow(
                                  detail.fields[i].type.displayName,
                                  detail.fields[i].effectiveValue,
                                ),
                                if (i < detail.fields.length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DetailSection(
                    title: 'Linked to'.tr,
                    action: TextButton.icon(
                      onPressed: () => _linkToEntity(detail),
                      icon: const Icon(Icons.link),
                      label: Text('Link'.tr),
                    ),
                    child: FutureBuilder<List<LifeEntity>>(
                      future: _linkedEntities,
                      builder: (context, linkedSnapshot) {
                        final entities =
                            linkedSnapshot.data ?? const <LifeEntity>[];
                        if (linkedSnapshot.connectionState !=
                            ConnectionState.done) {
                          return const LinearProgressIndicator();
                        }
                        if (entities.isEmpty) {
                          return Text('No linked people, things or places'.tr);
                        }
                        return Column(
                          children: [
                            for (final entity in entities)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.link_outlined),
                                title: Text(entity.displayName),
                                subtitle: Text(entity.type.name.tr),
                                trailing: IconButton(
                                  tooltip: 'Unlink'.tr,
                                  icon: const Icon(Icons.link_off_outlined),
                                  onPressed: () =>
                                      _unlinkEntity(detail, entity),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // OCR text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DetailSection(
                    title: 'OCR text'.tr,
                    child: detail.textPages.isEmpty
                        ? Text('No recognized text'.tr)
                        : Column(
                            children: [
                              for (final page in detail.textPages)
                                ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Text(
                                    page.pageNumber == null
                                        ? 'Recognized text'.tr
                                        : 'Page ${page.pageNumber}'.tr,
                                  ),
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: SelectableText(page.text),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Reminders
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DetailSection(
                    title: AppStrings.remindersTitle.tr,
                    action: TextButton.icon(
                      onPressed: () => _addReminder(detail),
                      icon: const Icon(Icons.add_alert_outlined),
                      label: Text('Add'.tr),
                    ),
                    child: _DocumentReminderList(
                      reminders: widget.controller.reminders
                          .where(
                            (reminder) =>
                                reminder.documentId == detail.summary.id,
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),

                // Reminders
                if (detail.summary.expiryAt != null) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.remindersTitle.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFEF2F2,
                            ), // Red tint for expiry
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFDC2626),
                              ),
                              title: Text(
                                'Expires in ${detail.summary.expiryAt!.difference(DateTime.now()).inDays} days',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                              subtitle: Text(
                                AppStrings.txtActiveReminderSet.tr,
                                style: TextStyle(color: Color(0xFFDC2626)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DetailSection(
                    title: 'Processing history'.tr,
                    child: detail.processingHistory.isEmpty
                        ? Text('No processing history'.tr)
                        : Column(
                            children: [
                              for (final step in detail.processingHistory)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    step.status == 'COMPLETED'
                                        ? Icons.check_circle_outline
                                        : Icons.sync_outlined,
                                  ),
                                  title: Text(step.stepName),
                                  subtitle: Text(
                                    '${step.status} · ${step.attemptCount} attempt(s)',
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editTags(DocumentDetailView detail) async {
    final input = TextEditingController(
      text: detail.summary.tags.map((tag) => tag.name).join(', '),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit tags'.tr),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Identity, tax, family'.tr,
            helperText: 'Separate tags with commas.'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
    input.dispose();
    if (value == null) return;
    await widget.controller.replaceTags(detail.summary.id, value.split(','));
    if (mounted) setState(_reload);
  }

  Future<void> _changeType(DocumentDetailView detail) async {
    final selected = await showModalBottomSheet<DocumentType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text('Document type'.tr)),
            for (final type in DocumentType.values)
              RadioListTile<DocumentType>(
                value: type,
                // TODO: Migrate to RadioGroup when the minimum Flutter SDK
                // includes a stable bottom-sheet example for dynamic options.
                // ignore: deprecated_member_use
                groupValue: detail.summary.documentType,
                title: Text(type.displayName),
                // ignore: deprecated_member_use
                onChanged: (value) => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == detail.summary.documentType) return;
    await widget.controller.setDocumentType(detail.summary.id, selected);
    if (mounted) setState(_reload);
  }

  Future<void> _addReminder(DocumentDetailView detail) async {
    final now = DateTime.now();
    final suggested =
        detail.summary.expiryAt ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
      initialDate: suggested.isBefore(now) ? now : suggested,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;
    await widget.controller.createReminder(
      ReminderDraft(
        documentId: detail.summary.id,
        type: detail.summary.expiryAt == null
            ? ReminderType.custom
            : ReminderType.expiry,
        title: detail.summary.expiryAt == null
            ? 'Review ${detail.summary.logicalFilename}'
            : '${detail.summary.logicalFilename} expires',
        dueAt: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _linkToEntity(DocumentDetailView detail) async {
    final entities = widget.controller.entities
        .where((entity) => entity.status == LifeEntityStatus.active)
        .toList(growable: false);
    if (!mounted) return;
    if (entities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Create a person, thing or place before linking this record.'.tr,
          ),
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<LifeEntity>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text('Link record to'.tr)),
            for (final entity in entities)
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(entity.displayName),
                subtitle: Text(entity.type.name.tr),
                onTap: () => Navigator.pop(context, entity),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await widget.controller.linkDocumentEvidence(
      entityId: selected.id,
      documentId: detail.summary.id,
    );
    if (mounted) setState(_reload);
  }

  Future<void> _unlinkEntity(
    DocumentDetailView detail,
    LifeEntity entity,
  ) async {
    await widget.controller.unlinkDocumentEvidence(
      entityId: entity.id,
      documentId: detail.summary.id,
    );
    if (mounted) setState(_reload);
  }

  Future<void> _rename(DocumentDetailView detail) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameRecordDialog(initialName: detail.summary.logicalFilename),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await widget.controller.renameDocument(detail.summary.id, name);
    if (mounted) setState(_reload);
  }

  Future<void> _moveToTrash(DocumentDetailView detail) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Move record to trash?'.tr),
            content: Text(
              'The encrypted original can be restored from Recently Deleted.'
                  .tr,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'.tr),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Move to trash'.tr),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.controller.moveDocumentsToTrash(<String>[detail.summary.id]);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _reprocess(DocumentDetailView detail) async {
    await widget.controller.reprocessDocument(detail.summary.id);
    if (!mounted) return;
    setState(_reload);
    final job = widget.controller.jobs
        .where((candidate) => candidate.documentId == detail.summary.id)
        .firstOrNull;
    final message = switch (job?.status) {
      DocumentProcessingStatus.awaitingReview ||
      DocumentProcessingStatus.ready => 'OCR and document details updated.',
      DocumentProcessingStatus.retryScheduled =>
        'OCR could not finish. A retry is scheduled (${job?.safeErrorCode ?? 'temporary OCR error'}).',
      DocumentProcessingStatus.failed =>
        'OCR failed (${job?.safeErrorCode ?? 'unknown error'}).',
      _ => 'Document processing is still in progress.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.tr)));
  }

  Widget _buildActionIcon(
    IconData icon,
    String label, {
    Color color = const Color(0xFF0F172A),
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label.tr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfoStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.tr,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label.tr,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

final class _RenameRecordDialog extends StatefulWidget {
  const _RenameRecordDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameRecordDialog> createState() => _RenameRecordDialogState();
}

final class _RenameRecordDialogState extends State<_RenameRecordDialog> {
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Rename record'.tr),
    content: TextField(
      controller: _input,
      autofocus: true,
      maxLength: 240,
      decoration: InputDecoration(labelText: 'Filename'.tr),
      onSubmitted: (_) => _save(),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel'.tr),
      ),
      FilledButton(onPressed: _save, child: Text('Save'.tr)),
    ],
  );

  void _save() {
    final name = _input.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }
}

final class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ?action,
        ],
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: child,
      ),
    ],
  );
}

final class _DocumentReminderList extends StatelessWidget {
  const _DocumentReminderList({required this.reminders});

  final List<ReminderView> reminders;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return Text('No reminders'.tr);
    return Column(
      children: [
        for (final reminder in reminders)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              reminder.isEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
            ),
            title: Text(reminder.title),
            subtitle: Text(
              '${reminder.dueAt.toLocal()}'
              '${reminder.isEnabled ? '' : ' · Disabled'}',
            ),
          ),
      ],
    );
  }
}
