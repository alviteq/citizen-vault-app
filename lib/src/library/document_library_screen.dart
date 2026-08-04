import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/document_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

enum DocumentCategory {
  all('All'),
  identity('Identity'),
  financial('Financial'),
  insurance('Insurance'),
  medical('Medical'),
  property('Property'),
  vehicle('Vehicle'),
  education('Education'),
  employment('Employment'),
  bills('Bills & Receipts'),
  legal('Legal'),
  certificates('Certificates'),
  family('Family'),
  photos('Photos'),
  notes('Notes'),
  other('Other');

  const DocumentCategory(this.displayName);
  final String displayName;

  bool containsDocument(DocumentListItemView document) {
    if (this == all) return true;
    final type = document.documentType;
    final name = document.logicalFilename.toLowerCase();
    switch (this) {
      case identity:
        return [
          DocumentType.aadhaar,
          DocumentType.pan,
          DocumentType.passport,
          DocumentType.drivingLicence,
          DocumentType.voterId,
        ].contains(type);
      case financial:
        return [
          DocumentType.bankStatement,
          DocumentType.invoice,
          DocumentType.receipt,
        ].contains(type);
      case insurance:
        return type == DocumentType.insurancePolicy;
      case medical:
        return [
          DocumentType.medicalReport,
          DocumentType.prescription,
        ].contains(type);
      case property:
        return type == DocumentType.propertyTax;
      case vehicle:
        return type == DocumentType.vehicleDocument;
      case education:
        return type == DocumentType.educationCertificate;
      case employment:
        return _containsAny(name, const [
          'employment',
          'salary',
          'payslip',
          'offer letter',
          'experience',
        ]);
      case bills:
        return [
          DocumentType.electricityBill,
          DocumentType.waterBill,
          DocumentType.gasBill,
        ].contains(type);
      case legal:
        return _containsAny(name, const [
          'agreement',
          'affidavit',
          'legal',
          'contract',
          'deed',
          'will',
        ]);
      case certificates:
        return type == DocumentType.educationCertificate ||
            _containsAny(name, const ['certificate', 'licence', 'license']);
      case family:
        return _containsAny(name, const [
          'family',
          'marriage',
          'birth',
          'dependent',
        ]);
      case photos:
        return document.mimeType.startsWith('image/') &&
            type == DocumentType.generalDocument;
      case notes:
        return document.mimeType == 'text/plain' ||
            _containsAny(name, const ['note', 'memo']);
      case other:
        return type == DocumentType.generalDocument ||
            type == DocumentType.unknown;
      case all:
        return true;
    }
  }

  static bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);
}

enum _TopFilter { all, favourites, recent, archived }

final class DocumentLibraryScreen extends StatefulWidget {
  const DocumentLibraryScreen({
    required this.controller,
    this.initialFilter = const DocumentLibraryFilter(),
    super.key,
  });

  final IngestionUiController controller;
  final DocumentLibraryFilter initialFilter;

  @override
  State<DocumentLibraryScreen> createState() => _DocumentLibraryScreenState();
}

