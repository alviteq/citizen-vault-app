/// Streaming authenticated object storage for Citizen Vault.
library;

export 'src/cancellation/cancellation_token.dart';
export 'src/errors/object_store_failure.dart';
export 'src/format/object_format_v1.dart';
export 'src/model/object_id.dart';
export 'src/model/object_store_models.dart';
export 'src/model/vault_file_root_key.dart';
export 'src/retention/object_retention_repository.dart';
export 'src/store/encrypted_object_store.dart';
export 'src/store/file_encrypted_object_store.dart';

/// Package metadata for the encrypted object-store boundary.
abstract final class VaultObjectsPackage {
  /// Public API version introduced by the object-store milestone.
  static const String apiVersion = '0.7.0';
}
