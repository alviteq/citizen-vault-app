import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

/// Native document scanner flow. The scanner returns temporary paths which
/// are streamed directly into the encrypted ingestion pipeline.
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({required this.controller, super.key});

  final IngestionUiController controller;

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  List<String> _paths = const <String>[];
  bool _busy = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.controller.beginExternalActivity();
    try {
      final paths = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        asPdf: true,
      );
      if (!mounted) return;
      setState(() => _paths = paths ?? const <String>[]);
    } catch (_) {
      if (mounted) setState(() => _error = 'Scanner could not be opened.');
    } finally {
      widget.controller.endExternalActivity();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_paths.isEmpty) return;
    final path = _paths.single;
    final file = File(path);
    final length = await file.length();
    await widget.controller.importCandidate(
      IngestionCandidate(
        logicalFilename: 'Scan-${DateTime.now().millisecondsSinceEpoch}.pdf',
        mimeType: lookupMimeType(path) ?? 'application/pdf',
        length: length,
        source: DocumentImportSource.camera,
        openRead: file.openRead,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(AppStrings.btnReviewScan.tr),
      ),
      body: SafeArea(
        child: Center(
          child: _busy
              ? const CircularProgressIndicator(color: Colors.white)
              : _paths.isEmpty
              ? _emptyState()
              : _reviewState(),
        ),
      ),
    );
  }

  Widget _emptyState() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.document_scanner, size: 84, color: Colors.white70),
      const SizedBox(height: 20),
      Text(
        'Scan documents securely into OwnKeep'.tr,
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await widget.controller.importFile();
            if (mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.folder_open),
          label: Text('Choose from files'.tr),
        ),
      ],
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _scan,
        icon: const Icon(Icons.camera_alt),
        label: Text('Start scanning'.tr),
      ),
    ],
  );

  Widget _reviewState() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.picture_as_pdf, size: 96, color: Colors.white),
      const SizedBox(height: 16),
      Text(
        'Scan ready to secure'.tr,
        style: const TextStyle(color: Colors.white),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.lock),
        label: Text('Save to OwnKeep'.tr),
      ),
      TextButton(onPressed: _scan, child: Text('Scan again'.tr)),
    ],
  );
}
