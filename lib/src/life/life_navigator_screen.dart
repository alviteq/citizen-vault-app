// Life OS navigation intentionally combines structured browsing and search.
// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:async';

import 'package:citizen_vault_app/src/attention/attention_tasks_screen.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/document_detail_screen.dart';
import 'package:citizen_vault_app/src/life/entity_directory_screen.dart';
import 'package:citizen_vault_app/src/life/life_graph_search.dart';
import 'package:citizen_vault_app/src/life/life_timeline_screen.dart';
import 'package:citizen_vault_app/src/packs/smart_packs_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

enum LifeNavigatorFilter {
  all('All'),
  people('People'),
  things('Things'),
  places('Places'),
  organisations('Organisations'),
  claims('Claims'),
  events('Events'),
  state('State'),
  attention('Attention'),
  tasks('Tasks'),
  packs('Packs'),
  records('Records');

  const LifeNavigatorFilter(this.label);
  final String label;
}

final class LifeNavigatorScreen extends StatefulWidget {
  const LifeNavigatorScreen({
    required this.controller,
    this.initialFilter = LifeNavigatorFilter.all,
    this.initialQuery = '',
    super.key,
  });

  final IngestionUiController controller;
  final LifeNavigatorFilter initialFilter;
  final String initialQuery;

  @override
  State<LifeNavigatorScreen> createState() => _LifeNavigatorScreenState();
}

