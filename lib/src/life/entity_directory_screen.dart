// Profile widgets expose their behavior through the encrypted controller.
// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/document_detail_screen.dart';
import 'package:citizen_vault_app/src/life/life_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Encrypted directory of people, things, places, and organisations.
final class EntityDirectoryScreen extends StatefulWidget {
  const EntityDirectoryScreen({
    required this.controller,
    this.initialTypes,
    this.title = 'People, things & places',
    super.key,
  });

  final IngestionUiController controller;
  final Set<LifeEntityType>? initialTypes;
  final String title;

  @override
  State<EntityDirectoryScreen> createState() => _EntityDirectoryScreenState();
}

final class _EntityDirectoryScreenState extends State<EntityDirectoryScreen> {
  var _showArchived = false;

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
  Widget build(BuildContext context) {
    final entities = widget.controller.entities
        .where(
          (entity) =>
              (_showArchived || entity.status == LifeEntityStatus.active) &&
              (widget.initialTypes == null ||
                  widget.initialTypes!.contains(entity.type)),
        )
        .toList(growable: false);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.title.tr,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            tooltip: (_showArchived ? 'Hide archived' : 'Show archived').tr,
            onPressed: () => setState(() => _showArchived = !_showArchived),
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
          ),
        ],
      ),
      body: entities.isEmpty
          ? _EmptyEntities(onAdd: _add)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: entities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entity = entities[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _iconFor(entity.type),
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    title: Text(
                      entity.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      '${EntityTemplateRegistry.forType(entity.type).singularLabel.tr}'
                      '${entity.subtype == null ? '' : ' · ${entity.subtype}'}',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    trailing: entity.status == LifeEntityStatus.archived
                        ? Chip(label: Text(AppStrings.txtArchived.tr))
                        : const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF94A3B8),
                          ),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (context) => EntityProfileScreen(
                          controller: widget.controller,
                          entity: entity,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(AppStrings.btnAdd.tr),
      ),
    );
  }

  Future<void> _add() async {
    final allowedTypes = widget.initialTypes;
    final draft = await showModalBottomSheet<_EntityDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EntityEditor(
        initialType: allowedTypes?.firstOrNull,
        allowedTypes: allowedTypes,
      ),
    );
    if (draft == null) return;
    await widget.controller.createEntity(
      type: draft.type,
      displayName: draft.displayName,
      subtype: draft.subtype,
    );
  }
}

final class EntityProfileScreen extends StatefulWidget {
  const EntityProfileScreen({
    required this.controller,
    required this.entity,
    super.key,
  });

  final IngestionUiController controller;
  final LifeEntity entity;

  @override
  State<EntityProfileScreen> createState() => _EntityProfileScreenState();
}

