// Named public dependencies intentionally initialize private owned fields.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:citizen_vault_app/src/backup/backup_archive_transfer.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/ingestion/pdf_aware_thumbnail_generator.dart';
import 'package:citizen_vault_app/src/ocr/ml_kit_latin_ocr_engine.dart';
import 'package:citizen_vault_app/src/reminders/flutter_local_notification_projection.dart';
import 'package:citizen_vault_app/src/vault/biometric_authenticator.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vault_backup/vault_backup.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_ingestion/vault_ingestion.dart';
import 'package:vault_notifications/vault_notifications.dart';
import 'package:vault_objects/vault_objects.dart';
import 'package:vault_ocr/vault_ocr.dart' as ocr;
import 'package:vault_platform/vault_platform.dart';

/// An unlocked vault owned by the application shell.
abstract interface class UnlockedVaultHandle {
  /// Controller backed by this handle's encrypted database and object store.
  IngestionUiController get ingestionController;

  /// Whether a vault operation must not be interrupted by background locking.
  bool get isBusy;

  /// Creates and verifies a temporary portable backup.
  Future<PendingVaultBackup> createBackup({required String recoveryPassphrase});

  /// Closes the database and destroys in-memory key material.
  Future<void> close();
}

/// Verified temporary backup awaiting user-controlled export.
final class PendingVaultBackup {
  /// Creates an owned temporary archive.
  PendingVaultBackup({
    required this.archive,
    required this.archiveBytes,
    required this.objectCount,
  });

  /// App-private encrypted archive.
  final File archive;

  /// Archive length.
  final int archiveBytes;

  /// Number of encrypted objects included.
  final int objectCount;

  /// Removes the temporary app-private copy after export or cancellation.
  void dispose() {
    try {
      if (archive.existsSync()) archive.deleteSync();
    } on Object {
      // The archive remains encrypted and startup cleanup retries deletion.
    }
  }
}

/// Creates and unlocks the single local vault.
abstract interface class VaultLifecycle {
  /// Whether protected vault metadata is present on this installation.
  Future<bool> exists();

  /// Atomically creates a new vault protected by [recoveryPassphrase].
  Future<UnlockedVaultHandle> create({required String recoveryPassphrase});

  /// Authenticates [recoveryPassphrase] and opens the existing vault.
  Future<UnlockedVaultHandle> unlock({required String recoveryPassphrase});

  /// Whether a valid device envelope is configured.
  Future<bool> biometricEnabled();

  /// Whether an enrolled biometric is available on this device.
  Future<bool> biometricAvailable();

  /// Prompts locally and unlocks through the device envelope.
  Future<UnlockedVaultHandle> unlockWithBiometrics();

  /// Provisions biometric unlock after authenticating the recovery credential.
  Future<void> enableBiometrics({required String recoveryPassphrase});

  /// Deletes the device key while preserving recovery access.
  Future<void> disableBiometrics();

  /// Restores a verified portable archive into a clean installation.
  Future<UnlockedVaultHandle> restoreBackup({
    required File archive,
    required String recoveryPassphrase,
  });
}

/// Failure safe for presentation without exposing sensitive details.
final class VaultLifecycleFailure implements Exception {
  /// Creates a stable lifecycle failure.
  const VaultLifecycleFailure(this.code, {this.cause});

  /// Stable non-sensitive failure identifier.
  final String code;

  /// Internal diagnostic cause. Never display directly.
  final Object? cause;
}