final class _LifeNavigatorScreenState extends State<LifeNavigatorScreen> {
  late final TextEditingController _queryController = TextEditingController(
    text: widget.initialQuery,
  );
  late final LifeNavigatorFilter _filter = widget.initialFilter;
  var _results = const <LifeSearchResult>[];
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _queryController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search OwnKeep...'.tr,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent searches'.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final term in const [
                        'insurance',
                        'passport',
                        'bill',
                        'people',
                      ])
                        ActionChip(
                          label: Text(term.tr),
                          onPressed: () => _queryController.text = term,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Top results'.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? const _EmptyLifeNavigator()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _results.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
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
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _iconFor(result.kind),
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                title: Text(
                                  result.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  result.subtitle,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF94A3B8),
                                ),
                                onTap: () => _open(result),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _load() async {
    final query = _queryController.text.trim();
    if (mounted) {
      setState(() => _loading = true);
    }
    final results = query.isEmpty
        ? _browseResults()
        : await widget.controller.graphSearch(query);
    if (!mounted) return;
    setState(() {
      _results = results
          .where((result) => _matchesFilter(result, _filter))
          .toList(growable: false);
      _loading = false;
    });
  }

  List<LifeSearchResult> _browseResults() {
    final results = <LifeSearchResult>[];
    for (final entity in widget.controller.entities) {
      results.add(
        LifeSearchResult(
          kind: _entityFilterKind(entity.type),
          title: entity.displayName,
          subtitle:
              '${_entityLabel(entity.type)}${entity.subtype == null ? '' : ' · ${entity.subtype}'}',
          score: 100,
          entityId: entity.id,
        ),
      );
    }
    for (final claim in widget.controller.graphClaims) {
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.claim,
          title: claim.predicate,
          subtitle: claim.status.storageValue,
          score: claim.status == ClaimStatus.confirmed ? 95 : 55,
          entityId: claim.subjectEntityId,
          claimId: claim.id,
        ),
      );
    }
    for (final event in widget.controller.events) {
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.event,
          title: event.title,
          subtitle: event.type.displayName,
          score: event.status == LifeEventStatus.confirmed ? 90 : 50,
          eventId: event.id,
        ),
      );
    }
    for (final state in widget.controller.lifeStatesCache) {
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.state,
          title: state.kind.storageValue.replaceAll('_', ' '),
          subtitle: state.explanation,
          score: state.kind == LifeStateKind.ok ? 40 : 80,
          entityId: state.subjectEntityId,
          stateId: state.id,
          documentId: state.sourceDocumentId,
          evidenceDocumentId: state.evidenceDocumentId,
        ),
      );
    }
    for (final item in widget.controller.attentionItems) {
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.attention,
          title: item.title,
          subtitle: item.explanation,
          score: 100 - item.priority,
          entityId: item.entityId,
          attentionId: item.id,
          documentId: item.documentId,
          evidenceDocumentId: item.evidenceDocumentId,
        ),
      );
    }
    for (final task in widget.controller.tasks) {
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.task,
          title: task.title,
          subtitle: task.notes ?? 'Task',
          score: 60,
          entityId: task.entityId,
          taskId: task.id,
          documentId: task.documentId,
        ),
      );
    }
    for (final pack in widget.controller.smartPacks) {
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.pack,
          title: pack.title,
          subtitle: pack.type.displayName,
          score: 60,
          entityId: pack.entityId,
          packId: pack.id,
        ),
      );
    }
    for (final document in widget.controller.dashboardDocuments) {
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.record,
          title: document.logicalFilename,
          subtitle: document.documentType.displayName,
          score: 50,
          documentId: document.id,
        ),
      );
    }
    results.sort((left, right) => right.score.compareTo(left.score));
    return results;
  }

  Future<void> _open(LifeSearchResult result) async {
    switch (result.kind) {
      case LifeSearchKind.entity:
        final entity = result.entityId == null
            ? null
            : await widget.controller.entityById(result.entityId!);
        if (!mounted || entity == null) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) => EntityProfileScreen(
              controller: widget.controller,
              entity: entity,
            ),
          ),
        );
      case LifeSearchKind.claim:
      case LifeSearchKind.state:
        final entity = result.entityId == null
            ? null
            : await widget.controller.entityById(result.entityId!);
        if (entity != null && mounted) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (context) => EntityProfileScreen(
                controller: widget.controller,
                entity: entity,
              ),
            ),
          );
        } else if (mounted) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (context) =>
                  AttentionTasksScreen(controller: widget.controller),
            ),
          );
        }
      case LifeSearchKind.event:
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) =>
                LifeTimelineScreen(controller: widget.controller),
          ),
        );
      case LifeSearchKind.attention:
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) =>
                AttentionTasksScreen(controller: widget.controller),
          ),
        );
      case LifeSearchKind.task:
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) =>
                AttentionTasksScreen(controller: widget.controller),
          ),
        );
      case LifeSearchKind.pack:
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) =>
                SmartPacksScreen(controller: widget.controller),
          ),
        );
      case LifeSearchKind.record:
        if (!mounted || result.documentId == null) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(
              controller: widget.controller,
              documentId: result.documentId!,
            ),
          ),
        );
    }
    await widget.controller.refresh();
    if (mounted) {
      await _load();
    }
  }

  static bool _matchesFilter(
    LifeSearchResult result,
    LifeNavigatorFilter filter,
  ) => switch (filter) {
    LifeNavigatorFilter.all => true,
    LifeNavigatorFilter.people =>
      result.kind == LifeSearchKind.entity &&
          (result.subtitle.startsWith('Person') ||
              result.subtitle.startsWith('Family') ||
              result.subtitle.startsWith('Pet')),
    LifeNavigatorFilter.things =>
      result.kind == LifeSearchKind.entity &&
          !result.subtitle.startsWith('Person') &&
          !result.subtitle.startsWith('Family') &&
          !result.subtitle.startsWith('Pet') &&
          !result.subtitle.startsWith('Place') &&
          !result.subtitle.startsWith('Property') &&
          !result.subtitle.startsWith('Organisation'),
    LifeNavigatorFilter.places =>
      result.kind == LifeSearchKind.entity &&
          (result.subtitle.startsWith('Place') ||
              result.subtitle.startsWith('Property')),
    LifeNavigatorFilter.organisations =>
      result.kind == LifeSearchKind.entity &&
          result.subtitle.startsWith('Organisation'),
    LifeNavigatorFilter.claims => result.kind == LifeSearchKind.claim,
    LifeNavigatorFilter.events => result.kind == LifeSearchKind.event,
    LifeNavigatorFilter.state => result.kind == LifeSearchKind.state,
    LifeNavigatorFilter.attention => result.kind == LifeSearchKind.attention,
    LifeNavigatorFilter.tasks => result.kind == LifeSearchKind.task,
    LifeNavigatorFilter.packs => result.kind == LifeSearchKind.pack,
    LifeNavigatorFilter.records => result.kind == LifeSearchKind.record,
  };

  static IconData _iconFor(LifeSearchKind kind) => switch (kind) {
    LifeSearchKind.entity => Icons.account_circle_outlined,
    LifeSearchKind.claim => Icons.fact_check_outlined,
    LifeSearchKind.event => Icons.timeline_outlined,
    LifeSearchKind.state => Icons.analytics_outlined,
    LifeSearchKind.attention => Icons.notification_important_outlined,
    LifeSearchKind.task => Icons.task_alt_outlined,
    LifeSearchKind.pack => Icons.inventory_2_outlined,
    LifeSearchKind.record => Icons.description_outlined,
  };

  static String _entityLabel(LifeEntityType type) => switch (type) {
    LifeEntityType.person => 'Person',
    LifeEntityType.family => 'Family',
    LifeEntityType.pet => 'Pet',
    LifeEntityType.vehicle => 'Vehicle',
    LifeEntityType.property => 'Property',
    LifeEntityType.place => 'Place',
    LifeEntityType.device => 'Device',
    LifeEntityType.appliance => 'Appliance',
    LifeEntityType.organisation => 'Organisation',
    LifeEntityType.account => 'Account',
    LifeEntityType.policy => 'Policy',
    LifeEntityType.subscription => 'Subscription',
    LifeEntityType.warranty => 'Warranty',
    LifeEntityType.other => 'Other',
  };

  static LifeSearchKind _entityFilterKind(LifeEntityType type) {
    switch (type) {
      case LifeEntityType.person:
      case LifeEntityType.family:
      case LifeEntityType.pet:
      case LifeEntityType.vehicle:
      case LifeEntityType.property:
      case LifeEntityType.place:
      case LifeEntityType.device:
      case LifeEntityType.appliance:
      case LifeEntityType.organisation:
      case LifeEntityType.account:
      case LifeEntityType.policy:
      case LifeEntityType.subscription:
      case LifeEntityType.warranty:
      case LifeEntityType.other:
        return LifeSearchKind.entity;
    }
  }
}

final class _EmptyLifeNavigator extends StatelessWidget {
  const _EmptyLifeNavigator();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        AppStrings
            .txtNothingMatchedYetTryAPersonCarHomeInsurerPackOrRecordName
            .tr,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