final class _EntityProfileScreenState extends State<EntityProfileScreen> {
  late LifeEntity _entity = widget.entity;
  var _attributes = const <LifeEntityAttribute>[];
  var _history = const <LifeEntityHistoryEvent>[];
  var _claims = const <LifeClaim>[];
  var _evidence = const <EvidenceLink>[];
  var _relationships = const <LifeRelationship>[];
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetails());
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _entity.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            tooltip: 'Edit profile'.tr,
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          labelColor: Color(0xFF3B82F6),
          unselectedLabelColor: Color(0xFF64748B),
          indicatorColor: Color(0xFF3B82F6),
          tabs: [
            Tab(text: 'Overview'.tr),
            Tab(text: 'Evidence'.tr),
            Tab(text: 'Claims'.tr),
            Tab(text: 'Events'.tr),
            Tab(text: 'More'.tr),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _ProfileOverview(
            entity: _entity,
            attributes: _attributes,
            onEditNotes: _editNotes,
            onEditAliases: _editAliases,
            onAddCustomAttribute: _addCustomAttribute,
            onChoosePhoto: _choosePhoto,
            photoBytes: _photoBytes,
          ),
          _ProfileEvidence(
            evidence: _evidence,
            onOpen: _openEvidence,
            onLink: _linkEvidence,
          ),
          _ProfileClaims(claims: _claims, onReview: _reviewClaim),
          LifeTimelinePanel(
            controller: widget.controller,
            entityId: _entity.id,
          ),
          _ProfileMore(
            entity: _entity,
            history: _history,
            relationships: _relationships,
            entities: widget.controller.entities,
            onArchiveChanged: _setArchived,
            onMerge: _mergeDuplicate,
            onAddRelationship: _addRelationship,
            onRemoveRelationship: _removeRelationship,
          ),
        ],
      ),
    ),
  );

  Future<void> _edit() async {
    final draft = await showModalBottomSheet<_EntityDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EntityEditor(entity: _entity),
    );
    if (draft == null) return;
    await widget.controller.updateEntity(
      entityId: _entity.id,
      displayName: draft.displayName,
      subtype: draft.subtype,
    );
    if (!mounted) return;
    setState(() {
      _entity = LifeEntity(
        id: _entity.id,
        type: _entity.type,
        displayName: draft.displayName,
        subtype: draft.subtype,
        status: _entity.status,
        createdAt: _entity.createdAt,
        updatedAt: DateTime.now().toUtc(),
        archivedAt: _entity.archivedAt,
      );
    });
    await _loadDetails();
  }

  Future<void> _setArchived(bool archived) async {
    await widget.controller.setEntityArchived(_entity.id, archived);
    if (!mounted) return;
    setState(() {
      _entity = LifeEntity(
        id: _entity.id,
        type: _entity.type,
        displayName: _entity.displayName,
        subtype: _entity.subtype,
        status: archived ? LifeEntityStatus.archived : LifeEntityStatus.active,
        createdAt: _entity.createdAt,
        updatedAt: DateTime.now().toUtc(),
        archivedAt: archived ? DateTime.now().toUtc() : null,
      );
    });
    await _loadDetails();
  }

  Future<void> _loadDetails() async {
    final attributes = await widget.controller.entityAttributes(_entity.id);
    final history = await widget.controller.entityHistory(_entity.id);
    final claims = await widget.controller.entityClaims(_entity.id);
    final evidence = await widget.controller.entityEvidence(_entity.id);
    final relationships = await widget.controller.entityRelationships(
      _entity.id,
    );
    final photoDocumentId = attributes
        .where((attribute) => attribute.key == 'PHOTO_DOCUMENT_ID')
        .firstOrNull
        ?.value
        .stringValue;
    final photoBytes = photoDocumentId == null
        ? null
        : await widget.controller.documentPreview(photoDocumentId);
    if (!mounted) return;
    setState(() {
      _attributes = attributes;
      _history = history;
      _claims = claims;
      _evidence = evidence;
      _relationships = relationships;
      _photoBytes = photoBytes;
    });
  }

  Future<void> _editNotes() async {
    final current = _attributes
        .where((attribute) => attribute.key == 'NOTES')
        .firstOrNull;
    var draft = current?.value.stringValue ?? '';
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.txtPrivateNotes.tr),
        content: TextFormField(
          initialValue: draft,
          onChanged: (value) => draft = value,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: 'Add notes stored inside your encrypted vault'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.btnCancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: Text(AppStrings.btnSave.tr),
          ),
        ],
      ),
    );
    if (notes == null) return;
    await widget.controller.upsertEntityAttribute(
      entityId: _entity.id,
      key: 'NOTES',
      value: ClaimValue.string(notes),
    );
    await _loadDetails();
  }

  Future<void> _editAliases() async {
    final current = _attributes
        .where((attribute) => attribute.key == 'ALIASES')
        .firstOrNull;
    var draft = current?.value.stringValue ?? '';
    final aliases = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.txtAliases.tr),
        content: TextFormField(
          initialValue: draft,
          onChanged: (value) => draft = value,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'One alternative name per line'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.btnCancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: Text(AppStrings.btnSave.tr),
          ),
        ],
      ),
    );
    if (aliases == null) return;
    await widget.controller.upsertEntityAttribute(
      entityId: _entity.id,
      key: 'ALIASES',
      value: ClaimValue.string(aliases),
    );
    await _loadDetails();
  }

  Future<void> _addCustomAttribute() async {
    final draft = await showModalBottomSheet<_AttributeDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CustomAttributeEditor(),
    );
    if (draft == null) return;
    await widget.controller.upsertEntityAttribute(
      entityId: _entity.id,
      key: draft.key,
      value: draft.value,
    );
    await _loadDetails();
  }

  Future<void> _choosePhoto() async {
    final images = widget.controller.dashboardDocuments
        .where((document) => document.mimeType.startsWith('image/'))
        .toList(growable: false);
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.txtImportAPhotoFirstThenLinkIt.tr)),
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(AppStrings.txtChooseEncryptedProfilePhoto.tr)),
            for (final image in images.take(8))
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(image.logicalFilename),
                onTap: () => Navigator.pop(context, image.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await widget.controller.upsertEntityAttribute(
      entityId: _entity.id,
      key: 'PHOTO_DOCUMENT_ID',
      value: ClaimValue.identifier(selected),
    );
    await _loadDetails();
  }

  Future<void> _reviewClaim(LifeClaim claim, ClaimStatus status) async {
    await widget.controller.reviewEntityClaim(claim.id, status);
    await _loadDetails();
  }

  Future<void> _openEvidence(EvidenceLink evidence) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => DocumentDetailScreen(
          controller: widget.controller,
          documentId: evidence.documentId,
        ),
      ),
    );
  }

  Future<void> _linkEvidence() async {
    final documents = widget.controller.dashboardDocuments
        .where((document) => !document.isArchived)
        .toList(growable: false);
    if (documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.txtImportARecordFirst.tr)),
      );
      return;
    }
    final documentId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppStrings.txtLinkEncryptedEvidence.tr),
              subtitle: Text(
                AppStrings.txtTheOriginalRemainsEncryptedAndUnchanged.tr,
              ),
            ),
            for (final document in documents.take(12))
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(document.logicalFilename),
                onTap: () => Navigator.pop(context, document.id),
              ),
          ],
        ),
      ),
    );
    if (documentId == null) return;
    await widget.controller.linkDocumentEvidence(
      entityId: _entity.id,
      documentId: documentId,
    );
    await _loadDetails();
  }

  Future<void> _addRelationship() async {
    final others = widget.controller.entities
        .where(
          (candidate) =>
              candidate.id != _entity.id &&
              candidate.status == LifeEntityStatus.active,
        )
        .toList(growable: false);
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.txtAddAnotherProfileFirst.tr)),
      );
      return;
    }
    final draft = await showModalBottomSheet<_RelationshipDraft>(
      context: context,
      builder: (context) => _RelationshipEditor(entities: others),
    );
    if (draft == null) return;
    await widget.controller.createEntityRelationship(
      fromEntityId: _entity.id,
      toEntityId: draft.toEntityId,
      type: draft.type,
    );
    await _loadDetails();
  }

  Future<void> _removeRelationship(LifeRelationship relationship) async {
    await widget.controller.reviewEntityRelationship(
      relationship.id,
      ClaimStatus.rejected,
    );
    await _loadDetails();
  }

  Future<void> _mergeDuplicate() async {
    final candidates = await widget.controller.duplicateEntityCandidates(
      _entity,
    );
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.txtNoMatchingDuplicateWasFound.tr)),
      );
      return;
    }
    final duplicate = await showModalBottomSheet<LifeEntity>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppStrings.txtChooseDuplicateToMerge.tr),
              subtitle: Text(
                AppStrings.txtTheDuplicateIDAndHistoryWillBeRetained.tr,
              ),
            ),
            for (final candidate in candidates)
              ListTile(
                leading: Icon(_iconFor(candidate.type)),
                title: Text(candidate.displayName),
                subtitle: Text(candidate.subtype ?? 'Same profile type'.tr),
                onTap: () => Navigator.pop(context, candidate),
              ),
          ],
        ),
      ),
    );
    if (duplicate == null) return;
    await widget.controller.mergeEntities(
      primaryEntityId: _entity.id,
      duplicateEntityId: duplicate.id,
    );
    await _loadDetails();
  }
}

