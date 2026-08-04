// Search view models stay local to the app shell.
// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:vault_domain/vault_domain.dart';

enum LifeSearchKind {
  entity,
  claim,
  event,
  state,
  attention,
  task,
  pack,
  record,
}

final class LifeSearchResult {
  const LifeSearchResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.score,
    this.entityId,
    this.claimId,
    this.eventId,
    this.documentId,
    this.stateId,
    this.attentionId,
    this.taskId,
    this.packId,
    this.evidenceDocumentId,
  });

  final LifeSearchKind kind;
  final String title;
  final String subtitle;
  final int score;
  final String? entityId;
  final String? claimId;
  final String? eventId;
  final String? documentId;
  final String? stateId;
  final String? attentionId;
  final String? taskId;
  final String? packId;
  final String? evidenceDocumentId;
}

final class LifeGraphSearch {
  static Future<List<LifeSearchResult>> build({
    required String query,
    required List<LifeEntity> entities,
    required Map<String, List<LifeEntityAttribute>> attributesByEntityId,
    required List<LifeClaim> claims,
    required List<LifeEvent> events,
    required List<DerivedLifeState> states,
    required List<AttentionItem> attentionItems,
    required List<LifeTask> tasks,
    required List<SmartPack> smartPacks,
    required List<DocumentSearchResult> documents,
  }) async {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return const <LifeSearchResult>[];
    final entityById = {for (final entity in entities) entity.id: entity};
    final results = <LifeSearchResult>[];

    for (final entity in entities) {
      final aliases = _aliases(attributesByEntityId[entity.id] ?? const []);
      final score = _scoreStrings(normalized, <String>[
        entity.displayName,
        entity.subtype ?? '',
        entity.type.storageValue,
        ...aliases,
      ]);
      if (score <= 0) continue;
      final aliasText = aliases.isEmpty
          ? ''
          : ' · ${aliases.take(2).join(', ')}';
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.entity,
          title: entity.displayName,
          subtitle:
              '${_entityTypeLabel(entity.type)}${entity.subtype == null ? '' : ' · ${entity.subtype}'}$aliasText',
          score: score + 120,
          entityId: entity.id,
        ),
      );
    }

    for (final claim in claims) {
      final entity = entityById[claim.subjectEntityId];
      final score = _scoreStrings(normalized, <String>[
        claim.predicate,
        _claimValueLabel(claim.value),
        entity?.displayName ?? '',
      ]);
      if (score <= 0) continue;
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.claim,
          title: _claimTitle(claim.predicate),
          subtitle:
              '${_claimValueLabel(claim.value)} · ${entity?.displayName ?? 'Unlinked entity'}',
          score: score + (claim.status == ClaimStatus.confirmed ? 100 : 40),
          entityId: claim.subjectEntityId,
          claimId: claim.id,
        ),
      );
    }

    for (final event in events) {
      final score = _scoreStrings(normalized, <String>[
        event.title,
        event.type.displayName,
        event.notes ?? '',
      ]);
      if (score <= 0) continue;
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.event,
          title: event.title,
          subtitle: event.type.displayName,
          score: score + (event.status == LifeEventStatus.confirmed ? 90 : 35),
          eventId: event.id,
        ),
      );
    }

    for (final state in states) {
      final entity = state.subjectEntityId == null
          ? null
          : entityById[state.subjectEntityId!];
      final score = _scoreStrings(normalized, <String>[
        state.ruleId,
        state.explanation,
        state.kind.storageValue,
        entity?.displayName ?? '',
      ]);
      if (score <= 0) continue;
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.state,
          title: _stateTitle(state.kind),
          subtitle:
              '${state.explanation}${entity == null ? '' : ' · ${entity.displayName}'}',
          score: score + 60,
          entityId: state.subjectEntityId,
          stateId: state.id,
          eventId: state.sourceEventId,
          claimId: state.sourceClaimId,
          documentId: state.sourceDocumentId,
          evidenceDocumentId: state.evidenceDocumentId,
        ),
      );
    }

    for (final item in attentionItems) {
      final entity = item.entityId == null ? null : entityById[item.entityId!];
      final score = _scoreStrings(normalized, <String>[
        item.title,
        item.explanation,
        item.category.storageValue,
        entity?.displayName ?? '',
      ]);
      if (score <= 0) continue;
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.attention,
          title: item.title,
          subtitle: item.explanation,
          score: score + 80,
          entityId: item.entityId,
          attentionId: item.id,
          claimId: item.claimId,
          eventId: item.eventId,
          documentId: item.documentId,
          evidenceDocumentId: item.evidenceDocumentId,
        ),
      );
    }

    for (final task in tasks) {
      final entity = task.entityId == null ? null : entityById[task.entityId!];
      final score = _scoreStrings(normalized, <String>[
        task.title,
        task.notes ?? '',
        entity?.displayName ?? '',
      ]);
      if (score <= 0) continue;
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.task,
          title: task.title,
          subtitle: entity == null ? 'Task' : 'Task · ${entity.displayName}',
          score: score + 70,
          entityId: task.entityId,
          eventId: task.eventId,
          taskId: task.id,
          documentId: task.documentId,
        ),
      );
    }

    for (final pack in smartPacks) {
      final entity = pack.entityId == null ? null : entityById[pack.entityId!];
      final score = _scoreStrings(normalized, <String>[
        pack.title,
        pack.type.displayName,
        entity?.displayName ?? '',
      ]);
      if (score <= 0) continue;
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.pack,
          title: pack.title,
          subtitle:
              '${pack.type.displayName}${entity == null ? '' : ' · ${entity.displayName}'}',
          score: score + 55,
          entityId: pack.entityId,
          packId: pack.id,
        ),
      );
    }

    for (final document in documents) {
      final score = _scoreStrings(normalized, <String>[
        document.logicalFilename,
        document.documentType.displayName,
      ]);
      if (score <= 0) continue;
      results.add(
        LifeSearchResult(
          kind: LifeSearchKind.record,
          title: document.logicalFilename,
          subtitle: document.documentType.displayName,
          score: score + document.relevance.round(),
          documentId: document.documentId,
        ),
      );
    }

    results.sort((left, right) => right.score.compareTo(left.score));
    return results;
  }

  static List<String> _aliases(List<LifeEntityAttribute> attributes) {
    final raw = attributes
        .where((attribute) => attribute.key == 'ALIASES')
        .firstOrNull
        ?.value
        .stringValue;
    if (raw == null || raw.trim().isEmpty) return <String>[];
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static int _scoreStrings(String normalizedQuery, List<String> values) {
    var score = 0;
    final terms = normalizedQuery.split(' ');
    for (final value in values) {
      final normalizedValue = _normalize(value);
      if (normalizedValue.isEmpty) continue;
      if (normalizedValue == normalizedQuery) score += 80;
      if (normalizedValue.startsWith(normalizedQuery)) score += 55;
      if (normalizedValue.contains(normalizedQuery)) score += 35;
      for (final term in terms) {
        if (term.isEmpty) continue;
        if (normalizedValue == term) {
          score += 18;
        } else if (normalizedValue.startsWith(term)) {
          score += 12;
        } else if (normalizedValue.contains(term)) {
          score += 8;
        }
      }
    }
    return score;
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static String _entityTypeLabel(LifeEntityType type) => switch (type) {
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

  static String _claimTitle(String predicate) =>
      predicate.toLowerCase().split('_').map(_capitalize).join(' ');

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  static String _claimValueLabel(ClaimValue value) => switch (value.type) {
    ClaimValueType.string => value.stringValue,
    ClaimValueType.integer => '${value.integerValue}',
    ClaimValueType.decimal => '${value.decimalValue}',
    ClaimValueType.boolean => value.booleanValue ? 'Yes' : 'No',
    ClaimValueType.date || ClaimValueType.datetime =>
      value.dateTimeValue.toIso8601String().split('T').first,
    ClaimValueType.money =>
      '${value.moneyValue.currency} ${value.moneyValue.amountMinorUnits}',
    ClaimValueType.identifier => value.stringValue,
    ClaimValueType.uri => value.stringValue,
    ClaimValueType.entityReference => value.stringValue,
  };

  static String _stateTitle(LifeStateKind kind) => switch (kind) {
    LifeStateKind.ok => 'OK',
    LifeStateKind.unknown => 'Unknown',
    LifeStateKind.incomplete => 'Incomplete',
    LifeStateKind.missing => 'Missing',
    LifeStateKind.expiresSoon => 'Expires Soon',
    LifeStateKind.expired => 'Expired',
    LifeStateKind.overdue => 'Overdue',
    LifeStateKind.actionRequired => 'Action Required',
  };
}
