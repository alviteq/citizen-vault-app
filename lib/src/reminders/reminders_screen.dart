import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Upcoming local reminders and reconciliation actions.
final class RemindersScreen extends StatefulWidget {
  /// Creates the reminder screen.
  const RemindersScreen({required this.controller, super.key});

  /// Unlocked controller.
  final IngestionUiController controller;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

final class _RemindersScreenState extends State<RemindersScreen> {
  IngestionUiController get controller => widget.controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        AppStrings.remindersTitle.tr,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
    ),
    body: RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _ReminderDefaultsCard(
            offsets: controller.preferences.defaultReminderOffsets,
            onChanged: _saveOffsets,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.txtNotificationsAreLocalAndContainNoDocumentDetails.tr,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (controller.reminders.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: <Widget>[
                  Icon(Icons.notifications_off_outlined, size: 52),
                  SizedBox(height: 12),
                  Text(AppStrings.noUpcomingReminders.tr),
                  Text(AppStrings.addFromDocumentDetail.tr),
                ],
              ),
            )
          else
            for (final reminder in controller.reminders)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
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
                        Icons.event_outlined,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    title: Text(
                      reminder.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${reminder.documentFilename}\n'
                      '${_format(reminder.dueAt)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF94A3B8),
                      ),
                      onSelected: (action) {
                        unawaited(_act(context, controller, reminder, action));
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        PopupMenuItem(
                          value: 'snooze',
                          child: Text(AppStrings.btnSnooze1Day.tr),
                        ),
                        PopupMenuItem(
                          value: 'reschedule',
                          child: Text(AppStrings.btnChooseNewDate.tr),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            (reminder.isEnabled ? 'Disable' : 'Enable').tr,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'complete',
                          child: Text(AppStrings.btnMarkCompleted.tr),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(AppStrings.btnDelete.tr),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );

  Future<void> _saveOffsets(List<int> offsets) async {
    final current = controller.preferences;
    await controller.savePreferences(
      VaultPreferencesView(
        useGrid: current.useGrid,
        darkMode: current.darkMode,
        defaultReminderOffsets: offsets,
        lastBackupAt: current.lastBackupAt,
        lastBackupObjectCount: current.lastBackupObjectCount,
      ),
    );
    if (mounted) setState(() {});
  }

  static Future<void> _act(
    BuildContext context,
    IngestionUiController controller,
    ReminderView reminder,
    String action,
  ) async {
    switch (action) {
      case 'snooze':
        await controller.snoozeReminder(reminder.id, const Duration(days: 1));
        return;
      case 'reschedule':
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          firstDate: now,
          lastDate: DateTime(now.year + 10),
          initialDate: reminder.dueAt.toLocal().isAfter(now)
              ? reminder.dueAt.toLocal()
              : now,
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(reminder.dueAt.toLocal()),
        );
        if (time == null) return;
        final target = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (!target.isAfter(DateTime.now())) return;
        await controller.rescheduleReminder(reminder.id, target);
        return;
      case 'toggle':
        await controller.setReminderEnabled(reminder.id, !reminder.isEnabled);
        return;
      case 'complete':
        await controller.completeReminder(reminder.id);
        return;
      case 'delete':
        await controller.deleteReminder(reminder.id);
        return;
    }
  }
}

final class _ReminderDefaultsCard extends StatelessWidget {
  const _ReminderDefaultsCard({required this.offsets, required this.onChanged});

  final List<int> offsets;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    const choices = <int>[30, 14, 7, 3, 1];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default reminder choices'.tr,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'These choices appear when reviewing an expiry or due date.'.tr,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final days in choices)
                  FilterChip(
                    label: Text((days == 1 ? '1 day' : '$days days').tr),
                    selected: offsets.contains(days),
                    onSelected: (selected) {
                      final updated = offsets.toSet();
                      if (selected) {
                        updated.add(days);
                      } else if (updated.length > 1) {
                        updated.remove(days);
                      }
                      onChanged(
                        updated.toList()..sort((a, b) => b.compareTo(a)),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _format(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour}:$minute';
}