final class _ProfileOverview extends StatelessWidget {
  const _ProfileOverview({
    required this.entity,
    required this.attributes,
    required this.onEditNotes,
    required this.onEditAliases,
    required this.onAddCustomAttribute,
    required this.onChoosePhoto,
    required this.photoBytes,
  });

  final LifeEntity entity;
  final List<LifeEntityAttribute> attributes;
  final VoidCallback onEditNotes;
  final VoidCallback onEditAliases;
  final VoidCallback onAddCustomAttribute;
  final VoidCallback onChoosePhoto;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final template = EntityTemplateRegistry.forType(entity.type);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GestureDetector(
          onTap: onChoosePhoto,
          child: CircleAvatar(
            radius: 46,
            backgroundImage: photoBytes == null
                ? null
                : MemoryImage(photoBytes!),
            child: Icon(
              photoBytes != null
                  ? null
                  : attributes.any(
                      (attribute) => attribute.key == 'PHOTO_DOCUMENT_ID',
                    )
                  ? Icons.photo_outlined
                  : _iconFor(entity.type),
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          entity.displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          template.singularLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Text(
          AppStrings.txtProfileFields.tr,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notes_outlined),
          title: Text(AppStrings.txtPrivateNotes.tr),
          subtitle: Text(
            attributes
                    .where((attribute) => attribute.key == 'NOTES')
                    .firstOrNull
                    ?.value
                    .stringValue ??
                'Add encrypted notes',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: onEditNotes,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alternate_email),
          title: Text(AppStrings.txtAliases.tr),
          subtitle: Text(
            attributes
                    .where((attribute) => attribute.key == 'ALIASES')
                    .firstOrNull
                    ?.value
                    .stringValue
                    .replaceAll('\n', ', ') ??
                'Add alternative names',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: onEditAliases,
        ),
        for (final field in template.fields)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_circle_outline),
            title: Text(field.label),
            subtitle: Text(AppStrings.txtNoConfirmedValueYet.tr),
          ),
        for (final attribute in attributes.where(
          (attribute) => !{
            'NOTES',
            'ALIASES',
            'PHOTO_DOCUMENT_ID',
            'MERGED_INTO',
          }.contains(attribute.key),
        ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: Text(attribute.key.replaceAll('_', ' ').toLowerCase()),
            subtitle: Text(_displayClaimValue(attribute.value)),
          ),
        OutlinedButton.icon(
          onPressed: onAddCustomAttribute,
          icon: const Icon(Icons.add),
          label: Text(AppStrings.txtAddCustomField.tr),
        ),
      ],
    );
  }
}

