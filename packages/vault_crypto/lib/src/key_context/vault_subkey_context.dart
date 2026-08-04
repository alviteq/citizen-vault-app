/// Fixed HKDF contexts. Arbitrary production contexts cannot be constructed.
enum VaultSubkeyContext {
  /// SQLCipher database key.
  database('citizen-vault/database/v1'),

  /// Root used to derive independent file keys.
  fileRoot('citizen-vault/file-root/v1'),

  /// Portable backup encryption key.
  backup('citizen-vault/backup/v1'),

  /// Protected metadata key.
  metadata('citizen-vault/metadata/v1'),

  /// Audit-chain key.
  audit('citizen-vault/audit/v1');

  const VaultSubkeyContext(this.label);

  /// Reviewed UTF-8 HKDF info label.
  final String label;
}
