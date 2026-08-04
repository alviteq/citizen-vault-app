import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// Screen presenting minimized Emergency Medical Card & responder contacts.
final class EmergencyModeScreen extends StatefulWidget {
  /// Creates the Emergency Mode display screen.
  const EmergencyModeScreen({required this.controller, super.key});

  /// Ingestion and presentation controller.
  final IngestionUiController controller;

  @override
  State<EmergencyModeScreen> createState() => _EmergencyModeScreenState();
}

final class _EmergencyModeScreenState extends State<EmergencyModeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.recordEmergencyAccess();
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
    final env = widget.controller.emergencyStorage.envelope;
    final med = env.medicalRecord;
    final tr = widget.controller.multilingualEngine.translate;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626), // Strong Red
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Icon(Icons.medical_services, size: 24),
            const SizedBox(width: 8),
            Text(
              tr('Emergency Card'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2), // Very soft red
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFDC2626)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings
                          .txtEmergencyStorageBoundaryActiveIsolatedFromMainVaultGraphEvidenceAndClaims
                          .tr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B), // Dark Red text
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        med.fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFDC2626,
                          ), // Blood red background
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          med.bloodGroup,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, color: Color(0xFFF1F5F9)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED), // Soft Orange
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.coronavirus,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    title: Text(
                      AppStrings.knownAllergies.tr,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    subtitle: Text(
                      med.allergies,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF), // Soft Blue
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    title: Text(
                      AppStrings.activeMedications.tr,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    subtitle: Text(
                      med.medications,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF), // Soft Purple
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_hospital,
                        color: Color(0xFF9333EA),
                      ),
                    ),
                    title: Text(
                      AppStrings.primaryPhysician.tr,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    subtitle: Text(
                      '${med.doctorName} (${med.doctorPhone})',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4), // Soft Green
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.health_and_safety,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    title: Text(
                      AppStrings.healthInsurancePolicy.tr,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    subtitle: Text(
                      '${med.insuranceProvider}\n${med.insurancePolicyNumber}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.txtEmergencyResponderContacts.tr,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final contact in env.contacts)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
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
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: contact.isPrimary
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFF1F5F9),
                      foregroundColor: contact.isPrimary
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B),
                      child: Icon(
                        contact.isPrimary ? Icons.star : Icons.person,
                      ),
                    ),
                    title: Text(
                      contact.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '${contact.relationship} • ${contact.phone}',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0FDF4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Dialing ${contact.name} (${contact.phone})...',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: Text('Emergency Access Log (${env.accessLog.length})'),
                onPressed: () =>
                    unawaited(_showAccessLogDialog(context, env.accessLog)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccessLogDialog(
    BuildContext context,
    List<String> logTimestamps,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.accessAuditLogTitle.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.txtTimestampsWhenEmergencyMedicalCardWasOpened.tr,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (logTimestamps.isEmpty)
                Text(AppStrings.noAccessLogsRecorded.tr)
              else
                for (final ts in logTimestamps)
                  Text(' • $ts', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.btnClose.tr),
          ),
        ],
      ),
    );
  }
}