final class _ProfileMore extends StatelessWidget {
  const _ProfileMore({
    required this.entity,
    required this.history,
    required this.relationships,
    required this.entities,
    required this.onArchiveChanged,
    required this.onMerge,
    required this.onAddRelationship,
    required this.onRemoveRelationship,
  });

  final LifeEntity entity;
  final List<LifeEntityHistoryEvent> history;
  final List<LifeRelationship> relationships;
  final List<LifeEntity> entities;
  final ValueChanged<bool> onArchiveChanged;
  final VoidCallback onMerge;
  final VoidCallback onAddRelationship;
  final ValueChanged<LifeRelationship> onRemoveRelationship;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      SwitchListTile(
        value: entity.status == LifeEntityStatus.archived,
        onChanged: onArchiveChanged,
        title: Text(
          entity.status == LifeEntityStatus.archived
              ? 'Archived'
              : 'Archive profile',
        ),
        subtitle: Text(AppStrings.txtHistoryAndEvidenceAreRetained.tr),
      ),
      ListTile(
        leading: const Icon(Icons.merge_outlined),
        title: Text(AppStrings.txtMergeADuplicate.tr),
        subtitle: Text(AppStrings.txtRequiresAnExactSameNameProfileMatch.tr),
        onTap: onMerge,
      ),
      const Divider(),
      Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.txtRelationships.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: onAddRelationship,
            icon: const Icon(Icons.add),
            label: Text(AppStrings.btnAdd.tr),
          ),
        ],
      ),
      if (relationships.isEmpty)
        ListTile(title: Text(AppStrings.txtNoRelationshipsYet.tr))
      else
        for (final relationship in relationships)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text(
              relationship.type.storageValue.replaceAll('_', ' ').toLowerCase(),
            ),
            subtitle: Text(
              entities
                      .where(
                        (candidate) =>
                            candidate.id ==
                            (relationship.fromEntityId == entity.id
                                ? relationship.toEntityId
                                : relationship.fromEntityId),
                      )
                      .firstOrNull
                      ?.displayName ??
                  'Archived profile',
            ),
            trailing: relationship.status == ClaimStatus.rejected
                ? Chip(label: Text(AppStrings.txtREJECTED.tr))
                : IconButton(
                    tooltip: 'Remove relationship'.tr,
                    onPressed: () => onRemoveRelationship(relationship),
                    icon: const Icon(Icons.link_off),
                  ),
          ),
      const Divider(),
      Text(
        AppStrings.txtHistory.tr,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (history.isEmpty)
        ListTile(title: Text(AppStrings.txtNoProfileChangesRecordedYet.tr))
      else
        for (final event in history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(_historyLabel(event.eventType)),
            subtitle: Text(
              MaterialLocalizations.of(
                context,
              ).formatShortDate(event.createdAt.toLocal()),
            ),
          ),
    ],
  );
}

