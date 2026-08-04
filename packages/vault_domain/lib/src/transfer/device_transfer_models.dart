import 'package:meta/meta.dart';

/// Transport mechanism for encrypted device-to-device transfers.
enum TransferTransportKind {
  /// Local Area Wi-Fi network transfer.
  localNetwork('Local Wi-Fi Network'),

  /// Wi-Fi Direct Peer-to-Peer transport.
  wiFiDirect('Wi-Fi Direct P2P'),

  /// Physical USB storage archive export.
  usbStorage('USB Physical Storage');

  const TransferTransportKind(this.displayName);

  /// Transport display label.
  final String displayName;
}

/// Ephemeral pairing session for device transfer handshake.
@immutable
final class TransferPairingSession {
  /// Creates a pairing session.
  const TransferPairingSession({
    required this.sessionId,
    required this.pairingPin,
    required this.senderDeviceId,
    required this.expiresAt,
  });

  /// Unique session ID.
  final String sessionId;

  /// Ephemeral 6-digit pairing PIN code.
  final String pairingPin;

  /// Sender device name/identifier.
  final String senderDeviceId;

  /// Expiration timestamp.
  final DateTime expiresAt;
}

/// Encrypted payload metadata for device-to-device transport.
@immutable
final class TransferPayloadPackage {
  /// Creates a payload package metadata wrapper.
  const TransferPayloadPackage({
    required this.packageId,
    required this.totalChunks,
    required this.totalSizeBytes,
    required this.payloadHashHex,
  });

  /// Unique package identifier.
  final String packageId;

  /// Total transfer chunks.
  final int totalChunks;

  /// Total size in bytes.
  final int totalSizeBytes;

  /// SHA-256 integrity hash hex string.
  final String payloadHashHex;
}

/// Device-to-device transfer state.
@immutable
final class TransferProgress {
  /// Creates transfer progress state.
  const TransferProgress({
    required this.transferredChunks,
    required this.totalChunks,
    required this.transferredBytes,
    required this.totalBytes,
    required this.status,
    this.errorMessage,
  });

  /// Number of completed chunks.
  final int transferredChunks;

  /// Total chunks in session.
  final int totalChunks;

  /// Transferred byte count.
  final int transferredBytes;

  /// Total payload byte count.
  final int totalBytes;

  /// Status description string.
  final String status;

  /// Optional error message.
  final String? errorMessage;

  /// Calculated completion percentage (0.0 to 1.0).
  double get fraction =>
      totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
}
