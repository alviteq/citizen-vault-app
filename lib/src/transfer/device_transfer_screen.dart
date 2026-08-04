import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen presenting offline device-to-device transfer pairing & progress.
final class DeviceTransferScreen extends StatefulWidget {
  /// Creates the device-to-device transfer screen.
  const DeviceTransferScreen({required this.controller, super.key});

  /// Controller instance.
  final IngestionUiController controller;

  @override
  State<DeviceTransferScreen> createState() => _DeviceTransferScreenState();
}

final class _DeviceTransferScreenState extends State<DeviceTransferScreen> {
  TransferTransportKind _transport = TransferTransportKind.localNetwork;

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

  void _startPairing() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Direct device transfer is not available yet. Export an encrypted '
          '.cvault backup from Settings instead.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.controller.transferEngine;
    final session = engine.activeSession;
    final prog = engine.currentProgress;
    final tr = widget.controller.multilingualEngine.translate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr('Device-to-Device Transfer'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // Soft Blue
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.phonelink_setup,
                          size: 20,
                          color: Color(0xFF1D4ED8),
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppStrings.txtEncryptedP2PTransferNoServer.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppStrings
                          .txtTransferredVaultArchivesAreByteAndGraphEquivalentAuthenticatedWithSHA256SignaturesAndZeroKeysOrPlaintextLeaveYourDevices
                          .tr,
                      style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Text(
              AppStrings.txtSelectTransportLayer.tr.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
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
                child: Column(
                  children: [
                    for (final t in TransferTransportKind.values)
                      ListTile(
                        title: Text(
                          t.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        trailing: _transport == t
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF3B82F6),
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                color: Color(0xFF94A3B8),
                              ),
                        onTap: () {
                          setState(() => _transport = t);
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (session == null) ...[
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(AppStrings.initiatePairing.tr),
                  onPressed: _startPairing,
                ),
              ),
            ] else ...[
              Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        AppStrings.txtEphemeralPairingPINCode.tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.pairingPin,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sender Device: ${session.senderDeviceId}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      if (prog != null) ...[
                        LinearProgressIndicator(value: prog.fraction),
                        const SizedBox(height: 8),
                        Text(
                          prog.status,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${prog.transferredChunks} / ${prog.totalChunks} '
                          'chunks '
                          '(${(prog.fraction * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send_to_mobile),
                          label: Text(AppStrings.txtSimulateTransferSession.tr),
                          onPressed: null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