final class _ProfileEvidence extends StatelessWidget {
  const _ProfileEvidence({
    required this.evidence,
    required this.onOpen,
    required this.onLink,
  });

  final List<EvidenceLink> evidence;
  final ValueChanged<EvidenceLink> onOpen;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onLink,
            icon: const Icon(Icons.add_link),
            label: Text(AppStrings.txtLinkEncryptedRecord.tr),
          ),
        ),
      ),
      Expanded(
        child: evidence.isEmpty
            ? Center(child: Text(AppStrings.txtNoLinkedEvidenceYet.tr))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: evidence.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = evidence[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        '${'Encrypted record'.tr} ${item.documentId}',
                      ),
                      subtitle: Text(
                        item.pageNumber == null
                            ? 'Source evidence'
                            : 'Source evidence · page ${item.pageNumber}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onOpen(item),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

final class _ProfileClaims extends StatefulWidget {
  const _ProfileClaims({required this.claims, required this.onReview});

  final List<LifeClaim> claims;
  final void Function(LifeClaim claim, ClaimStatus status) onReview;

  @override
  State<_ProfileClaims> createState() => _ProfileClaimsState();
}

final class _ProfileClaimsState extends State<_ProfileClaims> {
  var _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final claims = widget.claims
        .where(
          (claim) =>
              _showHistory ||
              claim.status == ClaimStatus.suggested ||
              claim.status == ClaimStatus.confirmed,
        )
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            selected: _showHistory,
            onSelected: (value) => setState(() => _showHistory = value),
            label: Text(AppStrings.txtIncludeRejectedAndSuperseded.tr),
          ),
        ),
        const SizedBox(height: 8),
        if (claims.isEmpty)
          Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              AppStrings.txtNoClaimsYetLinkAReviewedRecordFromTheInbox.tr,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final claim in claims)
            Card(
              child: ListTile(
                title: Text(claim.predicate.replaceAll('_', ' ').toLowerCase()),
                subtitle: Text(_displayClaimValue(claim.value)),
                trailing: claim.status == ClaimStatus.suggested
                    ? Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Reject Claim'.tr,
                            onPressed: () =>
                                widget.onReview(claim, ClaimStatus.rejected),
                            icon: const Icon(Icons.close),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Confirm Claim'.tr,
                            onPressed: () =>
                                widget.onReview(claim, ClaimStatus.confirmed),
                            icon: const Icon(Icons.check),
                          ),
                        ],
                      )
                    : Chip(label: Text(claim.status.storageValue)),
              ),
            ),
      ],
    );
  }
}

