import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:vault_backup/src/errors/backup_failure.dart';
import 'package:vault_backup/src/format/backup_codecs.dart';
import 'package:vault_backup/src/model/backup_models.dart';
import 'package:vault_crypto/vault_crypto.dart';

/// Owned secrets recovered from a portable backup envelope.
final class UnlockedBackupSecrets {
  /// Creates the owned secrets.
  UnlockedBackupSecrets({
    required this.masterKey,
    required List<int> vaultHkdfSalt,
  }) : _vaultHkdfSalt = Uint8List.fromList(vaultHkdfSalt);

  /// Recovered Master Vault Key.
  final SecretBytes masterKey;
  final Uint8List _vaultHkdfSalt;

  /// Defensive copy of the stable per-vault HKDF salt.
  Uint8List get vaultHkdfSalt => Uint8List.fromList(_vaultHkdfSalt);

  /// Destroys the Master Vault Key and overwrites the owned salt buffer.
  void destroy() {
    masterKey.destroy();
    _vaultHkdfSalt.fillRange(0, _vaultHkdfSalt.length, 0);
  }
}

/// Backup-specific envelope and manifest cryptography.
final class BackupCryptography {
  /// Creates the service with injected OS randomness.
  BackupCryptography({required CryptographicRandom random})
    : _vault = VaultCryptography(random: random),
      _random = random,
      _aes = crypto.AesGcm.with256bits(),
      _sha = crypto.Sha256().toSync();

  final VaultCryptography _vault;
  final CryptographicRandom _random;
  final crypto.AesGcm _aes;
  final crypto.HashAlgorithm _sha;

  /// Wraps the Master Vault Key and vault HKDF salt using header bytes as AAD.
  Future<BackupRecoveryEnvelope> createRecoveryEnvelope({
    required String recoveryPassphrase,
    required BackupPublicHeader header,
    required List<int> canonicalHeaderBytes,
    required SecretBytes masterKey,
    required List<int> vaultHkdfSalt,
  }) async {
    if (masterKey.length != 32 || vaultHkdfSalt.length != 32) {
      throw const InvalidBackupFormatFailure('recovery_plaintext_shape');
    }
    final wrappingKey = await _vault.deriveRecoveryWrappingKey(
      recoveryPassphrase: recoveryPassphrase,
      salt: header.kdfSalt,
      parameters: header.kdfParameters,
    );
    final wrappingBytes = wrappingKey.extractBytes();
    final masterBytes = masterKey.extractBytes();
    final nonce = await _randomExact(12);
    try {
      final box = await _aes.encrypt(
        <int>[...masterBytes, ...vaultHkdfSalt],
        secretKey: crypto.SecretKey(wrappingBytes),
        nonce: nonce,
        aad: canonicalHeaderBytes,
      );
      return BackupRecoveryEnvelope(
        nonce: nonce,
        ciphertext: box.cipherText,
        authenticationTag: box.mac.bytes,
      );
    } finally {
      wrappingKey.destroy();
      wrappingBytes.fillRange(0, wrappingBytes.length, 0);
      masterBytes.fillRange(0, masterBytes.length, 0);
    }
  }

  /// Authenticates and recovers the Master Vault Key and vault HKDF salt.
  Future<UnlockedBackupSecrets> unlockRecoveryEnvelope({
    required String recoveryPassphrase,
    required BackupPublicHeader header,
    required List<int> canonicalHeaderBytes,
    required BackupRecoveryEnvelope envelope,
  }) async {
    final wrappingKey = await _vault.deriveRecoveryWrappingKey(
      recoveryPassphrase: recoveryPassphrase,
      salt: header.kdfSalt,
      parameters: header.kdfParameters,
    );
    final wrappingBytes = wrappingKey.extractBytes();
    try {
      final plaintext = await _aes.decrypt(
        crypto.SecretBox(
          envelope.ciphertext,
          nonce: envelope.nonce,
          mac: crypto.Mac(envelope.authenticationTag),
        ),
        secretKey: crypto.SecretKey(wrappingBytes),
        aad: canonicalHeaderBytes,
      );
      if (plaintext.length != 64) {
        throw const BackupAuthenticationFailure();
      }
      return UnlockedBackupSecrets(
        masterKey: SecretBytes(plaintext.sublist(0, 32)),
        vaultHkdfSalt: plaintext.sublist(32),
      );
    } on crypto.SecretBoxAuthenticationError catch (error) {
      throw BackupAuthenticationFailure(cause: error);
    } finally {
      wrappingKey.destroy();
      wrappingBytes.fillRange(0, wrappingBytes.length, 0);
    }
  }

  /// Encrypts canonical manifest bytes with the derived Backup Key.
  Future<Uint8List> encryptManifest({
    required List<int> canonicalManifestBytes,
    required SecretBytes backupKey,
    required List<int> canonicalHeaderBytes,
    required List<int> recoveryEnvelopeBytes,
  }) async {
    final key = backupKey.extractBytes();
    final nonce = await _randomExact(12);
    try {
      final box = await _aes.encrypt(
        canonicalManifestBytes,
        secretKey: crypto.SecretKey(key),
        nonce: nonce,
        aad: await _manifestAad(
          canonicalHeaderBytes,
          recoveryEnvelopeBytes,
        ),
      );
      return EncryptedManifestCodec.encode(
        nonce: nonce,
        ciphertext: box.cipherText,
        tag: box.mac.bytes,
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// Authenticates and decrypts canonical manifest bytes.
  Future<Uint8List> decryptManifest({
    required List<int> encryptedManifestBytes,
    required SecretBytes backupKey,
    required List<int> canonicalHeaderBytes,
    required List<int> recoveryEnvelopeBytes,
    required int maximumManifestBytes,
  }) async {
    final envelope = EncryptedManifestCodec.decode(
      encryptedManifestBytes,
      maximumCiphertextBytes: maximumManifestBytes,
    );
    final key = backupKey.extractBytes();
    try {
      return Uint8List.fromList(
        await _aes.decrypt(
          crypto.SecretBox(
            envelope.ciphertext,
            nonce: envelope.nonce,
            mac: crypto.Mac(envelope.tag),
          ),
          secretKey: crypto.SecretKey(key),
          aad: await _manifestAad(
            canonicalHeaderBytes,
            recoveryEnvelopeBytes,
          ),
        ),
      );
    } on crypto.SecretBoxAuthenticationError catch (error) {
      throw BackupAuthenticationFailure(cause: error);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<Uint8List> _manifestAad(
    List<int> headerBytes,
    List<int> envelopeBytes,
  ) async {
    final headerDigest = await _sha.hash(headerBytes);
    final envelopeDigest = await _sha.hash(envelopeBytes);
    return Uint8List.fromList(<int>[
      ...utf8.encode('citizen-vault/manifest-aad/v1'),
      ...headerDigest.bytes,
      ...envelopeDigest.bytes,
    ]);
  }

  Future<Uint8List> _randomExact(int length) async {
    final bytes = await _random.secureBytes(length);
    if (bytes.length != length) {
      throw const BackupCreationFailure();
    }
    return Uint8List.fromList(bytes);
  }
}