final class _DocumentLibraryScreenState extends State<DocumentLibraryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  _TopFilter _topFilter = _TopFilter.all;
  DocumentCategory _categoryFilter = DocumentCategory.all;
  String? _tagId;
  bool _isGridView = true;
  bool _loading = true;
  late DocumentSort _sort;
  final Set<String> _selected = <String>{};

  bool get _trashMode => widget.initialFilter.deletedOnly;

  @override
  void initState() {
    super.initState();
    _isGridView = widget.controller.preferences.useGrid;
    _sort = widget.initialFilter.sort;
    _search.text = widget.initialFilter.query;
    if (widget.initialFilter.archivedOnly) {
      _topFilter = _TopFilter.archived;
    } else if (widget.initialFilter.favouritesOnly) {
      _topFilter = _TopFilter.favourites;
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    await widget.controller.loadDocuments(
      DocumentLibraryFilter(
        query: _search.text,
        favouritesOnly: _topFilter == _TopFilter.favourites,
        archivedOnly: _topFilter == _TopFilter.archived,
        deletedOnly: _trashMode,
        tagId: _tagId,
        sort: _topFilter == _TopFilter.recent ? DocumentSort.newest : _sort,
      ),
    );
    if (mounted) setState(() => _loading = false);
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_load());
    });
  }

  Future<void> _open(DocumentListItemView document) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DocumentDetailScreen(
          controller: widget.controller,
          documentId: document.id,
        ),
      ),
    );
    await _load();
  }

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  AppStrings.txtFilterByType.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: DocumentCategory.values.length,
                  itemBuilder: (context, index) {
                    final cat = DocumentCategory.values[index];
                    final isSelected = _categoryFilter == cat;
                    final count = widget.controller.dashboardDocuments
                        .where(cat.containsDocument)
                        .length;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      title: Text(
                        cat.displayName,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        count == 1 ? '1 record'.tr : '$count records'.tr,
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF2563EB))
                          : null,
                      onTap: () {
                        setState(() => _categoryFilter = cat);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: <Widget>[
            ListTile(
              title: Text('All tags'.tr),
              trailing: _tagId == null ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _tagId = null);
                Navigator.pop(context);
                unawaited(_load());
              },
            ),
            for (final tag in widget.controller.tags)
              ListTile(
                title: Text(tag.name),
                trailing: _tagId == tag.id ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() => _tagId = tag.id);
                  Navigator.pop(context);
                  unawaited(_load());
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Client-side filtering for category
    final documents = widget.controller.documents.where((doc) {
      if (_categoryFilter == DocumentCategory.all) return true;
      return _categoryFilter.containsDocument(doc);
    }).toList();
    final width = MediaQuery.sizeOf(context).width;
    final gridColumns = width >= 1400
        ? 5
        : width >= 1050
        ? 4
        : width >= 700
        ? 3
        : 2;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _selected.isNotEmpty
              ? '${_selected.length} selected'
              : (_trashMode ? 'Recently Deleted'.tr : 'Documents'.tr),
        ),
        actions: [
          if (_selected.isNotEmpty) ...[
            PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'primary':
                    unawaited(_selectedAction());
                  case 'favourite':
                    unawaited(_favouriteSelected());
                  case 'tags':
                    unawaited(_tagSelected());
                  case 'trash':
                    unawaited(_trashSelected());
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem(
                  value: 'primary',
                  child: Text((_trashMode ? 'Restore' : 'Archive').tr),
                ),
                if (!_trashMode) ...[
                  PopupMenuItem(
                    value: 'favourite',
                    child: Text('Favourite'.tr),
                  ),
                  PopupMenuItem(value: 'tags', child: Text('Edit tags'.tr)),
                  PopupMenuItem(
                    value: 'trash',
                    child: Text('Move to trash'.tr),
                  ),
                ],
              ],
            ),
            IconButton(
              tooltip: 'Cancel'.tr,
              onPressed: () => setState(_selected.clear),
              icon: const Icon(Icons.close),
            ),
          ] else ...[
            PopupMenuButton<DocumentSort>(
              tooltip: 'Sort'.tr,
              initialValue: _sort,
              onSelected: (value) {
                setState(() => _sort = value);
                unawaited(_load());
              },
              itemBuilder: (context) => <PopupMenuEntry<DocumentSort>>[
                for (final value in DocumentSort.values)
                  PopupMenuItem<DocumentSort>(
                    value: value,
                    child: Text(_sortLabel(value).tr),
                  ),
              ],
              icon: const Icon(Icons.sort),
            ),
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list : Icons.grid_view,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: _toggleView,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            if (!_trashMode)
              Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: TextField(
                  controller: _search,
                  onChanged: _searchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search documents...'.tr,
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

            // Filter Bar
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTopFilterChip('All', _TopFilter.all),
                    const SizedBox(width: 8),
                    _buildTopFilterChip('Favourites', _TopFilter.favourites),
                    const SizedBox(width: 8),
                    _buildTopFilterChip('Archived', _TopFilter.archived),
                    const SizedBox(width: 16),
                    Container(
                      height: 24,
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(width: 16),
                    ActionChip(
                      label: Text(_categoryFilter.displayName),
                      avatar: const Icon(Icons.filter_list, size: 16),
                      onPressed: _showCategorySheet,
                      backgroundColor: _categoryFilter != DocumentCategory.all
                          ? const Color(0xFFDBEAFE)
                          : Theme.of(context).colorScheme.surface,
                      side: BorderSide(
                        color: _categoryFilter != DocumentCategory.all
                            ? const Color(0xFF93C5FD)
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      label: Text(
                        _tagId == null
                            ? 'Tags'.tr
                            : widget.controller.tags
                                      .where((tag) => tag.id == _tagId)
                                      .map((tag) => tag.name)
                                      .firstOrNull ??
                                  'Tags'.tr,
                      ),
                      avatar: const Icon(Icons.label_outline, size: 16),
                      onPressed: _showTagSheet,
                    ),
                  ],
                ),
              ),
            ),

            // Documents Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : documents.isEmpty
                    ? Center(
                        child: ListView(
                          children: [
                            const SizedBox(height: 96),
                            const Icon(
                              Icons.folder_open_outlined,
                              size: 56,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.txtNoRecordsFound.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridColumns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: width >= 700 ? 0.9 : 0.8,
                        ),
                        itemCount: documents.length,
                        itemBuilder: (context, index) => _GridItem(
                          controller: widget.controller,
                          document: documents[index],
                          onTap: () => _selected.isEmpty
                              ? _open(documents[index])
                              : _toggleSelected(documents[index].id),
                          onLongPress: () =>
                              _toggleSelected(documents[index].id),
                          selected: _selected.contains(documents[index].id),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: documents.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ListItem(
                            controller: widget.controller,
                            document: documents[index],
                            onTap: () => _selected.isEmpty
                                ? _open(documents[index])
                                : _toggleSelected(documents[index].id),
                            onLongPress: () =>
                                _toggleSelected(documents[index].id),
                            selected: _selected.contains(documents[index].id),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleView() async {
    final value = !_isGridView;
    setState(() => _isGridView = value);
    final current = widget.controller.preferences;
    await widget.controller.savePreferences(
      VaultPreferencesView(
        useGrid: value,
        darkMode: current.darkMode,
        defaultReminderOffsets: current.defaultReminderOffsets,
        lastBackupAt: current.lastBackupAt,
        lastBackupObjectCount: current.lastBackupObjectCount,
      ),
    );
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  Future<void> _selectedAction() async {
    if (_trashMode) {
      await widget.controller.restoreDocumentsFromTrash(_selected);
    } else {
      await widget.controller.setDocumentsArchived(_selected, true);
    }
    _selected.clear();
    await _load();
  }

  Future<void> _trashSelected() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Move records to trash?'.tr),
            content: Text(
              'The encrypted originals can be restored from Recently Deleted.'
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
    await widget.controller.moveDocumentsToTrash(_selected);
    _selected.clear();
    await _load();
  }

  Future<void> _favouriteSelected() async {
    await widget.controller.setDocumentsFavourite(_selected, true);
    _selected.clear();
    await _load();
  }

  Future<void> _tagSelected() async {
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Replace tags'.tr),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Comma-separated tags'.tr),
        ),
        actions: <Widget>[
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
    final tags = value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    await widget.controller.replaceTagsForDocuments(_selected, tags);
    _selected.clear();
    await _load();
  }

  String _sortLabel(DocumentSort sort) => switch (sort) {
    DocumentSort.newest => 'Newest first',
    DocumentSort.oldest => 'Oldest first',
    DocumentSort.name => 'Name',
    DocumentSort.type => 'Document type',
    DocumentSort.upcomingReminder => 'Upcoming reminder',
  };

  Widget _buildTopFilterChip(String label, _TopFilter filter) {
    final isSelected = _topFilter == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _topFilter = filter);
          unawaited(_load());
        }
      },
      selectedColor: Theme.of(context).colorScheme.secondaryContainer,
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({
    required this.controller,
    required this.document,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });

  final IngestionUiController controller;
  final DocumentListItemView document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isPdf = document.mimeType == 'application/pdf';
    return Semantics(
      button: true,
      label: 'Open ${document.logicalFilename}',
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: _DocumentThumbnail(
                  controller: controller,
                  document: document,
                  large: true,
                ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.logicalFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (isPdf ? 'PDF' : 'Image').tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.controller,
    required this.document,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });

  final IngestionUiController controller;
  final DocumentListItemView document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isPdf = document.mimeType == 'application/pdf';
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surface,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          onTap: onTap,
          onLongPress: onLongPress,
          leading: SizedBox(
            width: 48,
            height: 48,
            child: _DocumentThumbnail(
              controller: controller,
              document: document,
            ),
          ),
          title: Text(
            document.logicalFilename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            (isPdf ? 'PDF' : 'Image').tr,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({
    required this.controller,
    required this.document,
    this.large = false,
  });

  final IngestionUiController controller;
  final DocumentListItemView document;
  final bool large;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: controller.documentPreview(document.id),
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes != null && bytes.isNotEmpty) {
        return ClipRRect(
          borderRadius: large
              ? const BorderRadius.vertical(top: Radius.circular(15))
              : BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(context),
          ),
        );
      }
      return _fallback(context);
    },
  );

  Widget _fallback(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: large
          ? const BorderRadius.vertical(top: Radius.circular(15))
          : BorderRadius.circular(10),
    ),
    child: Center(
      child: Icon(
        document.mimeType == 'application/pdf'
            ? Icons.picture_as_pdf
            : Icons.image,
        size: large ? 48 : 26,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