final class _EmptyEntities extends StatelessWidget {
  const _EmptyEntities({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_tree_outlined, size: 54),
          const SizedBox(height: 14),
          Text(
            AppStrings.txtBuildYourPrivateLifeMap.tr,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings
                .txtAddPeopleVehiclesPropertiesDevicesAndPlacesEverythingStaysEncryptedOnThisDevice
                .tr,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(AppStrings.txtAddYourFirstProfile.tr),
          ),
        ],
      ),
    ),
  );
}

final class _EntityEditor extends StatefulWidget {
  const _EntityEditor({this.entity, this.initialType, this.allowedTypes});

  final LifeEntity? entity;
  final LifeEntityType? initialType;
  final Set<LifeEntityType>? allowedTypes;

  @override
  State<_EntityEditor> createState() => _EntityEditorState();
}

final class _EntityEditorState extends State<_EntityEditor> {
  late LifeEntityType _type =
      widget.entity?.type ?? widget.initialType ?? LifeEntityType.person;
  late final _name = TextEditingController(text: widget.entity?.displayName);
  late final _subtype = TextEditingController(text: widget.entity?.subtype);

  @override
  void dispose() {
    _name.dispose();
    _subtype.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (widget.entity == null ? 'Add profile' : 'Edit profile').tr,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<LifeEntityType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: 'Profile type'.tr),
            items: [
              for (final template in EntityTemplateRegistry.templates.where(
                (template) =>
                    widget.allowedTypes == null ||
                    widget.allowedTypes!.contains(template.type),
              ))
                DropdownMenuItem(
                  value: template.type,
                  child: Text(template.singularLabel.tr),
                ),
            ],
            onChanged: widget.entity == null
                ? (value) => setState(() => _type = value ?? _type)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Name'.tr),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subtype,
            decoration: InputDecoration(labelText: 'Subtype (optional)'.tr),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                context,
                _EntityDraft(
                  type: _type,
                  displayName: name,
                  subtype: _subtype.text.trim().isEmpty
                      ? null
                      : _subtype.text.trim(),
                ),
              );
            },
            child: Text(AppStrings.btnSave.tr),
          ),
        ],
      ),
    ),
  );
}

final class _EntityDraft {
  const _EntityDraft({
    required this.type,
    required this.displayName,
    this.subtype,
  });

  final LifeEntityType type;
  final String displayName;
  final String? subtype;
}

final class _CustomAttributeEditor extends StatefulWidget {
  const _CustomAttributeEditor();

  @override
  State<_CustomAttributeEditor> createState() => _CustomAttributeEditorState();
}

final class _CustomAttributeEditorState extends State<_CustomAttributeEditor> {
  final _label = TextEditingController();
  final _value = TextEditingController();
  ClaimValueType _type = ClaimValueType.string;

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.txtCustomEncryptedField.tr,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: InputDecoration(labelText: 'Field name'.tr),
        ),
        SizedBox(height: 12),
        DropdownButtonFormField<ClaimValueType>(
          initialValue: _type,
          decoration: InputDecoration(labelText: 'Value type'.tr),
          items: [
            DropdownMenuItem(
              value: ClaimValueType.string,
              child: Text(AppStrings.txtText.tr),
            ),
            DropdownMenuItem(
              value: ClaimValueType.identifier,
              child: Text(AppStrings.txtIdentifier.tr),
            ),
            DropdownMenuItem(
              value: ClaimValueType.uri,
              child: Text(AppStrings.txtWebsiteURI.tr),
            ),
          ],
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _value,
          decoration: InputDecoration(labelText: 'Value'.tr),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () {
            final label = _label.text.trim();
            final value = _value.text.trim();
            if (label.isEmpty || value.isEmpty) return;
            final key = 'CUSTOM_${label.toUpperCase().replaceAll(' ', '_')}';
            final typed = switch (_type) {
              ClaimValueType.identifier => ClaimValue.identifier(value),
              ClaimValueType.uri => ClaimValue.uri(value),
              _ => ClaimValue.string(value),
            };
            Navigator.pop(context, _AttributeDraft(key: key, value: typed));
          },
          child: Text(AppStrings.txtSaveField.tr),
        ),
      ],
    ),
  );
}

