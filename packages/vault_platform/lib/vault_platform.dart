/// Native security adapters for Citizen Vault.
library;

export 'src/platform_cryptographic_random.dart';
export 'src/platform_device_envelope_store.dart';

/// Package metadata for native security adapters.
abstract final class VaultPlatformPackage {
  /// Public Dart API version.
  static const String apiVersion = '0.2.0';
}
