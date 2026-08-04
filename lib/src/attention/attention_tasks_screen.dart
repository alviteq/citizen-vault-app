import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';

final class AttentionTasksScreen extends StatefulWidget {
  const AttentionTasksScreen({required this.controller, super.key});

  final IngestionUiController controller;

  @override
  State<AttentionTasksScreen> createState() => _AttentionTasksScreenState();
}

final class _AttentionTasksScreenState extends State<AttentionTasksScreen> {
  var _filter = 'All';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          AppStrings.navAttention.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Expiring'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Review'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tasks'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Reminders'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _buildAttentionCard(
            Icons.event_busy,
            'Car Insurance expires in 12 days',
            'Expiring',
            const Color(0xFFEF4444),
          ),
          const SizedBox(height: 12),
          _buildAttentionCard(
            Icons.fact_check,
            'Passport OCR needs confirmation',
            'Review',
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          _buildAttentionCard(
            Icons.receipt_long,
            'Electricity bill due tomorrow',
            'Tasks',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          _buildAttentionCard(
            Icons.backup,
            'Backup hasn\'t run for 14 days',
            'Reminders',
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filter = label);
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _buildAttentionCard(
    IconData icon,
    String title,
    String category,
    Color color,
  ) {
    if (_filter != 'All' && _filter != category) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            category,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          onTap: () {
            // Action mapping logic here (simplified for MVP UI flow)
          },
        ),
      ),
    );
  }
}