final class _AttributeDraft {
  const _AttributeDraft({required this.key, required this.value});

  final String key;
  final ClaimValue value;
}

final class _RelationshipEditor extends StatefulWidget {
  const _RelationshipEditor({required this.entities});

  final List<LifeEntity> entities;

  @override
  State<_RelationshipEditor> createState() => _RelationshipEditorState();
}

final class _RelationshipEditorState extends State<_RelationshipEditor> {
  late String _toEntityId = widget.entities.first.id;
  LifeRelationshipType _type = LifeRelationshipType.relatedTo;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.txtAddRelationship.tr,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _toEntityId,
            decoration: InputDecoration(labelText: 'Related profile'.tr),
            items: [
              for (final entity in widget.entities)
                DropdownMenuItem(
                  value: entity.id,
                  child: Text(entity.displayName),
                ),
            ],
            onChanged: (value) =>
                setState(() => _toEntityId = value ?? _toEntityId),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LifeRelationshipType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: 'Relationship'.tr),
            items: [
              for (final type in LifeRelationshipType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(
                    type.storageValue.replaceAll('_', ' ').toLowerCase(),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _RelationshipDraft(toEntityId: _toEntityId, type: _type),
            ),
            child: Text(AppStrings.txtAddRelationship.tr),
          ),
        ],
      ),
    ),
  );
}

final class _RelationshipDraft {
  const _RelationshipDraft({required this.toEntityId, required this.type});

  final String toEntityId;
  final LifeRelationshipType type;
}

IconData _iconFor(LifeEntityType type) => switch (type) {
  LifeEntityType.person => Icons.person_outline,
  LifeEntityType.family => Icons.groups_outlined,
  LifeEntityType.pet => Icons.pets_outlined,
  LifeEntityType.vehicle => Icons.directions_car_outlined,
  LifeEntityType.property => Icons.home_outlined,
  LifeEntityType.place => Icons.place_outlined,
  LifeEntityType.device => Icons.phone_android_outlined,
  LifeEntityType.appliance => Icons.kitchen_outlined,
  LifeEntityType.organisation => Icons.business_outlined,
  _ => Icons.category_outlined,
};

String _historyLabel(String eventType) => switch (eventType) {
  'ENTITY_CREATED' => 'Profile created',
  'ENTITY_UPDATED' => 'Profile edited',
  'ENTITY_ARCHIVED' => 'Profile archived',
  'ENTITY_RESTORED' => 'Profile restored',
  'ENTITY_ATTRIBUTE_UPDATED' => 'Profile details updated',
  'ENTITY_MERGED_FROM' => 'Duplicate merged into this profile',
  'ENTITY_MERGED_INTO' => 'Profile merged into another profile',
  _ => eventType.toLowerCase().replaceAll('_', ' '),
};

String _displayClaimValue(ClaimValue value) => switch (value.type) {
  ClaimValueType.string ||
  ClaimValueType.identifier ||
  ClaimValueType.uri ||
  ClaimValueType.entityReference => value.stringValue,
  ClaimValueType.integer => '${value.integerValue}',
  ClaimValueType.decimal => '${value.decimalValue}',
  ClaimValueType.boolean => value.booleanValue ? 'Yes' : 'No',
  ClaimValueType.date ||
  ClaimValueType.datetime => value.dateTimeValue.toLocal().toIso8601String(),
  ClaimValueType.money =>
    '${value.moneyValue.currency} '
        '${value.moneyValue.amountMinorUnits / 100}',
};
