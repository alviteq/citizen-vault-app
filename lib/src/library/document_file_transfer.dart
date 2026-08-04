import 'dart:io';

import 'package:flutter/services.dart';

/// User-controlled plaintext export boundary for one authenticated original.
// The interface is an injectable native security boundary.
// ignore: one_member_abstracts
abstract interface class DocumentFileTransfer {
  /// Saves [source] through the system document provider.
  Future<bool> exportDocument({
    required File source,
    required String suggestedName,
    required String mimeType,
  });
}

/// Android Storage Access Framework / iOS document-picker implementation.
final class PlatformDocumentFileTransfer implements DocumentFileTransfer {
  /// Creates the platform adapter.
  const PlatformDocumentFileTransfer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('citizen_vault/files');

  final MethodChannel _channel;

  @override
  Future<bool> exportDocument({
    required File source,
    required String suggestedName,
    required String mimeType,
  }) async {
    if (!source.existsSync() || source.lengthSync() <= 0) {
      throw const DocumentFileTransferFailure('document_missing');
    }
    try {
      return await _channel
              .invokeMethod<bool>('exportDocument', <String, Object>{
                'sourcePath': source.path,
                'suggestedName': suggestedName,
                'mimeType': mimeType,
              }) ??
          false;
    } on PlatformException catch (error) {
      throw DocumentFileTransferFailure('document_export_failed', cause: error);
    }
  }
}

/// Stable transfer failure that never exposes plaintext paths.
final class DocumentFileTransferFailure implements Exception {
  /// Creates a safe transfer failure.
  const DocumentFileTransferFailure(this.code, {this.cause});

  /// Non-sensitive error identifier.
  final String code;

  /// Internal diagnostics only.
  final Object? cause;
}
