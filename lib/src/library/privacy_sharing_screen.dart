// Privacy sharing UI provides user-controlled flattened redactions and warnings.
// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen for configuring privacy-aware sharing with flattened redactions.
final class PrivacySharingScreen extends StatefulWidget {
  const PrivacySharingScreen({
    required this.controller,
    required this.detail,
    super.key,
  });

  final IngestionUiController controller;
  final DocumentDetailView detail;

  @override
  State<PrivacySharingScreen> createState() => _PrivacySharingScreenState();
}

final class _PrivacySharingScreenState extends State<PrivacySharingScreen> {
  final _recipientController = TextEditingController(text: 'Bank');
  final _purposeController = TextEditingController(text: 'Loan Application');

  var _redactId = true;
  var _redactAddress = true;
  var _redactDob = true;
  var _redactQr = true;
  var _redactSignature = true;
  var _stripMetadata = true;
  var _exporting = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  String get _watermarkText {
    final recipient = _recipientController.text.trim().toUpperCase();
    final purpose = _purposeController.text.trim().toUpperCase();
    final date = DateTime.now().toIso8601String().split('T').first;
    return 'FOR ${recipient.isEmpty ? 'RECIPIENT' : recipient} - ${purpose.isEmpty ? 'SHARING' : purpose} - $date';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        AppStrings.privacySharingTitle.tr,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Color(0xFF0F172A),
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF), // Soft Blue
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.security_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings
                        .txtOriginalFileRemainsUntouchedRedactionsAreFlattenedPermanentlyBeforeExport
                        .tr,
                    style: TextStyle(
                      color: Color(0xFF1E3A8A), // Dark blue text
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.txtValue1RecipientPurpose.tr,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _recipientController,
          decoration: const InputDecoration(
            labelText: 'Recipient (e.g. HDFC Bank, Landlord)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _purposeController,
          decoration: const InputDecoration(
            labelText: 'Purpose (e.g. Loan Application, Rental)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.txtValue2FieldRedactionsMasking.tr,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        SwitchListTile(
          title: Text(AppStrings.txtMaskIDNumbersAadhaarPANPassport.tr),
          value: _redactId,
          onChanged: (val) => setState(() => _redactId = val),
        ),
        SwitchListTile(
          title: Text(AppStrings.txtMaskResidentialAddress.tr),
          value: _redactAddress,
          onChanged: (val) => setState(() => _redactAddress = val),
        ),
        SwitchListTile(
          title: Text(AppStrings.txtMaskDateOfBirth.tr),
          value: _redactDob,
          onChanged: (val) => setState(() => _redactDob = val),
        ),
        SwitchListTile(
          title: Text(AppStrings.txtMaskQRCodesBarcodes.tr),
          value: _redactQr,
          onChanged: (val) => setState(() => _redactQr = val),
        ),
        SwitchListTile(
          title: Text(AppStrings.txtMaskSignatures.tr),
          value: _redactSignature,
          onChanged: (val) => setState(() => _redactSignature = val),
        ),
        SwitchListTile(
          title: Text(AppStrings.txtStripEXIFFileMetadata.tr),
          value: _stripMetadata,
          onChanged: (val) => setState(() => _stripMetadata = val),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.txtValue3WatermarkPreview.tr,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _watermarkText,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7), // Soft Amber for warning
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFF92400E)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings
                        .txtNoticeExportedCopiesLeaveOwnKeepProtectionAndCannotBeRemotelyRevoked
                        .tr,
                    style: TextStyle(
                      color: Color(0xFF92400E), // Dark amber text
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _exporting ? null : _exportRedacted,
          icon: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share_outlined),
          label: Text(AppStrings.txtExportRedactedWatermarkedCopy.tr),
        ),
      ],
    ),
  );

  Future<void> _exportRedacted() async {
    final options = PrivacyExportOptions(
      recipient: _recipientController.text.trim(),
      purpose: _purposeController.text.trim(),
      watermarkText: _watermarkText,
      redactIdNumbers: _redactId,
      redactAddress: _redactAddress,
      redactDateOfBirth: _redactDob,
      redactQrBarcodes: _redactQr,
      redactSignatures: _redactSignature,
      stripMetadata: _stripMetadata,
    );

    setState(() => _exporting = true);
    final result = await widget.controller.exportRedactedDocument(
      widget.detail,
      options,
    );
    if (!mounted) return;
    setState(() => _exporting = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }
}
