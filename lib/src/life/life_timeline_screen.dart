// Timeline widgets intentionally keep event presentation and editing together.
// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/document_detail_screen.dart';
import 'package:citizen_vault_app/src/library/document_library_screen.dart';
import 'package:citizen_vault_app/src/reminders/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

final class LifeTimelineScreen extends StatelessWidget {
  const LifeTimelineScreen({
    required this.controller,
    this.entityId,
    this.title = 'Life Timeline',
    super.key,
  });

  final IngestionUiController controller;
  final String? entityId;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: LifeTimelinePanel(controller: controller, entityId: entityId),
      ),
    ),
  );
}

final class LifeTimelinePanel extends StatefulWidget {
  const LifeTimelinePanel({required this.controller, this.entityId, super.key});

  final IngestionUiController controller;
  final String? entityId;

  @override
  State<LifeTimelinePanel> createState() => _LifeTimelinePanelState();
}

enum _TimelineFilter { current, suggested, history }

final class _LifeTimelinePanelState extends State<LifeTimelinePanel> {
  var _events = const <LifeEvent>[];
  _TimelineFilter _filter = _TimelineFilter.current;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final visible = _events.where(
      (event) => switch (_filter) {
        _TimelineFilter.current => event.status == LifeEventStatus.confirmed,
        _TimelineFilter.suggested => event.status == LifeEventStatus.suggested,
        _TimelineFilter.history =>
          event.status == LifeEventStatus.rejected ||
              event.status == LifeEventStatus.superseded,
      },
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        key: ValueKey('timeline-${widget.entityId ?? 'global'}'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: Text('All'.tr),
                          selected: _filter == _TimelineFilter.current,
                          onSelected: (_) =>
                              setState(() => _filter = _TimelineFilter.current),
                        ),
                        ActionChip(
                          label: Text('Documents'.tr),
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => DocumentLibraryScreen(
                                controller: widget.controller,
                              ),
                            ),
                          ),
                        ),
                        FilterChip(
                          label: Text('Events'.tr),
                          selected: _filter == _TimelineFilter.suggested,
                          onSelected: (_) => setState(
                            () => _filter = _TimelineFilter.suggested,
                          ),
                        ),
                        ActionChip(
                          label: Text('Reminders'.tr),
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => RemindersScreen(
                                controller: widget.controller,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Add event',
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyTimeline(
                suggested: _filter == _TimelineFilter.suggested,
                onAdd: _add,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final event = visible.elementAt(index);
                  return _EventCard(event: event, onTap: () => _open(event));
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final events = widget.entityId == null
        ? await _globalEvents()
        : await widget.controller.entityEvents(
            widget.entityId!,
            includeHistorical: true,
          );
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<List<LifeEvent>> _globalEvents() async {
    await widget.controller.refresh();
    return widget.controller.events;
  }

  Future<void> _add() async {
    final draft = await showModalBottomSheet<LifeEventDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LifeEventEditor(
        entities: widget.controller.entities,
        documents: widget.controller.dashboardDocuments,
        fixedEntityId: widget.entityId,
      ),
    );
    if (draft == null) return;
    await widget.controller.createEvent(
      type: draft.type,
      title: draft.title,
      startAt: draft.startAt,
      endAt: draft.endAt,
      amountMinorUnits: draft.amountMinorUnits,
      currency: draft.currency,
      locationEntityId: draft.locationEntityId,
      notes: draft.notes,
      entityId: draft.entityId,
      documentId: draft.documentId,
    );
    await _load();
  }

  Future<void> _open(LifeEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EventDetails(
        controller: widget.controller,
        event: event,
        onChanged: _load,
      ),
    );
    await _load();
  }
}

final class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.suggested, required this.onAdd});

  final bool suggested;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timeline_outlined, size: 52),
          const SizedBox(height: 12),
          Text(
            suggested ? 'No suggestions to review' : 'No events here yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            suggested
                ? 'Confirmed records can propose evidence-backed events.'
                : 'Add a purchase, payment, renewal, service, or life event.',
            textAlign: TextAlign.center,
          ),
          if (!suggested) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(AppStrings.txtAddEvent.tr),
            ),
          ],
        ],
      ),
    ),
  );
}

final class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final LifeEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _eventIcon(event.type),
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${event.type.displayName} · '
            '${MaterialLocalizations.of(context).formatMediumDate(event.startAt.toLocal())}'
            '${event.amountMinorUnits == null ? '' : '\n${event.currency} ${(event.amountMinorUnits! / 100).toStringAsFixed(2)}'}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        isThreeLine: event.amountMinorUnits != null,
        trailing: event.status == LifeEventStatus.suggested
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppStrings.btnReview.tr,
                  style: TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : event.status == LifeEventStatus.superseded
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppStrings.txtCorrected.tr,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    ),
  );
}

final class _EventDetails extends StatefulWidget {
  const _EventDetails({
    required this.controller,
    required this.event,
    required this.onChanged,
  });

