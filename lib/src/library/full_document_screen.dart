import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/library/document_export_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ocr/vault_ocr.dart';

/// Full-screen authenticated original viewer.
final class FullDocumentScreen extends StatefulWidget {
  /// Creates a viewer for [detail].
  const FullDocumentScreen({
    required this.controller,
    required this.detail,
    super.key,
  });

  /// Unlocked vault controller.
  final IngestionUiController controller;

  /// Encrypted document metadata.
  final DocumentDetailView detail;

  @override
  State<FullDocumentScreen> createState() => _FullDocumentScreenState();
}

final class _FullDocumentScreenState extends State<FullDocumentScreen> {
  DecryptedAssetLease? _lease;
  late final Future<String> _path = _openOriginal();

  Future<String> _openOriginal() async {
    final lease = await widget.controller.documentOriginal(
      widget.detail.summary.id,
      mimeType: widget.detail.summary.mimeType,
    );
    _lease = lease;
    if (!mounted) {
      await lease.close();
      throw StateError('Viewer closed before the document opened.');
    }
    return lease.usePrivatePath((path) async => path);
  }

  @override
  void dispose() {
    final lease = _lease;
    if (lease != null) unawaited(lease.close());
    super.dispose();
  }

  Future<void> _saveCopy() async {
    if (!await confirmDocumentExport(context) || !mounted) return;
    final message = await widget.controller.exportDocument(widget.detail);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111416),
    appBar: AppBar(
      backgroundColor: const Color(0xFF111416),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        widget.detail.summary.logicalFilename,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: <Widget>[
        IconButton(
          tooltip: 'Save a copy',
          onPressed: _saveCopy,
          icon: const Icon(Icons.download_outlined, color: Colors.white),
        ),
      ],
    ),
    body: FutureBuilder<String>(
      future: _path,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const _ViewerMessage(
            icon: Icons.gpp_bad_outlined,
            title: 'Original could not be opened',
            body: 'OwnKeep could not authenticate this document safely.',
          );
        }
        return _OriginalContent(
          path: snapshot.requireData,
          mimeType: widget.detail.summary.mimeType,
        );
      },
    ),
  );
}

final class _OriginalContent extends StatelessWidget {
  const _OriginalContent({required this.path, required this.mimeType});

  final String path;
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    final normalized = mimeType.toLowerCase();
    if (normalized == 'application/pdf') {
      // The default null link handler keeps PDF annotations non-interactive, so
      // untrusted documents cannot launch external URLs from this viewer.
      return PdfViewer.file(path);
    }
    if (normalized.startsWith('image/')) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 8,
        child: Center(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => const _ViewerMessage(
              icon: Icons.broken_image_outlined,
              title: 'Image could not be displayed',
              body: 'The original remains protected inside OwnKeep.',
            ),
          ),
        ),
      );
    }
    if (normalized == 'text/plain') {
      return _PlainTextDocument(path: path);
    }
    return const _ViewerMessage(
      icon: Icons.description_outlined,
      title: 'No built-in viewer for this format',
      body: 'Use Save a copy to open it with another trusted application.',
    );
  }
}

final class _PlainTextDocument extends StatelessWidget {
  const _PlainTextDocument({required this.path});

  final String path;

  static const int _maximumDisplayBytes = 2 * 1024 * 1024;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _read(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final text = snapshot.data;
      if (text == null) {
        return const _ViewerMessage(
          icon: Icons.text_snippet_outlined,
          title: 'Text is too large to display',
          body: 'Use Save a copy to open the complete file safely.',
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          text,
          style: const TextStyle(color: Colors.white, height: 1.4),
        ),
      );
    },
  );

  Future<String?> _read() async {
    final file = File(path);
    if (await file.length() > _maximumDisplayBytes) return null;
    return utf8.decode(await file.readAsBytes(), allowMalformed: true);
  }
}

final class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white70, size: 64),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}
