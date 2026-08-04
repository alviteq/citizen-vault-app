/// Versioned cryptographic contracts and implementations for Citizen Vault.
library;

export 'src/algorithms/vault_cryptography.dart';
export 'src/envelope/device_envelope.dart';
export 'src/envelope/recovery_envelope.dart';
export 'src/errors/crypto_failure.dart';
export 'src/kdf/kdf_parameters.dart';
export 'src/key_context/vault_subkey_context.dart';
export 'src/key_hierarchy/vault_key_hierarchy.dart';
export 'src/policy/import_policy.dart';
export 'src/policy/recovery_credential_policy.dart';
export 'src/random/cryptographic_random.dart';
export 'src/secret/secret_bytes.dart';
export 'src/serialization/recovery_envelope_codec.dart';

/// Package metadata for the cryptographic boundary.
abstract final class VaultCryptoPackage {
  /// Version of the public Dart API introduced by the cryptographic spike.
  static const String apiVersion = '0.2.0';
}
