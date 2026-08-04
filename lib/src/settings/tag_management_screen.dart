import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Manages encrypted normalized document tags.
final class TagManagementScreen extends StatelessWidget {
  const TagManagementScreen({required this.controller, super.key});

  final IngestionUiController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('Tags'.tr)),
      body: controller.tags.isEmpty
          ? Center(child: Text('No tags'.tr))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.tags.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tag = controller.tags[index];
                final count = controller.dashboardDocuments
                    .where(
                      (document) =>
                          document.tags.any((item) => item.id == tag.id),
                    )
                    .length;
                return ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(tag.name),
                  subtitle: Text(
                    count == 1 ? '1 record'.tr : '$count records'.tr,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'rename') {
                        _rename(context, tag);
                      } else if (action == 'delete') {
                        _delete(context, tag);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'rename', child: Text('Rename'.tr)),
                      PopupMenuItem(value: 'delete', child: Text('Delete'.tr)),
                    ],
                  ),
                );
              },
            ),
    ),
  );

  Future<void> _rename(BuildContext context, DocumentTagView tag) async {
    final input = TextEditingController(text: tag.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename tag'.tr),
        content: TextField(controller: input, autofocus: true, maxLength: 40),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
    input.dispose();
    if (name == null || name.isEmpty) return;
    await controller.renameTag(tag.id, name);
  }

  Future<void> _delete(BuildContext context, DocumentTagView tag) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete tag?'.tr),
            content: Text(
              'The tag will be removed from records. Documents are not deleted.'
                  .tr,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'.tr),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete'.tr),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await controller.deleteTag(tag.id);
  }
}