/// Production app-private vault composition.
final class LocalVaultLifecycle implements VaultLifecycle {
  /// Creates a lifecycle rooted in [rootDirectory].
  LocalVaultLifecycle({
    required Directory rootDirectory,
    CryptographicRandom random = const PlatformCryptographicRandom(),
    DeviceEnvelopeStore deviceEnvelopes = const PlatformDeviceEnvelopeStore(),
    BiometricAuthenticator? biometricAuthenticator,
    BackupArchiveTransfer backupTransfer =
        const PlatformBackupArchiveTransfer(),
    RestoreStoragePolicy? restoreStoragePolicy,
    ocr.OcrEngine ocrEngine = const MlKitLatinOcrEngine(),
    List<String> Function()? preferredOcrLanguages,
    RecoveryKdfParameters kdfParameters =
        const RecoveryKdfParameters.productionArgon2id(),
  }) : _root = Directory('${rootDirectory.path}/citizen_vault'),
       _random = random,
       _deviceEnvelopes = deviceEnvelopes,
       _biometrics = biometricAuthenticator ?? PlatformBiometricAuthenticator(),
       _restoreStorage =
           restoreStoragePolicy ??
           _PlatformRestoreStoragePolicy(backupTransfer),
       _ocrEngine = ocrEngine,
       _preferredOcrLanguages =
           preferredOcrLanguages ??
           (() => <String>[
             OfflineMultilingualEngine().preferences.ocrLanguage,
           ]),
       _kdfParameters = kdfParameters;

  /// Creates a lifecycle using the platform's private application-support path.
  static Future<LocalVaultLifecycle> applicationSupport() async =>
      LocalVaultLifecycle(
        rootDirectory: await getApplicationSupportDirectory(),
      );

  final Directory _root;
  final CryptographicRandom _random;
  final DeviceEnvelopeStore _deviceEnvelopes;
  final BiometricAuthenticator _biometrics;
  final RestoreStoragePolicy _restoreStorage;
  final ocr.OcrEngine _ocrEngine;
  final List<String> Function() _preferredOcrLanguages;
  final RecoveryKdfParameters _kdfParameters;

  static const String _deviceKeyAlias = 'citizen_vault.master.v1';

  File get _metadataFile => File('${_root.path}/vault-metadata-v1.json');
  File get _databaseFile => File('${_root.path}/vault.db');

  @override
  Future<bool> exists() async => _metadataFile.existsSync();

  @override
  Future<UnlockedVaultHandle> create({
    required String recoveryPassphrase,
  }) async {
    if (await exists()) {
      throw const VaultLifecycleFailure('vault_already_exists');
    }
    final cryptography = VaultCryptography(random: _random);
    VaultKeyProvisioningResult? provisioning;
    _LocalUnlockedVaultHandle? handle;
    try {
      provisioning = await cryptography.createVaultKeys(
        recoveryPassphrase: recoveryPassphrase,
        kdfParameters: _kdfParameters,
      );
      handle = await _open(
        masterKey: provisioning.masterKey,
        vaultSalt: provisioning.vaultHkdfSalt,
      );
      final metadata = _VaultMetadata(
        vaultSalt: provisioning.vaultHkdfSalt,
        recoveryEnvelope: RecoveryEnvelopeCodec.encode(
          provisioning.recoveryEnvelope,
        ),
        createdAt: provisioning.recoveryEnvelope.createdAt,
      );
      await _writeMetadata(metadata);
      return handle;
    } on VaultLifecycleFailure {
      await handle?.close();
      await _removeIncompleteCreation();
      rethrow;
    } on WeakRecoveryCredentialFailure catch (error) {
      await handle?.close();
      throw VaultLifecycleFailure('weak_recovery_credential', cause: error);
    } on Object catch (error, stack) {
      debugPrint('Vault creation error: $error\n$stack');
      await handle?.close();
      await _removeIncompleteCreation();
      throw VaultLifecycleFailure('vault_creation_failed', cause: error);
    } finally {
      provisioning?.masterKey.destroy();
    }
  }

