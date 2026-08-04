import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/library/document_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Displays measured private-vault storage without exposing local paths.
final class VaultStorageScreen extends StatefulWidget {
  const VaultStorageScreen({required this.controller, super.key});

  final IngestionUiController controller;

  @override
  State<VaultStorageScreen> createState() => _VaultStorageScreenState();
}

final class _VaultStorageScreenState extends State<VaultStorageScreen> {
  late Future<VaultStorageSummary> _summary;
  var _cleaning = false;

  @override
  void initState() {
    super.initState();
    _summary = widget.controller.storageSummary();
  }

  void _refresh() {
    setState(() => _summary = widget.controller.storageSummary());
  }

  Future<void> _cleanTemporaryStorage() async {
    if (_cleaning) return;
    setState(() => _cleaning = true);
    try {
      await widget.controller.cleanTemporaryStorage();
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temporary private files cleaned.')),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temporary storage could not be cleaned safely.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = widget.controller.dashboardDocuments;
    final archived = documents.where((document) => document.isArchived).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Storage'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Measure again',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<VaultStorageSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StorageError(onRetry: _refresh);
          }
          final summary = snapshot.data ?? const VaultStorageSummary.empty();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF0B4A99),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Encrypted vault usage',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatBytes(summary.totalBytes),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${documents.length} records • '
                        '${summary.fileCount} private files',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _StorageTile(
                icon: Icons.folder_copy_outlined,
                title: 'Encrypted originals',
                subtitle: 'Authenticated object storage',
                bytes: summary.objectBytes,
              ),
              _StorageTile(
                icon: Icons.table_chart_outlined,
                title: 'Encrypted database',
                subtitle: 'Metadata, search, graph, and reminders',
                bytes: summary.databaseBytes,
              ),
              _StorageTile(
                icon: Icons.hourglass_bottom_outlined,
                title: 'Temporary processing',
                subtitle: 'Short-lived OCR and backup working files',
                bytes: summary.temporaryBytes,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: OutlinedButton.icon(
                  onPressed: _cleaning ? null : _cleanTemporaryStorage,
                  icon: _cleaning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Clean temporary files'),
                ),
              ),
              _StorageTile(
                icon: Icons.security_outlined,
                title: 'Vault metadata',
                subtitle: 'Protected configuration and other private files',
                bytes: summary.otherBytes,
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: const Icon(Icons.description_outlined),
                title: const Text('All records'),
                subtitle: Text('${documents.length} encrypted records'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DocumentLibraryScreen(controller: widget.controller),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: const Icon(Icons.delete_outline),
                title: const Text('Recently deleted'),
                subtitle: const Text('Review or restore recoverable records'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DocumentLibraryScreen(
                      controller: widget.controller,
                      initialFilter: const DocumentLibraryFilter(
                        deletedOnly: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Archived records'),
                subtitle: Text('$archived archived records'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DocumentLibraryScreen(
                      controller: widget.controller,
                      initialFilter: const DocumentLibraryFilter(
                        archivedOnly: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'OwnKeep counts files inside its private vault only. Copies '
                'you explicitly export are controlled by their destination '
                'and are not included here.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kib = bytes / 1024;
    if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
    final mib = kib / 1024;
    if (mib < 1024) return '${mib.toStringAsFixed(1)} MB';
    return '${(mib / 1024).toStringAsFixed(2)} GB';
  }
}

final class _StorageTile extends StatelessWidget {
  const _StorageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bytes,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int bytes;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Text(_VaultStorageScreenState._formatBytes(bytes)),
  );
}

final class _StorageError extends StatelessWidget {
  const _StorageError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 12),
        const Text('Vault storage could not be measured.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
