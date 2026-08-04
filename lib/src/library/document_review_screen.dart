import 'dart:typed_data';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

class DocumentReviewScreen extends StatefulWidget {
  const DocumentReviewScreen({
    required this.review,
    required this.controller,
    super.key,
  });

  final DocumentReviewView review;
  final IngestionUiController controller;

  @override
  State<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends State<DocumentReviewScreen> {
  late DocumentType _type;
  late final Map<String, TextEditingController> _fields;
  late final TextEditingController _tags;
  late final Future<Uint8List?> _preview;
  LifeEntity? _selectedProfile;
  List<LifeEntity> _candidates = [];
  int? _reminderDaysBefore;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.review.suggestedType;
    _preview = widget.controller.documentPreview(widget.review.documentId);
    _tags = TextEditingController();
    _fields = <String, TextEditingController>{
      for (final field in widget.review.fields)
        field.id: TextEditingController(text: field.effectiveValue),
    };

    // Load link-to candidates
    widget.controller.profileMatchCandidates(widget.review).then((candidates) {
      if (mounted) {
        final combined = <String, LifeEntity>{
          for (final entity in widget.controller.entities) entity.id: entity,
          for (final entity in candidates) entity.id: entity,
        };
        setState(() => _candidates = combined.values.toList(growable: false));
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _tags.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSave() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final submission = widget.review.fields
        .map(
          (f) => ConfirmedFieldEdit(
            fieldId: f.id,
            value: _fields[f.id]?.text ?? '',
          ),
        )
        .toList(growable: false);

    ReminderDraft? reminderDraft;
    if (_reminderDaysBefore != null) {
      ExtractedFieldView? expiryField;
      for (final field in widget.review.fields) {
        if (field.type == ExtractedFieldType.expiryDate ||
            field.type == ExtractedFieldType.dueDate) {
          expiryField = field;
          break;
        }
      }
      final date = expiryField == null
          ? null
          : DateTime.tryParse(_fields[expiryField.id]?.text.trim() ?? '');
      if (date != null && expiryField != null) {
        final dueAt = date.subtract(Duration(days: _reminderDaysBefore!));
        if (!dueAt.isAfter(DateTime.now())) {
          setState(() {
            _saving = false;
            _error = 'Choose a reminder date in the future.'.tr;
          });
          return;
        }
        reminderDraft = ReminderDraft(
          documentId: widget.review.documentId,
          type: expiryField.type == ExtractedFieldType.dueDate
              ? ReminderType.dueDate
              : ReminderType.expiry,
          title: '${widget.review.logicalFilename} needs attention',
          dueAt: dueAt,
        );
      }
    }

    try {
      await widget.controller.confirmReview(
        documentId: widget.review.documentId,
        documentType: _type,
        fields: submission,
        profileEntityId: _selectedProfile?.id,
      );
      final tags = _tags.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
      if (tags.isNotEmpty) {
        await widget.controller.replaceTags(widget.review.documentId, tags);
      }
      if (reminderDraft != null) {
        await widget.controller.createReminder(reminderDraft);
      }
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The reviewed details could not be saved.'.tr;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.txtReviewDocument.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 220,
              color: const Color(0xFF0F172A),
              child: FutureBuilder<Uint8List?>(
                future: _preview,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) {
                    return const Center(
                      child: Icon(
                        Icons.description_outlined,
                        size: 48,
                        color: Color(0xFFCBD5E1),
                      ),
                    );
                  }
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    AppStrings.txtOwnKeepFound.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Fields
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildFieldRow('Document type', _type.displayName),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        for (final field in widget.review.fields) ...[
                          _buildFieldRow(
                            field.type.displayName,
                            _fields[field.id]?.text ?? '',
                          ),
                          if (field != widget.review.fields.last)
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _editFields,
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(AppStrings.txtEditFields.tr),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Tags'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tags,
                    decoration: InputDecoration(
                      hintText: 'Identity, family, tax'.tr,
                      helperText: 'Separate tags with commas.'.tr,
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Link To
                  if (_candidates.isNotEmpty) ...[
                    Text(
                      AppStrings.txtLinkTo.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.msgSuggestLinkHeader.tr,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    RadioGroup<LifeEntity>(
                      groupValue: _selectedProfile,
                      onChanged: (value) =>
                          setState(() => _selectedProfile = value),
                      child: Column(
                        children: [
                          for (final candidate in _candidates)
                            RadioListTile<LifeEntity>(
                              title: Text(
                                candidate.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                EntityTemplateRegistry.forType(
                                  candidate.type,
                                ).singularLabel,
                              ),
                              value: candidate,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF2563EB),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Expiry Reminder
                  Text(
                    AppStrings.txtAddExpiryReminder.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final days
                          in widget
                              .controller
                              .preferences
                              .defaultReminderOffsets)
                        _buildReminderChip(
                          days == 1 ? '1 day before' : '$days days before',
                          days,
                        ),
                      _buildReminderChip('On expiry date', 0),
                    ],
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Confirm CTA
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _saving ? null : _confirmAndSave,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        AppStrings.btnConfirmSave.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
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

  Future<void> _editFields() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit extracted fields'.tr),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              DropdownButtonFormField<DocumentType>(
                initialValue: _type,
                decoration: InputDecoration(labelText: 'Document type'.tr),
                items: [
                  for (final type in DocumentType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              for (final field in widget.review.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _fields[field.id],
                    decoration: InputDecoration(
                      labelText: field.type.displayName,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Done'.tr),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _buildReminderChip(String label, int daysBefore) {
    return FilterChip(
      label: Text(label),
      selected: _reminderDaysBefore == daysBefore,
      onSelected: (val) =>
          setState(() => _reminderDaysBefore = val ? daysBefore : null),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}
