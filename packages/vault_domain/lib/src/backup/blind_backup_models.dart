import 'package:meta/meta.dart';

/// Supported blind backup destinations.
enum BlindBackupDestinationKind {
  /// Google Drive blind encrypted vault folder.
  googleDrive('Google Drive Encrypted Vault'),

  /// Apple iCloud blind encrypted container.
  iCloud('iCloud Private Storage'),

  /// Local NAS (Network Attached Storage) SMB/NFS share.
  localNas('Local NAS Share'),

  /// Self-hosted WebDAV server.
  webDav('WebDAV Server');

  const BlindBackupDestinationKind(this.displayName);

  /// Human readable display label.
  final String displayName;
}

/// Configuration for a blind backup provider destination.
@immutable
final class BlindBackupConfig {
  /// Creates a blind backup configuration.
  const BlindBackupConfig({
    required this.destinationKind,
    required this.accountIdentifier,
    required this.remoteDirectoryPath,
    this.autoSyncEnabled = false,
    this.lastSyncAt,
  });

  /// Target blind backup provider type.
  final BlindBackupDestinationKind destinationKind;

  /// Account or server label.
  final String accountIdentifier;

  /// Remote directory location path.
  final String remoteDirectoryPath;

  /// Whether automatic periodic sync is active.
  final bool autoSyncEnabled;

  /// Last backup timestamp.
  final DateTime? lastSyncAt;
}

/// Blind backup sync status.
@immutable
final class BlindBackupSyncStatus {
  /// Creates a blind backup sync status.
  const BlindBackupSyncStatus({
    required this.isSyncing,
    required this.statusMessage,
    this.syncedArchiveHashHex,
  });

  /// Whether transfer is currently active.
  final bool isSyncing;

  /// Human readable status message.
  final String statusMessage;

  /// SHA-256 hash of last confirmed synced archive.
  final String? syncedArchiveHashHex;
}