  final IngestionUiController controller;
  final LifeEvent event;
  final Future<void> Function() onChanged;

  @override
  State<_EventDetails> createState() => _EventDetailsState();
}

final class _EventDetailsState extends State<_EventDetails> {
  var _evidence = const <LifeEventEvidence>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadEvidence());
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Icon(_eventIcon(event.type))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(event.type.displayName),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailRow(
                label: 'Date',
                value: MaterialLocalizations.of(
                  context,
                ).formatFullDate(event.startAt.toLocal()),
              ),
              if (event.endAt != null)
                _DetailRow(
                  label: 'Until',
                  value: MaterialLocalizations.of(
                    context,
                  ).formatFullDate(event.endAt!.toLocal()),
                ),
              if (event.amountMinorUnits != null)
                _DetailRow(
                  label: 'Amount',
                  value:
                      '${event.currency} ${(event.amountMinorUnits! / 100).toStringAsFixed(2)}',
                ),
              if (event.notes?.isNotEmpty ?? false)
                _DetailRow(label: 'Notes', value: event.notes!),
              _DetailRow(label: 'Status', value: event.status.storageValue),
              const Divider(height: 28),
              Text(
                AppStrings.txtEvidence.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_evidence.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(AppStrings.txtNoEncryptedEvidenceLinked.tr),
                )
              else
                for (final evidence in _evidence)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text('Encrypted record ${evidence.documentId}'),
                    subtitle: Text(
                      evidence.pageNumber == null
                          ? evidence.evidenceRole
                          : '${evidence.evidenceRole} · page ${evidence.pageNumber}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openEvidence(evidence),
                  ),
              const SizedBox(height: 12),
              if (event.status == LifeEventStatus.suggested)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _review(LifeEventStatus.rejected),
                        child: Text(AppStrings.btnReject.tr),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _review(LifeEventStatus.confirmed),
                        child: Text(AppStrings.btnConfirm.tr),
                      ),
                    ),
                  ],
                )
              else if (event.status == LifeEventStatus.confirmed)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _correct,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(AppStrings.txtCorrectWithoutOverwriting.tr),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadEvidence() async {
    final evidence = await widget.controller.eventEvidence(widget.event.id);
    if (!mounted) return;
    setState(() => _evidence = evidence);
  }

  Future<void> _review(LifeEventStatus status) async {
    await widget.controller.reviewEvent(widget.event.id, status);
    await widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _correct() async {
    final draft = await showModalBottomSheet<LifeEventDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LifeEventEditor(
        entities: widget.controller.entities,
        documents: widget.controller.dashboardDocuments,
        event: widget.event,
        correction: true,
      ),
    );
    if (draft == null) return;
    await widget.controller.correctEvent(
      eventId: widget.event.id,
      type: draft.type,
      title: draft.title,
      startAt: draft.startAt,
      endAt: draft.endAt,
      amountMinorUnits: draft.amountMinorUnits,
      currency: draft.currency,
      locationEntityId: draft.locationEntityId,
      notes: draft.notes,
    );
    await widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openEvidence(LifeEventEvidence evidence) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => DocumentDetailScreen(
          controller: widget.controller,
          documentId: evidence.documentId,
        ),
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

final class LifeEventDraft {
  const LifeEventDraft({
    required this.type,
    required this.title,
    required this.startAt,
    this.endAt,
    this.amountMinorUnits,
    this.currency,
    this.locationEntityId,
    this.notes,
    this.entityId,
    this.documentId,
  });

  final LifeEventType type;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final int? amountMinorUnits;
  final String? currency;
  final String? locationEntityId;
  final String? notes;
  final String? entityId;
  final String? documentId;
}

final class LifeEventEditor extends StatefulWidget {
  const LifeEventEditor({
    required this.entities,
    required this.documents,
    this.fixedEntityId,
    this.event,
    this.correction = false,
    super.key,
  });

  final List<LifeEntity> entities;
  final List<DocumentListItemView> documents;
  final String? fixedEntityId;
  final LifeEvent? event;
  final bool correction;

  @override
  State<LifeEventEditor> createState() => _LifeEventEditorState();
}

final class _LifeEventEditorState extends State<LifeEventEditor> {
  late LifeEventType _type = widget.event?.type ?? LifeEventType.custom;
  late DateTime _start = widget.event?.startAt.toLocal() ?? DateTime.now();
  late DateTime? _end = widget.event?.endAt?.toLocal();
  late String? _entityId = widget.fixedEntityId;
  late String? _locationEntityId = widget.event?.locationEntityId;
  String? _documentId;
  late final _title = TextEditingController(text: widget.event?.title);
  late final _amount = TextEditingController(
    text: widget.event?.amountMinorUnits == null
        ? ''
        : (widget.event!.amountMinorUnits! / 100).toStringAsFixed(2),
  );
  late final _currency = TextEditingController(
    text: widget.event?.currency ?? 'INR',
  );
  late final _notes = TextEditingController(text: widget.event?.notes);

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _currency.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.correction ? 'Correct event' : 'Add event',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.correction)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  AppStrings
                      .txtTheOriginalRemainsInHistoryAndThisReplacementKeepsItsEntityAndEvidenceLinks
                      .tr,
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LifeEventType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Event type'),
              items: [
                for (final type in LifeEventType.values)
                  DropdownMenuItem(value: type, child: Text(type.displayName)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(AppStrings.txtDate.tr),
              subtitle: Text(
                MaterialLocalizations.of(context).formatMediumDate(_start),
              ),
              onTap: _pickStart,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppStrings.txtDateRange.tr),
              value: _end != null,
              onChanged: (enabled) async {
                if (!enabled) {
                  setState(() => _end = null);
                } else {
                  final selected = await _pickDate(_start);
                  if (selected != null) setState(() => _end = selected);
                }
              },
            ),
            if (_end != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: Text(AppStrings.txtEndDate.tr),
                subtitle: Text(
                  MaterialLocalizations.of(context).formatMediumDate(_end!),
                ),
                onTap: () async {
                  final selected = await _pickDate(_end!);
                  if (selected != null) setState(() => _end = selected);
                },
              ),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (optional)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _currency,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Currency'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.fixedEntityId == null && !widget.correction)
              DropdownButtonFormField<String>(
                initialValue: _entityId,
                decoration: const InputDecoration(
                  labelText: 'Linked profile (optional)',
                ),
                items: [
                  DropdownMenuItem(child: Text(AppStrings.txtNoProfile.tr)),
                  for (final entity in widget.entities.where(
                    (item) => item.status == LifeEntityStatus.active,
                  ))
                    DropdownMenuItem(
                      value: entity.id,
                      child: Text(entity.displayName),
                    ),
                ],
                onChanged: (value) => setState(() => _entityId = value),
              ),
            if (widget.fixedEntityId == null && !widget.correction)
              const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _locationEntityId,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
              ),
              items: [
                DropdownMenuItem(child: Text(AppStrings.txtNoLocation.tr)),
                for (final entity in widget.entities.where(
                  (item) =>
                      item.status == LifeEntityStatus.active &&
                      (item.type == LifeEntityType.place ||
                          item.type == LifeEntityType.property),
                ))
                  DropdownMenuItem(
                    value: entity.id,
                    child: Text(entity.displayName),
                  ),
              ],
              onChanged: (value) => setState(() => _locationEntityId = value),
            ),
            if (!widget.correction) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _documentId,
                decoration: const InputDecoration(
                  labelText: 'Encrypted evidence (optional)',
                ),
                items: [
                  DropdownMenuItem(child: Text(AppStrings.txtNoRecord.tr)),
                  for (final document in widget.documents.where(
                    (item) => !item.isArchived,
                  ))
                    DropdownMenuItem(
                      value: document.id,
                      child: Text(
                        document.logicalFilename,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _documentId = value),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Private notes (optional)',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(
                  widget.correction ? 'Save correction' : 'Save event',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickStart() async {
    final selected = await _pickDate(_start);
    if (selected != null) setState(() => _start = selected);
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.txtEnterAnEventTitle.tr)),
      );
      return;
    }
    if (_end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.txtEndDateCannotBeBeforeStartDate.tr),
        ),
      );
      return;
    }
    final amount = _amount.text.trim().isEmpty
        ? null
        : double.tryParse(_amount.text.trim());
    if (_amount.text.trim().isNotEmpty && amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.txtEnterAValidAmount.tr)),
      );
      return;
    }
    final currency = amount == null
        ? null
        : _currency.text.trim().toUpperCase();
    if (amount != null && (currency == null || currency.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.txtEnterACurrencyCode.tr)),
      );
      return;
    }
    Navigator.pop(
      context,
      LifeEventDraft(
        type: _type,
        title: title,
        startAt: DateTime.utc(_start.year, _start.month, _start.day),
        endAt: _end == null
            ? null
            : DateTime.utc(_end!.year, _end!.month, _end!.day),
        amountMinorUnits: amount == null ? null : (amount * 100).round(),
        currency: currency,
        locationEntityId: _locationEntityId,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        entityId: _entityId,
        documentId: _documentId,
      ),
    );
  }
}

IconData _eventIcon(LifeEventType type) => switch (type) {
  LifeEventType.purchase => Icons.shopping_bag_outlined,
  LifeEventType.payment => Icons.payments_outlined,
  LifeEventType.renewal => Icons.autorenew,
  LifeEventType.expiry => Icons.hourglass_bottom,
  LifeEventType.service => Icons.build_outlined,
  LifeEventType.repair => Icons.home_repair_service_outlined,
  LifeEventType.medical => Icons.medical_services_outlined,
  LifeEventType.education => Icons.school_outlined,
  LifeEventType.tax => Icons.receipt_long_outlined,
  LifeEventType.employment => Icons.work_outline,
  LifeEventType.warranty => Icons.verified_user_outlined,
  LifeEventType.custom => Icons.event_outlined,
};
