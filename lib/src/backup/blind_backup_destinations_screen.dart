import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen presenting user-selected blind cloud & network backup destinations.
final class BlindBackupDestinationsScreen extends StatefulWidget {
  /// Creates the blind backup destinations screen.
  const BlindBackupDestinationsScreen({required this.controller, super.key});

  /// Controller instance.
  final IngestionUiController controller;

  @override
  State<BlindBackupDestinationsScreen> createState() =>
      _BlindBackupDestinationsScreenState();
}

final class _BlindBackupDestinationsScreenState
    extends State<BlindBackupDestinationsScreen> {
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

  void _triggerSync() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Automatic provider sync is not configured. Use Encrypted Backup '
          'in Settings to save a verified .cvault archive to your provider.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.controller.blindBackupEngine;
    final cfg = engine.activeConfig;
    final status = engine.syncStatus;
    final tr = widget.controller.multilingualEngine.translate;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr('Blind Backup Destinations'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
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
                color: const Color(0xFFEFF6FF), // Soft Blue
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_off, size: 20, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 8),
                      Text(
                        AppStrings.txtZeroTokenBlindBackupPolicy.tr,
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
                        .txtOnlyEncryptedArchiveBytesLeaveYourDeviceZeroProviderTokensOrMasterVaultKeysAreRetainedByOwnKeep
                        .tr,
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.txtSelectDestinationProvider.tr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    for (
                      var i = 0;
                      i < BlindBackupDestinationKind.values.length;
                      i++
                    ) ...[
                      if (i > 0)
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          BlindBackupDestinationKind.values[i].displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        trailing:
                            cfg.destinationKind ==
                                BlindBackupDestinationKind.values[i]
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF3B82F6),
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                color: Color(0xFFCBD5E1),
                              ),
                        onTap: () {
                          widget.controller.configureBlindBackupDestination(
                            BlindBackupConfig(
                              destinationKind:
                                  BlindBackupDestinationKind.values[i],
                              accountIdentifier: cfg.accountIdentifier,
                              remoteDirectoryPath: cfg.remoteDirectoryPath,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.txtActiveDestinationConfiguration.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ConfigRow(
                    label: 'Provider',
                    value: cfg.destinationKind.displayName,
                  ),
                  _ConfigRow(label: 'Account', value: cfg.accountIdentifier),
                  _ConfigRow(
                    label: 'Remote Path',
                    value: cfg.remoteDirectoryPath,
                  ),
                  if (cfg.lastSyncAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Last Synced: ${cfg.lastSyncAt!.toIso8601String().split('T').first}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (status != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4), // Soft Green
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        status.statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.sync),
                      label: Text(
                        AppStrings.triggerBlindSync.tr,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _triggerSync,
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

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
