import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// User-controlled transfer boundary for encrypted `.cvault` archives.
abstract interface class BackupArchiveTransfer {
  /// Opens the system document provider and returns a local readable archive.
  Future<SelectedBackupArchive?> pickArchive();

  /// Exports [archive] through the system document provider.
  Future<bool> exportArchive(File archive);

  /// Returns platform-reported available bytes for the volume containing
  /// [path].
  Future<int> availableBytes(String path);
}

/// A provider-selected archive with its user-visible logical name.
final class SelectedBackupArchive {
  /// Creates a selected archive.
  const SelectedBackupArchive({required this.file, required this.displayName});

  /// Local readable file exposed by the platform picker.
  final File file;

  /// Provider-supplied logical filename shown to the user.
  final String displayName;
}

/// Android Storage Access Framework / iOS document-picker implementation.
final class PlatformBackupArchiveTransfer implements BackupArchiveTransfer {
  /// Creates the platform adapter.
  const PlatformBackupArchiveTransfer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('citizen_vault/files');

  final MethodChannel _channel;

  static const XTypeGroup _backupType = XTypeGroup(
    label: 'OwnKeep encrypted backup',
    extensions: <String>['cvault'],
    mimeTypes: <String>['application/octet-stream'],
    uniformTypeIdentifiers: <String>['public.data'],
  );

  @override
  Future<SelectedBackupArchive?> pickArchive() async {
    final selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_backupType],
    );
    if (selected == null) return null;
    return validateSelectedBackup(selected);
  }

  @override
  Future<bool> exportArchive(File archive) async {
    if (!archive.existsSync() ||
        !archive.path.toLowerCase().endsWith('.cvault')) {
      throw const BackupArchiveTransferFailure('backup_missing');
    }
    try {
      return await _channel.invokeMethod<bool>(
            'exportArchive',
            <String, Object>{'sourcePath': archive.path},
          ) ??
          false;
    } on PlatformException catch (error) {
      throw BackupArchiveTransferFailure('backup_export_failed', cause: error);
    }
  }

  @override
  Future<int> availableBytes(String path) async {
    try {
      final bytes = await _channel.invokeMethod<int>(
        'availableBytes',
        <String, Object>{'path': path},
      );
      if (bytes == null || bytes < 0) {
        throw const BackupArchiveTransferFailure('storage_unavailable');
      }
      return bytes;
    } on BackupArchiveTransferFailure {
      rethrow;
    } on Object catch (error) {
      throw BackupArchiveTransferFailure('storage_unavailable', cause: error);
    }
  }
}

/// Validates the readable provider copy without trusting its cached extension.
///
/// Android document providers can report `.cvault` as
/// `application/octet-stream`; `file_selector_android` then gives its
/// app-private cached copy a `.bin` suffix. The authenticated archive verifier,
/// rather than that mutable suffix, is the security boundary.
SelectedBackupArchive validateSelectedBackup(XFile selected) {
  final file = File(selected.path);
  if (!file.existsSync() || file.lengthSync() <= 0) {
    throw const BackupArchiveTransferFailure('invalid_backup_selection');
  }
  final logicalName = selected.name.toLowerCase().endsWith('.cvault')
      ? selected.name
      : 'Selected OwnKeep backup';
  return SelectedBackupArchive(file: file, displayName: logicalName);
}

/// Stable transfer failure that never exposes provider or sandbox paths.
final class BackupArchiveTransferFailure implements Exception {
  /// Creates a safe transfer failure.
  const BackupArchiveTransferFailure(this.code, {this.cause});

  /// Non-sensitive error identifier.
  final String code;

  /// Internal cause for diagnostics only.
  final Object? cause;
}
