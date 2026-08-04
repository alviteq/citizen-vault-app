import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:vault_crypto/src/envelope/recovery_envelope.dart';
import 'package:vault_crypto/src/errors/crypto_failure.dart';
import 'package:vault_crypto/src/kdf/kdf_parameters.dart';
import 'package:vault_crypto/src/policy/import_policy.dart';
import 'package:vault_crypto/src/policy/recovery_credential_policy.dart';
import 'package:vault_crypto/src/random/cryptographic_random.dart';
import 'package:vault_crypto/src/secret/secret_bytes.dart';
import 'package:vault_crypto/src/serialization/recovery_envelope_codec.dart';

/// Versioned cryptographic operations for recovery-key provisioning.
final class VaultCryptography {
  /// Creates the service with an injected production or deterministic RNG.
  VaultCryptography({
    required this.random,
    VaultImportPolicy importPolicy = const VaultImportPolicy(),
  }) : _policy = importPolicy,
       _aesGcm = crypto.AesGcm.with256bits();

  /// Random source used for all generated key material and nonces.
  final CryptographicRandom random;
  final VaultImportPolicy _policy;
  final crypto.AesGcm _aesGcm;

  /// Creates a random Master Vault Key, stable HKDF salt, and recovery
  /// envelope.
  Future<VaultKeyProvisioningResult> createVaultKeys({
    required String recoveryPassphrase,
    RecoveryKdfParameters kdfParameters =
        const RecoveryKdfParameters.productionArgon2id(),
    DateTime? createdAt,
  }) async {
    final assessment = RecoveryCredentialPolicy.assess(recoveryPassphrase);
    if (!assessment.accepted) {
      throw WeakRecoveryCredentialFailure(assessment.reason);
    }
    final masterKey = SecretBytes(await _randomExact(32));
    try {
      final vaultSalt = await _randomExact(32);
      final kdfSalt = await _randomExact(16);
      final nonce = await _randomExact(12);
      final envelope = await createRecoveryEnvelope(
        recoveryPassphrase: recoveryPassphrase,
        masterKey: masterKey,
        kdfParameters: kdfParameters,
        salt: kdfSalt,
        nonce: nonce,
        createdAt: createdAt ?? DateTime.now().toUtc(),
      );
      return VaultKeyProvisioningResult(
        masterKey: masterKey,
        vaultHkdfSalt: vaultSalt,
        recoveryEnvelope: envelope,
      );
    } on Object {
      masterKey.destroy();
      rethrow;
    }
  }

