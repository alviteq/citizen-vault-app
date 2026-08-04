/// Encrypted SQLCipher database infrastructure for Citizen Vault.
library;

export 'src/attention/sqlcipher_attention_repository.dart';
export 'src/database/citizen_vault_database.dart';
export 'src/database/encrypted_database_opener.dart';
export 'src/errors/database_failure.dart';
export 'src/graph/sqlcipher_life_graph_repository.dart';
export 'src/integrity/database_integrity_service.dart';
export 'src/library/sqlcipher_document_library.dart';
export 'src/packs/sqlcipher_smart_pack_repository.dart';
export 'src/snapshot/database_snapshot_service.dart';
export 'src/snapshot/database_write_barrier.dart';

/// Package metadata for the encrypted database boundary.
abstract final class VaultDatabasePackage {
  /// Public API version.
  static const String apiVersion = '1.0.0';
}