  @override
  Future<UnlockedVaultHandle> unlock({
    required String recoveryPassphrase,
  }) async {
    try {
      final metadata = await _readMetadata();
      final envelope = RecoveryEnvelopeCodec.decode(metadata.recoveryEnvelope);
      if (envelope.createdAt != metadata.createdAt) {
        throw const VaultLifecycleFailure('vault_metadata_invalid');
      }
      final masterKey = await VaultCryptography(random: _random)
          .recoverMasterKey(
            recoveryPassphrase: recoveryPassphrase,
            envelope: envelope,
          );
      try {
        return await _open(masterKey: masterKey, vaultSalt: metadata.vaultSalt);
      } finally {
        masterKey.destroy();
      }
    } on RecoveryEnvelopeAuthenticationFailure catch (error) {
      throw VaultLifecycleFailure(
        'incorrect_recovery_credential',
        cause: error,
      );
    } on VaultLifecycleFailure {
      rethrow;
    } on Object catch (error) {
      throw VaultLifecycleFailure('vault_unlock_failed', cause: error);
    }
  }

  @override
  Future<bool> biometricEnabled() async {
    if (!await exists()) return false;
    return (await _readMetadata()).deviceEnvelope != null;
  }

  @override
  Future<bool> biometricAvailable() async {
    try {
      return await _biometrics.isAvailable();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> enableBiometrics({required String recoveryPassphrase}) async {
    final metadata = await _readMetadata();
    if (metadata.deviceEnvelope != null) return;
    if (!await biometricAvailable()) {
      throw const VaultLifecycleFailure('biometric_unavailable');
    }
    SecretBytes? masterKey;
    DeviceEnvelope? deviceEnvelope;
    try {
      masterKey = await VaultCryptography(random: _random).recoverMasterKey(
        recoveryPassphrase: recoveryPassphrase,
        envelope: RecoveryEnvelopeCodec.decode(metadata.recoveryEnvelope),
      );
      if (!await _biometrics.authenticate()) {
        throw const VaultLifecycleFailure('biometric_cancelled');
      }
      try {
        deviceEnvelope = await _wrapDeviceKey(masterKey);
      } on DeviceAuthenticationRequiredFailure {
        if (!await _biometrics.authenticate()) {
          throw const VaultLifecycleFailure('biometric_cancelled');
        }
        deviceEnvelope = await _wrapDeviceKey(masterKey);
      }
      await _writeMetadata(metadata.withDeviceEnvelope(deviceEnvelope));
    } on RecoveryEnvelopeAuthenticationFailure catch (error) {
      throw VaultLifecycleFailure(
        'incorrect_recovery_credential',
        cause: error,
      );
    } on VaultLifecycleFailure {
      if (deviceEnvelope == null) {
        await _deleteDeviceKeyBestEffort();
      }
      rethrow;
    } on Object catch (error) {
      await _deleteDeviceKeyBestEffort();
      throw VaultLifecycleFailure('biometric_enable_failed', cause: error);
    } finally {
      masterKey?.destroy();
    }
  }

  @override
  Future<void> disableBiometrics() async {
    final metadata = await _readMetadata();
    final deviceEnvelope = metadata.deviceEnvelope;
    if (deviceEnvelope == null) return;
    try {
      await _deviceEnvelopes.delete(deviceEnvelope.keyAlias);
      await _writeMetadata(metadata.withDeviceEnvelope(null));
    } on Object catch (error) {
      throw VaultLifecycleFailure('biometric_disable_failed', cause: error);
    }
  }

  @override
  Future<UnlockedVaultHandle> restoreBackup({
    required File archive,
    required String recoveryPassphrase,
  }) async {
    if (await exists()) {
      throw const VaultLifecycleFailure('vault_already_exists');
    }
    try {
      final restore = BackupRestoreService(
        archiveVerifier: VaultBackupArchiveVerifier(random: _random),
        capacityPolicy: _restoreStorage,
        provisioner: _LocalRestoredMetadataProvisioner(
          random: _random,
          kdfParameters: _kdfParameters,
        ),
        randomSource: _random,
      );
      await restore.restore(
        archive: archive,
        recoveryPassphrase: recoveryPassphrase,
        vaultsParent: _root.parent,
        activeDirectoryName: _root.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .last,
      );
      return await unlock(recoveryPassphrase: recoveryPassphrase);
    } on BackupAuthenticationFailure catch (error) {
      throw VaultLifecycleFailure(
        'incorrect_recovery_credential',
        cause: error,
      );
    } on InsufficientRestoreStorageFailure catch (error) {
      throw VaultLifecycleFailure('restore_storage_insufficient', cause: error);
    } on VaultLifecycleFailure {
      rethrow;
    } on BackupFailure catch (error) {
      throw VaultLifecycleFailure('backup_restore_failed', cause: error);
    } on Object catch (error) {
      throw VaultLifecycleFailure('backup_restore_failed', cause: error);
    }
  }

  @override
  Future<UnlockedVaultHandle> unlockWithBiometrics() async {
    final metadata = await _readMetadata();
    final deviceEnvelope = metadata.deviceEnvelope;
    if (deviceEnvelope == null) {
      throw const VaultLifecycleFailure('biometric_not_enabled');
    }
    SecretBytes? masterKey;
    try {
      if (!await _biometrics.authenticate()) {
        throw const VaultLifecycleFailure('biometric_cancelled');
      }
      masterKey = await _deviceEnvelopes.unwrap(deviceEnvelope);
      return await _open(masterKey: masterKey, vaultSalt: metadata.vaultSalt);
    } on PlatformKeyInvalidatedFailure catch (error) {
      await _deleteDeviceKeyBestEffort();
      await _writeMetadata(metadata.withDeviceEnvelope(null));
      throw VaultLifecycleFailure('biometric_invalidated', cause: error);
    } on DeviceAuthenticationRequiredFailure catch (error) {
      throw VaultLifecycleFailure('biometric_cancelled', cause: error);
    } on DeviceEnvelopeAuthenticationFailure catch (error) {
      await _deleteDeviceKeyBestEffort();
      await _writeMetadata(metadata.withDeviceEnvelope(null));
      throw VaultLifecycleFailure('biometric_invalidated', cause: error);
    } on VaultLifecycleFailure {
      rethrow;
    } on Object catch (error) {
      throw VaultLifecycleFailure('biometric_unlock_failed', cause: error);
    } finally {
      masterKey?.destroy();
    }
  }

  Future<DeviceEnvelope> _wrapDeviceKey(SecretBytes masterKey) =>
      _deviceEnvelopes.wrap(
        keyAlias: _deviceKeyAlias,
        masterKey: masterKey,
        invalidatedByBiometricEnrollment: true,
        authenticationValidity: const Duration(minutes: 5),
      );

  Future<void> _deleteDeviceKeyBestEffort() async {
    try {
      await _deviceEnvelopes.delete(_deviceKeyAlias);
    } on Object {
      // Recovery remains authoritative even if platform cleanup is unavailable.
    }
  }

  Future<_LocalUnlockedVaultHandle> _open({
    required SecretBytes masterKey,
    required List<int> vaultSalt,
  }) async {
    _cleanTemporaryBackups();
    VaultDerivedKeys? derived;
    VaultDatabaseSession? databaseSession;
    VaultFileRootKey? fileRootKey;
    try {
      derived = await VaultKeyHierarchy().deriveAll(
        masterKey: masterKey,
        vaultSalt: vaultSalt,
      );
      final databaseKey = SecretBytes(
        derived[VaultSubkeyContext.database].extractBytes(),
      );
      try {
        databaseSession = await EncryptedDatabaseOpener.open(
          file: _databaseFile,
          databaseKey: databaseKey,
        );
      } finally {
        databaseKey.destroy();
      }
      final fileRootBytes = derived[VaultSubkeyContext.fileRoot].extractBytes();
      try {
        fileRootKey = VaultFileRootKey.fromBytes(fileRootBytes, keyVersion: 1);
      } finally {
        fileRootBytes.fillRange(0, fileRootBytes.length, 0);
      }
      final objectStore = FileEncryptedObjectStore(
        rootDirectory: _root,
        random: _random,
        retentionRepository: DatabaseObjectRetentionRepository(databaseSession),
      );
      final coordinator = IngestionCoordinator(
        jobs: IngestionJobRepository(databaseSession),
        objectStore: objectStore,
        fileRootKey: fileRootKey,
        random: _random,
        thumbnails: const PdfAwareThumbnailGenerator(),
        ocrEngine: _ocrEngine,
        preferredOcrLanguages: _preferredOcrLanguages,
        decryptedAssets: ocr.DecryptedAssetLeaseManager(
          directory: Directory('${_root.path}/temporary/ocr'),
          random: _random,
          maximumBytes: const IngestionLimits().maximumFileBytes,
        ),
      );
      final reminderCoordinator = ReminderCoordinator(
        repository: ReminderRepository(
          session: databaseSession,
          random: _random,
        ),
        projection: FlutterLocalNotificationProjection(),
      );
      return _LocalUnlockedVaultHandle(
        databaseSession: databaseSession,
        fileRootKey: fileRootKey,
        createBackup: (recoveryPassphrase) => _createPortableBackup(
          databaseSession: databaseSession!,
          recoveryPassphrase: recoveryPassphrase,
        ),
        ingestionController: UnlockedIngestionUiController(
          coordinator: coordinator,
          library: SqlCipherDocumentLibrary(
            session: databaseSession,
            random: _random,
          ),
          graph: SqlCipherLifeGraphRepository(databaseSession, _random),
          reminders: reminderCoordinator,
          vaultRoot: _root,
        ),
      );
    } on Object {
      fileRootKey?.destroy();
      await databaseSession?.close();
      rethrow;
    } finally {
      derived?.destroy();
    }
  }

  Future<PendingVaultBackup> _createPortableBackup({
    required VaultDatabaseSession databaseSession,
    required String recoveryPassphrase,
  }) async {
    final metadata = await _readMetadata();
    SecretBytes? masterKey;
    Uint8List? generationRandom;
    try {
      masterKey = await VaultCryptography(random: _random).recoverMasterKey(
        recoveryPassphrase: recoveryPassphrase,
        envelope: RecoveryEnvelopeCodec.decode(metadata.recoveryEnvelope),
      );
      generationRandom = await _random.secureBytes(12);
      if (generationRandom.length != 12) {
        throw const EntropyUnavailableFailure();
      }
      final generationId = 'backup_${_hex(generationRandom)}';
      final vaultDigest = await VaultCryptography(
        random: _random,
      ).sha256(metadata.vaultSalt);
      final vaultId = 'vault_${_hex(vaultDigest.take(16))}';
      final backupDirectory = Directory('${_root.path}/temporary/backups')
        ..createSync(recursive: true);
      final created = DateTime.now().toUtc();
      final timestamp =
          '${created.year.toString().padLeft(4, '0')}'
          '${created.month.toString().padLeft(2, '0')}'
          '${created.day.toString().padLeft(2, '0')}-'
          '${created.hour.toString().padLeft(2, '0')}'
          '${created.minute.toString().padLeft(2, '0')}'
          '${created.second.toString().padLeft(2, '0')}';
      final output = File(
        '${backupDirectory.path}/ownkeep-$timestamp-$generationId.cvault',
      );
      final result =
          await VaultBackupService(
            session: databaseSession,
            snapshots: SqlCipherDatabaseSnapshotService(databaseSession),
            objectRootDirectory: _root,
            random: _random,
          ).create(
            VaultBackupRequest(
              generationId: BackupGenerationId(generationId),
              vaultId: vaultId,
              outputFile: output,
              workingDirectory: Directory('${backupDirectory.path}/working'),
              masterKey: masterKey,
              vaultHkdfSalt: metadata.vaultSalt,
              recoveryPassphrase: recoveryPassphrase,
              kdfParameters: _kdfParameters,
            ),
          );
      return PendingVaultBackup(
        archive: result.archive,
        archiveBytes: result.archiveBytes,
        objectCount: result.objectCount,
      );
    } on RecoveryEnvelopeAuthenticationFailure catch (error) {
      throw VaultLifecycleFailure(
        'incorrect_recovery_credential',
        cause: error,
      );
    } on VaultLifecycleFailure {
      rethrow;
    } on BackupFailure catch (error) {
      throw VaultLifecycleFailure('backup_creation_failed', cause: error);
    } on Object catch (error) {
      throw VaultLifecycleFailure('backup_creation_failed', cause: error);
    } finally {
      generationRandom?.fillRange(0, generationRandom.length, 0);
      masterKey?.destroy();
    }
  }

  void _cleanTemporaryBackups() {
    final directory = Directory('${_root.path}/temporary/backups');
    if (!directory.existsSync()) return;
    try {
      directory.deleteSync(recursive: true);
    } on Object {
      // Backup creation uses collision-resistant names and still fails closed.
    }
  }

  Future<void> _writeMetadata(_VaultMetadata metadata) async {
    _root.createSync(recursive: true);
    final temporary = File('${_metadataFile.path}.partial');
    final encoded = utf8.encode(jsonEncode(metadata.toJson()));
    RandomAccessFile? writer;
    try {
      final output = temporary.openSync(mode: FileMode.write);
      writer = output;
      output
        ..writeFromSync(encoded)
        ..flushSync()
        ..closeSync();
      writer = null;
      temporary.renameSync(_metadataFile.path);
    } on Object catch (error) {
      writer?.closeSync();
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
      throw VaultLifecycleFailure('metadata_write_failed', cause: error);
    } finally {
      encoded.fillRange(0, encoded.length, 0);
    }
  }

  Future<_VaultMetadata> _readMetadata() async {
    if (!_metadataFile.existsSync()) {
      throw const VaultLifecycleFailure('vault_not_found');
    }
    try {
      final bytes = _metadataFile.readAsBytesSync();
      if (bytes.length > _VaultMetadata.maximumEncodedBytes) {
        throw const FormatException('metadata is too large');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('metadata root');
      }
      return _VaultMetadata.fromJson(decoded);
    } on VaultLifecycleFailure {
      rethrow;
    } on Object catch (error) {
      throw VaultLifecycleFailure('vault_metadata_invalid', cause: error);
    }
  }

  Future<void> _removeIncompleteCreation() async {
    if (_metadataFile.existsSync()) return;
    if (_databaseFile.existsSync()) {
      _databaseFile.deleteSync();
    }
    for (final suffix in const <String>['-wal', '-shm']) {
      final sidecar = File('${_databaseFile.path}$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }
  }
}

final class _LocalUnlockedVaultHandle implements UnlockedVaultHandle {
  _LocalUnlockedVaultHandle({
    required this._databaseSession,
    required this._fileRootKey,
    required Future<PendingVaultBackup> Function(String recoveryPassphrase)
    createBackup,
    required this.ingestionController,
  }) : _createBackup = createBackup;

  final VaultDatabaseSession _databaseSession;
  final VaultFileRootKey _fileRootKey;
  final Future<PendingVaultBackup> Function(String recoveryPassphrase)
  _createBackup;

  @override
  final IngestionUiController ingestionController;

  var _closed = false;
  var _backupBusy = false;

  @override
  bool get isBusy => _backupBusy || ingestionController.isBusy;

  @override
  Future<PendingVaultBackup> createBackup({
    required String recoveryPassphrase,
  }) async {
    if (_closed) {
      throw const VaultLifecycleFailure('vault_session_closed');
    }
    if (_backupBusy) {
      throw const VaultLifecycleFailure('backup_in_progress');
    }
    _backupBusy = true;
    try {
      return await _createBackup(recoveryPassphrase);
    } finally {
      _backupBusy = false;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    ingestionController.dispose();
    _fileRootKey.destroy();
    await _databaseSession.close();
  }
}

final class _PlatformRestoreStoragePolicy implements RestoreStoragePolicy {
  const _PlatformRestoreStoragePolicy(this._transfer);

  final BackupArchiveTransfer _transfer;

  @override
  Future<void> ensureCapacity(Directory parent, int requiredBytes) async {
    if (requiredBytes < 0) {
      throw const InsufficientRestoreStorageFailure();
    }
    parent.createSync(recursive: true);
    final available = await _transfer.availableBytes(parent.path);
    if (available < requiredBytes) {
      throw const InsufficientRestoreStorageFailure();
    }
  }
}

final class _LocalRestoredMetadataProvisioner
    implements RestoredVaultProvisioner {
  const _LocalRestoredMetadataProvisioner({
    required CryptographicRandom random,
    required RecoveryKdfParameters kdfParameters,
  }) : _random = random,
       _kdfParameters = kdfParameters;

  final CryptographicRandom _random;
  final RecoveryKdfParameters _kdfParameters;

  @override
  Future<void> provision({
    required SecretBytes masterKey,
    required List<int> vaultHkdfSalt,
    required String recoveryPassphrase,
    required String vaultId,
    required Directory stagingDirectory,
  }) async {
    Uint8List? salt;
    Uint8List? nonce;
    try {
      salt = await _random.secureBytes(16);
      nonce = await _random.secureBytes(12);
      if (salt.length != 16 || nonce.length != 12) {
        throw const EntropyUnavailableFailure();
      }
      final envelope = await VaultCryptography(random: _random)
          .createRecoveryEnvelope(
            recoveryPassphrase: recoveryPassphrase,
            masterKey: masterKey,
            kdfParameters: _kdfParameters,
            salt: salt,
            nonce: nonce,
            createdAt: DateTime.now().toUtc(),
          );
      await _writeMetadataFile(
        File('${stagingDirectory.path}/vault-metadata-v1.json'),
        _VaultMetadata(
          vaultSalt: vaultHkdfSalt,
          recoveryEnvelope: RecoveryEnvelopeCodec.encode(envelope),
          createdAt: envelope.createdAt,
        ),
      );
    } finally {
      salt?.fillRange(0, salt.length, 0);
      nonce?.fillRange(0, nonce.length, 0);
    }
  }
}

String _hex(Iterable<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

Future<void> _writeMetadataFile(File file, _VaultMetadata metadata) async {
  file.parent.createSync(recursive: true);
  final temporary = File('${file.path}.partial');
  final encoded = utf8.encode(jsonEncode(metadata.toJson()));
  RandomAccessFile? writer;
  try {
    writer = temporary.openSync(mode: FileMode.write)
      ..writeFromSync(encoded)
      ..flushSync()
      ..closeSync();
    writer = null;
    temporary.renameSync(file.path);
  } finally {
    writer?.closeSync();
    if (temporary.existsSync()) temporary.deleteSync();
    encoded.fillRange(0, encoded.length, 0);
  }
}

final class _VaultMetadata {
  _VaultMetadata({
    required List<int> vaultSalt,
    required List<int> recoveryEnvelope,
    required this.createdAt,
    this.deviceEnvelope,
  }) : vaultSalt = Uint8List.fromList(vaultSalt),
       recoveryEnvelope = Uint8List.fromList(recoveryEnvelope) {
    if (this.vaultSalt.length != 32) {
      throw const FormatException('vault salt');
    }
    if (this.recoveryEnvelope.isEmpty ||
        this.recoveryEnvelope.length > maximumEnvelopeBytes) {
      throw const FormatException('recovery envelope');
    }
  }

  factory _VaultMetadata.fromJson(Map<String, Object?> json) {
    final version = json['format_version'];
    if ((version != 1 && version != formatVersion) ||
        (version == 1 && json.length != 4) ||
        (version == formatVersion && json.length != 5)) {
      throw const FormatException('metadata format');
    }
    final salt = json['vault_hkdf_salt'];
    final envelope = json['recovery_envelope'];
    final createdAt = json['created_at'];
    if (salt is! String || envelope is! String || createdAt is! String) {
      throw const FormatException('metadata fields');
    }
    return _VaultMetadata(
      vaultSalt: base64Decode(salt),
      recoveryEnvelope: base64Decode(envelope),
      createdAt: DateTime.parse(createdAt).toUtc(),
      deviceEnvelope: switch (json['device_envelope']) {
        final Map<String, Object?> value => _deviceEnvelopeFromJson(value),
        null => null,
        _ => throw const FormatException('device envelope'),
      },
    );
  }

  static const int formatVersion = 2;
  static const int maximumEnvelopeBytes = 4096;
  static const int maximumEncodedBytes = 16384;
  static final RegExp _deviceKeyAliasPattern = RegExp(
    r'^[A-Za-z0-9._-]{1,128}$',
  );

  final Uint8List vaultSalt;
  final Uint8List recoveryEnvelope;
  final DateTime createdAt;
  final DeviceEnvelope? deviceEnvelope;

  _VaultMetadata withDeviceEnvelope(DeviceEnvelope? value) => _VaultMetadata(
    vaultSalt: vaultSalt,
    recoveryEnvelope: recoveryEnvelope,
    createdAt: createdAt,
    deviceEnvelope: value,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'format_version': formatVersion,
    'vault_hkdf_salt': base64Encode(vaultSalt),
    'recovery_envelope': base64Encode(recoveryEnvelope),
    'created_at': createdAt.toUtc().toIso8601String(),
    'device_envelope': switch (deviceEnvelope) {
      final value? => <String, Object>{
        'key_alias': value.keyAlias,
        'nonce': base64Encode(value.nonce),
        'ciphertext': base64Encode(value.ciphertext),
        'authentication_tag': base64Encode(value.authenticationTag),
        'requires_authentication': value.requiresAuthentication,
        'invalidated_by_biometric_enrollment':
            value.invalidatedByBiometricEnrollment,
        'created_at': value.createdAt.toUtc().toIso8601String(),
        'hardware_backed': value.hardwareBacked,
      },
      null => null,
    },
  };

  static DeviceEnvelope _deviceEnvelopeFromJson(Map<String, Object?> json) {
    if (json.length != 8) throw const FormatException('device envelope shape');
    final alias = json['key_alias'];
    final nonce = json['nonce'];
    final ciphertext = json['ciphertext'];
    final tag = json['authentication_tag'];
    final requiresAuthentication = json['requires_authentication'];
    final invalidated = json['invalidated_by_biometric_enrollment'];
    final createdAt = json['created_at'];
    final hardwareBacked = json['hardware_backed'];
    if (alias is! String ||
        nonce is! String ||
        ciphertext is! String ||
        tag is! String ||
        requiresAuthentication is! bool ||
        invalidated is! bool ||
        createdAt is! String ||
        hardwareBacked is! bool) {
      throw const FormatException('device envelope fields');
    }
    final nonceBytes = base64Decode(nonce);
    final ciphertextBytes = base64Decode(ciphertext);
    final tagBytes = base64Decode(tag);
    if (!_deviceKeyAliasPattern.hasMatch(alias) ||
        !requiresAuthentication ||
        !invalidated ||
        nonceBytes.length != 12 ||
        ciphertextBytes.length != 32 ||
        tagBytes.length != 16) {
      throw const FormatException('device envelope policy');
    }
    return DeviceEnvelope(
      keyAlias: alias,
      nonce: nonceBytes,
      ciphertext: ciphertextBytes,
      authenticationTag: tagBytes,
      requiresAuthentication: requiresAuthentication,
      invalidatedByBiometricEnrollment: invalidated,
      createdAt: DateTime.parse(createdAt).toUtc(),
      hardwareBacked: hardwareBacked,
    );
  }
}