  /// Creates a deterministic recovery envelope from explicit inputs.
  ///
  /// Production callers should use [createVaultKeys]. This method exists for
  /// portable vectors, rewrapping, and audited migrations.
  Future<RecoveryEnvelope> createRecoveryEnvelope({
    required String recoveryPassphrase,
    required SecretBytes masterKey,
    required RecoveryKdfParameters kdfParameters,
    required List<int> salt,
    required List<int> nonce,
    required DateTime createdAt,
  }) async {
    final assessment = RecoveryCredentialPolicy.assess(recoveryPassphrase);
    if (!assessment.accepted) {
      throw WeakRecoveryCredentialFailure(assessment.reason);
    }
    if (masterKey.length != 32) {
      throw ArgumentError.value(masterKey.length, 'masterKey', 'must be 32');
    }
    _policy.validateKdf(kdfParameters, saltLength: salt.length);
    if (nonce.length != 12) {
      throw ArgumentError.value(nonce.length, 'nonce', 'must be 12');
    }
    final normalizedCreatedAt = DateTime.fromMillisecondsSinceEpoch(
      (createdAt.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    final baseHeader = RecoveryEnvelopeCodec.baseHeaderBytes(
      formatVersion: RecoveryEnvelope.currentFormatVersion,
      wrappingAlgorithm: KeyWrappingAlgorithm.aes256Gcm,
      kdfParameters: kdfParameters,
      salt: salt,
      nonce: nonce,
      createdAt: normalizedCreatedAt,
    );
    final digest = await sha256(baseHeader);
    final aad = RecoveryEnvelopeCodec.authenticatedHeader(
      baseHeader: baseHeader,
      headerDigest: digest,
    );
    final wrappingKey = await deriveRecoveryWrappingKey(
      recoveryPassphrase: recoveryPassphrase,
      salt: salt,
      parameters: kdfParameters,
    );
    final wrappingBytes = wrappingKey.extractBytes();
    final masterBytes = masterKey.extractBytes();
    try {
      final box = await _aesGcm.encrypt(
        masterBytes,
        secretKey: crypto.SecretKey(wrappingBytes),
        nonce: nonce,
        aad: aad,
      );
      return RecoveryEnvelope(
        formatVersion: RecoveryEnvelope.currentFormatVersion,
        wrappingAlgorithm: KeyWrappingAlgorithm.aes256Gcm,
        kdfParameters: kdfParameters,
        salt: salt,
        nonce: nonce,
        ciphertext: box.cipherText,
        authenticationTag: box.mac.bytes,
        headerDigest: digest,
        createdAt: normalizedCreatedAt,
      );
    } finally {
      wrappingKey.destroy();
      wrappingBytes.fillRange(0, wrappingBytes.length, 0);
      masterBytes.fillRange(0, masterBytes.length, 0);
    }
  }

  /// Recovers and authenticates the Master Vault Key.
  Future<SecretBytes> recoverMasterKey({
    required String recoveryPassphrase,
    required RecoveryEnvelope envelope,
  }) async {
    _policy.validateKdf(
      envelope.kdfParameters,
      saltLength: envelope.salt.length,
    );
    if (envelope.formatVersion != RecoveryEnvelope.currentFormatVersion ||
        envelope.wrappingAlgorithm != KeyWrappingAlgorithm.aes256Gcm) {
      throw const UnsupportedRecoveryEnvelopeFailure('algorithm');
    }
    final baseHeader = RecoveryEnvelopeCodec.baseHeaderBytes(
      formatVersion: envelope.formatVersion,
      wrappingAlgorithm: envelope.wrappingAlgorithm,
      kdfParameters: envelope.kdfParameters,
      salt: envelope.salt,
      nonce: envelope.nonce,
      createdAt: envelope.createdAt,
    );
    final digest = await sha256(baseHeader);
    if (!constantTimeEquals(digest, envelope.headerDigest)) {
      throw const RecoveryEnvelopeAuthenticationFailure();
    }
    final aad = RecoveryEnvelopeCodec.authenticatedHeader(
      baseHeader: baseHeader,
      headerDigest: digest,
    );
    final wrappingKey = await deriveRecoveryWrappingKey(
      recoveryPassphrase: recoveryPassphrase,
      salt: envelope.salt,
      parameters: envelope.kdfParameters,
    );
    final wrappingBytes = wrappingKey.extractBytes();
    try {
      final plaintext = await _aesGcm.decrypt(
        crypto.SecretBox(
          envelope.ciphertext,
          nonce: envelope.nonce,
          mac: crypto.Mac(envelope.authenticationTag),
        ),
        secretKey: crypto.SecretKey(wrappingBytes),
        aad: aad,
      );
      if (plaintext.length != 32) {
        throw const RecoveryEnvelopeAuthenticationFailure();
      }
      return SecretBytes(plaintext);
    } on crypto.SecretBoxAuthenticationError catch (error) {
      throw RecoveryEnvelopeAuthenticationFailure(cause: error);
    } finally {
      wrappingKey.destroy();
      wrappingBytes.fillRange(0, wrappingBytes.length, 0);
    }
  }

  /// Derives the recovery wrapping key using reviewed, validated parameters.
  Future<SecretBytes> deriveRecoveryWrappingKey({
    required String recoveryPassphrase,
    required List<int> salt,
    required RecoveryKdfParameters parameters,
  }) async {
    _policy.validateKdf(parameters, saltLength: salt.length);
    if (recoveryPassphrase.isEmpty) {
      throw ArgumentError.value('', 'recoveryPassphrase', 'must not be empty');
    }
    final crypto.SecretKey key;
    switch (parameters.algorithm) {
      case RecoveryKdfAlgorithm.argon2id:
        key = await crypto.Argon2id(
          parallelism: parameters.parallelism,
          memory: parameters.memoryKiB,
          iterations: parameters.iterations,
          hashLength: parameters.outputLength,
        ).deriveKeyFromPassword(password: recoveryPassphrase, nonce: salt);
      case RecoveryKdfAlgorithm.pbkdf2HmacSha256:
        key = await crypto.Pbkdf2.hmacSha256(
          iterations: parameters.iterations,
          bits: parameters.outputLength * 8,
        ).deriveKeyFromPassword(password: recoveryPassphrase, nonce: salt);
    }
    return SecretBytes(await key.extractBytes());
  }

  /// SHA-256 digest helper used by portable formats and vectors.
  Future<Uint8List> sha256(List<int> bytes) async {
    final hash = await crypto.Sha256().hash(bytes);
    return Uint8List.fromList(hash.bytes);
  }

  /// Compares equal-length byte strings without content-dependent early exit.
  static bool constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < left.length; index += 1) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  Future<Uint8List> _randomExact(int length) async {
    try {
      final bytes = await random.secureBytes(length);
      if (bytes.length != length) {
        throw const EntropyUnavailableFailure();
      }
      return Uint8List.fromList(bytes);
    } on VaultCryptoFailure {
      rethrow;
    } on Object catch (error) {
      throw EntropyUnavailableFailure(cause: error);
    }
  }
}

/// Owned result of recovery provisioning.
final class VaultKeyProvisioningResult {
  /// Creates the result.
  VaultKeyProvisioningResult({
    required this.masterKey,
    required List<int> vaultHkdfSalt,
    required this.recoveryEnvelope,
  }) : _vaultHkdfSalt = Uint8List.fromList(vaultHkdfSalt);

  /// Random 256-bit Master Vault Key.
  final SecretBytes masterKey;

  final Uint8List _vaultHkdfSalt;

  /// Portable recovery envelope.
  final RecoveryEnvelope recoveryEnvelope;

  /// Defensive copy of the stable non-secret vault HKDF salt.
  Uint8List get vaultHkdfSalt => Uint8List.fromList(_vaultHkdfSalt);
}
