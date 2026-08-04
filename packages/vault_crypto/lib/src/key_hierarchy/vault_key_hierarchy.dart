import 'dart:convert';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:vault_crypto/src/key_context/vault_subkey_context.dart';
import 'package:vault_crypto/src/secret/secret_bytes.dart';

/// Derives compartmentalized 256-bit keys from the Master Vault Key.
final class VaultKeyHierarchy {
  /// Creates a hierarchy using HKDF-HMAC-SHA-256.
  VaultKeyHierarchy()
    : _hkdf = crypto.Hkdf(hmac: crypto.Hmac.sha256(), outputLength: 32);

  final crypto.Hkdf _hkdf;

  /// Derives one fixed-context subkey.
  Future<SecretBytes> derive({
    required SecretBytes masterKey,
    required List<int> vaultSalt,
    required VaultSubkeyContext context,
  }) async {
    if (masterKey.length != 32) {
      throw ArgumentError.value(masterKey.length, 'masterKey', 'must be 32');
    }
    if (vaultSalt.length < 32) {
      throw ArgumentError.value(vaultSalt.length, 'vaultSalt', 'minimum is 32');
    }
    final masterBytes = masterKey.extractBytes();
    try {
      final key = await _hkdf.deriveKey(
        secretKey: crypto.SecretKey(masterBytes),
        nonce: vaultSalt,
        info: utf8.encode(context.label),
      );
      return SecretBytes(await key.extractBytes());
    } finally {
      masterBytes.fillRange(0, masterBytes.length, 0);
    }
  }

  /// Derives all reviewed subkeys.
  Future<VaultDerivedKeys> deriveAll({
    required SecretBytes masterKey,
    required List<int> vaultSalt,
  }) async {
    final values = <VaultSubkeyContext, SecretBytes>{};
    try {
      for (final context in VaultSubkeyContext.values) {
        values[context] = await derive(
          masterKey: masterKey,
          vaultSalt: vaultSalt,
          context: context,
        );
      }
      return VaultDerivedKeys._(values);
    } on Object {
      for (final value in values.values) {
        value.destroy();
      }
      rethrow;
    }
  }
}

/// Owned collection of derived vault subkeys.
final class VaultDerivedKeys {
  VaultDerivedKeys._(Map<VaultSubkeyContext, SecretBytes> values)
    : _values = Map.unmodifiable(values);

  final Map<VaultSubkeyContext, SecretBytes> _values;

  /// Returns the requested owned key while this collection is alive.
  SecretBytes operator [](VaultSubkeyContext context) {
    final value = _values[context];
    if (value == null || value.isDestroyed) {
      throw StateError('Derived key is unavailable');
    }
    return value;
  }

  /// Best-effort overwrites every derived key.
  void destroy() {
    for (final value in _values.values) {
      value.destroy();
    }
  }
}
