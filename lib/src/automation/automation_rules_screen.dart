import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen presenting local WHEN / IF / THEN automation rules and audit logs.
final class AutomationRulesScreen extends StatefulWidget {
  /// Creates the automation rules screen.
  const AutomationRulesScreen({required this.controller, super.key});

  /// Ingestion and presentation controller.
  final IngestionUiController controller;

  @override
  State<AutomationRulesScreen> createState() => _AutomationRulesScreenState();
}

final class _AutomationRulesScreenState extends State<AutomationRulesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.controller.automationEngine;
    final rules = engine.rules;
    final auditLogs = engine.auditLogs;
    final tr = widget.controller.multilingualEngine.translate;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr('Offline Automation Engine'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0B4A99),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0B4A99),
          dividerColor: const Color(0xFFF1F5F9),
          tabs: [
            Tab(
              icon: const Icon(Icons.auto_awesome),
              text: 'Active Rules (${rules.length})',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long),
              text: 'Execution Audit (${auditLogs.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // Soft Blue
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            size: 20,
                            color: Color(0xFF1D4ED8),
                          ),
                          SizedBox(width: 8),
                          Text(
                            AppStrings.txtOfflineSafetyGuaranteed.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        AppStrings
                            .txtAutomationRuns100LocallyWithBoundedRecursionCycleDetectionAuditTrailsAndZeroExternalNetworkCalls
                            .tr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final rule = rules[index - 1];
              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rule.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Switch(
                          value: rule.isEnabled,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            widget.controller.toggleAutomationRule(
                              rule.id,
                              val,
                            );
                          },
                        ),
                      ],
                    ),
                    if (rule.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        rule.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(
                            Icons.bolt,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          label: Text(
                            'WHEN: ${rule.trigger.displayName}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: const Color(0xFFFEF3C7),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        FilterChip(
                          selected: rule.isPreviewMode,
                          avatar: Icon(
                            Icons.visibility,
                            size: 16,
                            color: rule.isPreviewMode
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF94A3B8),
                          ),
                          label: Text(
                            rule.isPreviewMode ? 'Preview Mode' : 'Live Mode',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: rule.isPreviewMode
                                  ? const Color(0xFF1E3A8A)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          selectedColor: const Color(0xFFDBEAFE),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: (val) {
                            widget.controller.toggleAutomationPreviewMode(
                              rule.id,
                              val,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),
                    Text(
                      'IF Conditions (${rule.filters.length}):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final f in rule.filters)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.filter_alt_outlined,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '`${f.field}` ${f.operator.displayName} "${f.targetValue}"',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF334155),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'THEN Actions (${rule.actions.length}):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final a in rule.actions)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4), // Soft Green
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${a.kind.displayName} ${a.parameters}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (auditLogs.isEmpty)
            Center(child: Text(AppStrings.noAutomationExecutions.tr))
          else
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: auditLogs.length,
              itemBuilder: (context, index) {
                final log = auditLogs[index];
                final dateStr = log.triggeredAt
                    .toIso8601String()
                    .split('.')
                    .first;
                final isUndone = log.statusSummary.startsWith('Undone');

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: log.wasPreview
                          ? Colors.orange.withAlpha(40)
                          : Colors.green.withAlpha(40),
                      child: Icon(
                        log.wasPreview ? Icons.preview : Icons.play_arrow,
                        color: log.wasPreview ? Colors.orange : Colors.green,
                      ),
                    ),
                    title: Text(
                      log.ruleTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          '${log.triggerKind.displayName} • $dateStr',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log.statusSummary,
                          style: TextStyle(
                            fontSize: 12,
                            color: isUndone ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                    trailing: log.undoSnapshot != null
                        ? IconButton(
                            icon: const Icon(Icons.undo),
                            tooltip: 'Undo Automation',
                            onPressed: () {
                              widget.controller.undoAutomationExecution(log.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Reverted execution of ${log.ruleTitle}.',
                                  ),
                                ),
                              );
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(AppStrings.btnAddRule.tr),
        onPressed: () => unawaited(_showAddRuleDialog(context)),
      ),
    );
  }

  Future<void> _showAddRuleDialog(BuildContext dialogContext) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final filterFieldCtrl = TextEditingController(text: 'category');
    final filterValueCtrl = TextEditingController(text: 'vehicle');
    var trigger = AutomationTriggerKind.reviewConfirmed;
    var actionKind = AutomationActionKind.linkToEntity;

    await showDialog<void>(
      context: dialogContext,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(AppStrings.addAutomationRuleTitle.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rule Title *',
                    hintText: 'e.g. Auto-link Expense Invoices',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Rule purpose...',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AutomationTriggerKind>(
                  initialValue: trigger,
                  decoration: const InputDecoration(labelText: 'WHEN Trigger'),
                  items: AutomationTriggerKind.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => trigger = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: filterFieldCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IF Field Name',
                    hintText: 'e.g. category, mimeType, cost',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: filterValueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IF Target Value',
                    hintText: 'e.g. vehicle, application/pdf',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AutomationActionKind>(
                  initialValue: actionKind,
                  decoration: const InputDecoration(labelText: 'THEN Action'),
                  items: AutomationActionKind.values
                      .map(
                        (a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => actionKind = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppStrings.btnCancel.tr),
            ),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final newRule = AutomationRule(
                  id: 'rule-${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  trigger: trigger,
                  filters: [
                    AutomationFilter(
                      field: filterFieldCtrl.text.trim(),
                      operator: AutomationFilterOp.equals,
                      targetValue: filterValueCtrl.text.trim(),
                    ),
                  ],
                  actions: [AutomationAction(kind: actionKind)],
                );
                widget.controller.addOrUpdateAutomationRule(newRule);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Automation rule "$title" saved.')),
                );
              },
              child: Text(AppStrings.btnSaveRule.tr),
            ),
          ],
        ),
      ),
    );
  }
}
