import 'dart:convert';
import 'dart:io';

import 'package:citizen_vault_app/src/vault/biometric_authenticator.dart';
import 'package:citizen_vault_app/src/vault/vault_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vault_backup/vault_backup.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';
import 'package:vault_ocr/vault_ocr.dart';
import 'package:vault_test_support/vault_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'creates encrypted metadata and unlocks only with the passphrase',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'citizen_vault_lifecycle_',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final lifecycle = LocalVaultLifecycle(
        rootDirectory: root,
        random: DeterministicCryptographicRandom(
          List<int>.generate(256, (index) => index & 0xff),
        ),
      );
      const passphrase = 'correct horse battery staple';

      expect(await lifecycle.exists(), isFalse);
      final created = await lifecycle.create(recoveryPassphrase: passphrase);
      expect(await lifecycle.exists(), isTrue);
      await created.close();

      final metadata = File(
        '${root.path}/citizen_vault/vault-metadata-v1.json',
      ).readAsStringSync();
      expect(metadata, isNot(contains(passphrase)));
      expect(metadata, contains('"recovery_envelope"'));
      expect(File('${root.path}/citizen_vault/vault.db').existsSync(), isTrue);

      await expectLater(
        lifecycle.unlock(recoveryPassphrase: 'this phrase is definitely wrong'),
        throwsA(
          isA<VaultLifecycleFailure>().having(
            (failure) => failure.code,
            'code',
            'incorrect_recovery_credential',
          ),
        ),
      );

      final unlocked = await lifecycle.unlock(recoveryPassphrase: passphrase);
      await unlocked.ingestionController.refresh();
      expect(unlocked.ingestionController.jobs, isEmpty);
      await unlocked.close();
    },
  );

  test(
    'system picker lease prevents the unlocked session from closing',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'citizen_vault_picker_lease_',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final lifecycle = LocalVaultLifecycle(
        rootDirectory: root,
        random: DeterministicCryptographicRandom(
          List<int>.generate(256, (index) => (index * 7) & 0xff),
        ),
      );
      final handle = await lifecycle.create(
        recoveryPassphrase: 'picker lease recovery phrase',
      );

      expect(handle.isBusy, isFalse);
      handle.ingestionController.beginExternalActivity();
      expect(handle.isBusy, isTrue);
      handle.ingestionController.endExternalActivity();
      expect(handle.isBusy, isFalse);

      await handle.close();
    },
  );

  test('rejects a second vault creation without changing the first', () async {
    final root = Directory.systemTemp.createTempSync(
      'citizen_vault_lifecycle_',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final lifecycle = LocalVaultLifecycle(
      rootDirectory: root,
      random: DeterministicCryptographicRandom(
        List<int>.generate(256, (index) => (255 - index) & 0xff),
      ),
    );
    final handle = await lifecycle.create(
      recoveryPassphrase: 'first secure recovery phrase',
    );
    await handle.close();

    await expectLater(
      lifecycle.create(recoveryPassphrase: 'second secure recovery phrase'),
      throwsA(
        isA<VaultLifecycleFailure>().having(
          (failure) => failure.code,
          'code',
          'vault_already_exists',
        ),
      ),
    );
    expect(await lifecycle.exists(), isTrue);
  });

  test(
    'rejects inconsistent protected metadata before opening SQLCipher',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'citizen_vault_lifecycle_',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final lifecycle = LocalVaultLifecycle(
        rootDirectory: root,
        random: DeterministicCryptographicRandom(
          List<int>.generate(256, (index) => (index * 3) & 0xff),
        ),
      );
      const passphrase = 'metadata integrity recovery phrase';
      final handle = await lifecycle.create(recoveryPassphrase: passphrase);
      await handle.close();

      final metadataFile = File(
        '${root.path}/citizen_vault/vault-metadata-v1.json',
      );
      final metadata =
          jsonDecode(metadataFile.readAsStringSync()) as Map<String, Object?>;
      metadata['created_at'] = '2020-01-01T00:00:00.000Z';
      metadataFile.writeAsStringSync(jsonEncode(metadata), flush: true);

      await expectLater(
        lifecycle.unlock(recoveryPassphrase: passphrase),
        throwsA(
          isA<VaultLifecycleFailure>().having(
            (failure) => failure.code,
            'code',
            'vault_metadata_invalid',
          ),
        ),
      );
    },
  );

  test('biometric envelope preserves recovery fallback', () async {
    final root = Directory.systemTemp.createTempSync(
      'citizen_vault_biometric_',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final envelopes = _MemoryDeviceEnvelopeStore();
    addTearDown(envelopes.dispose);
    final biometrics = _FakeBiometrics();
    final lifecycle = LocalVaultLifecycle(
      rootDirectory: root,
      random: DeterministicCryptographicRandom(
        List<int>.generate(512, (index) => (index * 7) & 0xff),
      ),
      deviceEnvelopes: envelopes,
      biometricAuthenticator: biometrics,
    );
    const passphrase = 'biometric recovery fallback phrase';
    final created = await lifecycle.create(recoveryPassphrase: passphrase);
    await created.close();

    expect(await lifecycle.biometricEnabled(), isFalse);
    await lifecycle.enableBiometrics(recoveryPassphrase: passphrase);
    expect(await lifecycle.biometricEnabled(), isTrue);
    expect(biometrics.authenticationCount, 1);
    final biometric = await lifecycle.unlockWithBiometrics();
    await biometric.close();
    expect(biometrics.authenticationCount, 2);

    await lifecycle.disableBiometrics();
    expect(await lifecycle.biometricEnabled(), isFalse);
    final recovered = await lifecycle.unlock(recoveryPassphrase: passphrase);
    await recovered.close();
  });

  test(
    'invalidated biometric key fails closed and recovery still unlocks',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'citizen_vault_biometric_invalidated_',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final envelopes = _MemoryDeviceEnvelopeStore();
      addTearDown(envelopes.dispose);
      final lifecycle = LocalVaultLifecycle(
        rootDirectory: root,
        random: DeterministicCryptographicRandom(
          List<int>.generate(512, (index) => (index * 9 + 1) & 0xff),
        ),
        deviceEnvelopes: envelopes,
        biometricAuthenticator: _FakeBiometrics(),
      );
      const passphrase = 'biometric invalidation recovery phrase';
      final created = await lifecycle.create(recoveryPassphrase: passphrase);
      await created.close();
      await lifecycle.enableBiometrics(recoveryPassphrase: passphrase);
      await envelopes.delete('citizen_vault.master.v1');

      await expectLater(
        lifecycle.unlockWithBiometrics(),
        throwsA(
          isA<VaultLifecycleFailure>().having(
            (failure) => failure.code,
            'code',
            'biometric_invalidated',
          ),
        ),
      );
      final recovered = await lifecycle.unlock(recoveryPassphrase: passphrase);
      await recovered.close();
    },
  );

  test('version-one metadata remains unlock compatible', () async {
    final root = Directory.systemTemp.createTempSync(
      'citizen_vault_metadata_v1_',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final lifecycle = LocalVaultLifecycle(
      rootDirectory: root,
      random: DeterministicCryptographicRandom(
        List<int>.generate(256, (index) => (index * 11) & 0xff),
      ),
    );
    const passphrase = 'legacy metadata recovery phrase';
    final created = await lifecycle.create(recoveryPassphrase: passphrase);
    await created.close();
    final metadataFile = File(
      '${root.path}/citizen_vault/vault-metadata-v1.json',
    );
    final metadata =
        (jsonDecode(metadataFile.readAsStringSync()) as Map<String, Object?>)
          ..['format_version'] = 1
          ..remove('device_envelope');
    metadataFile.writeAsStringSync(jsonEncode(metadata), flush: true);

    final unlocked = await lifecycle.unlock(recoveryPassphrase: passphrase);
    await unlocked.close();
  });

  test(
    'portable backup restores a clean installation with its passphrase',
    () async {
      final sourceRoot = Directory.systemTemp.createTempSync(
        'citizen_vault_backup_source_',
      );
      final targetRoot = Directory.systemTemp.createTempSync(
        'citizen_vault_backup_target_',
      );
      addTearDown(() {
        if (sourceRoot.existsSync()) sourceRoot.deleteSync(recursive: true);
        if (targetRoot.existsSync()) targetRoot.deleteSync(recursive: true);
      });
      const passphrase = 'portable recovery phrase for lost phone';
      const kdf = RecoveryKdfParameters.productionPbkdf2Fallback();
      final source = LocalVaultLifecycle(
        rootDirectory: sourceRoot,
        random: DeterministicCryptographicRandom(
          List<int>.generate(4096, (index) => (index * 13) & 0xff),
        ),
        restoreStoragePolicy: const _AllowRestoreStorage(),
        kdfParameters: kdf,
      );
      final sourceHandle = await source.create(recoveryPassphrase: passphrase);
      final pending = await sourceHandle.createBackup(
        recoveryPassphrase: passphrase,
      );
      await sourceHandle.close();
      addTearDown(pending.dispose);

      final target = LocalVaultLifecycle(
        rootDirectory: targetRoot,
        random: DeterministicCryptographicRandom(
          List<int>.generate(4096, (index) => (index * 17 + 3) & 0xff),
        ),
        restoreStoragePolicy: const _AllowRestoreStorage(),
        kdfParameters: kdf,
      );
      await expectLater(
        target.restoreBackup(
          archive: pending.archive,
          recoveryPassphrase: 'incorrect but sufficiently long phrase',
        ),
        throwsA(
          isA<VaultLifecycleFailure>().having(
            (failure) => failure.code,
            'code',
            'incorrect_recovery_credential',
          ),
        ),
      );

      final restored = await target.restoreBackup(
        archive: pending.archive,
        recoveryPassphrase: passphrase,
      );
      await restored.ingestionController.refresh();
      expect(restored.ingestionController.documents, isEmpty);
      await restored.close();
      expect(await target.exists(), isTrue);
      expect(
        File(
          '${targetRoot.path}/citizen_vault/vault-metadata-v1.json',
        ).existsSync(),
        isTrue,
      );
      final reopened = await target.unlock(recoveryPassphrase: passphrase);
      await reopened.close();
    },
  );

  test(
    'complete encrypted document journey survives backup and reopen',
    () async {
      final sourceRoot = Directory.systemTemp.createTempSync(
        'ownkeep_journey_source_',
      );
      final targetRoot = Directory.systemTemp.createTempSync(
        'ownkeep_journey_target_',
      );
      addTearDown(() {
        if (sourceRoot.existsSync()) sourceRoot.deleteSync(recursive: true);
        if (targetRoot.existsSync()) targetRoot.deleteSync(recursive: true);
      });
      const passphrase = 'complete document journey recovery phrase';
      const kdf = RecoveryKdfParameters.productionPbkdf2Fallback();
      final source = LocalVaultLifecycle(
        rootDirectory: sourceRoot,
        random: DeterministicCryptographicRandom(
          List<int>.generate(8192, (index) => (index * 19 + 7) & 0xff),
        ),
        restoreStoragePolicy: const _AllowRestoreStorage(),
        kdfParameters: kdf,
        ocrEngine: const _JourneyOcrEngine(),
        preferredOcrLanguages: () => const <String>['hi'],
      );
      final handle = await source.create(recoveryPassphrase: passphrase);
      final controller = handle.ingestionController;
      final sourceImage = image.Image(width: 64, height: 40)
        ..clear(image.ColorRgb8(255, 255, 255));
      final png = image.encodePng(sourceImage);

      await controller.importCandidate(
        IngestionCandidate(
          logicalFilename: 'pan-card.png',
          mimeType: 'image/png',
          length: png.length,
          source: DocumentImportSource.gallery,
          openRead: () => Stream<List<int>>.value(png),
        ),
      );

      expect(
        controller.jobs.single.status,
        DocumentProcessingStatus.awaitingReview,
        reason:
            controller.jobs.single.safeErrorCode ??
            controller.notice ??
            'unknown reprocessing state',
      );
      final review = controller.reviews.single;
      expect(review.ocrTextPreview, contains('abcde1234f'));
      expect(await controller.search('ABCDE1234F'), hasLength(1));

      await controller.confirmReview(
        documentId: review.documentId,
        documentType: DocumentType.pan,
        fields: <ConfirmedFieldEdit>[
          for (final field in review.fields)
            ConfirmedFieldEdit(fieldId: field.id, value: field.effectiveValue),
        ],
      );
      await controller.reprocessDocument(review.documentId);
      expect(
        controller.jobs.single.status,
        DocumentProcessingStatus.awaitingReview,
        reason: controller.jobs.single.safeErrorCode,
      );
      final reprocessed = controller.reviews.singleWhere(
        (item) => item.documentId == review.documentId,
      );
      expect(reprocessed.ocrTextPreview, contains('abcde1234f'));
      await controller.confirmReview(
        documentId: reprocessed.documentId,
        documentType: DocumentType.pan,
        fields: <ConfirmedFieldEdit>[
          for (final field in reprocessed.fields)
            ConfirmedFieldEdit(fieldId: field.id, value: field.effectiveValue),
        ],
      );
      await controller.setFavourite(review.documentId, true);
      await controller.setArchived(review.documentId, true);
      final detail = await controller.document(review.documentId);
      expect(detail, isNotNull);
      expect(detail!.summary.isFavourite, isTrue);
      expect(detail.summary.isArchived, isTrue);

      final original = await controller.documentOriginal(
        review.documentId,
        mimeType: 'image/png',
      );
      final originalBytes = await original.usePrivatePath(
        (path) => File(path).readAsBytes(),
      );
      await original.close();
      expect(originalBytes, png);

      final pending = await handle.createBackup(recoveryPassphrase: passphrase);
      addTearDown(pending.dispose);
      await handle.close();

      final target = LocalVaultLifecycle(
        rootDirectory: targetRoot,
        random: DeterministicCryptographicRandom(
          List<int>.generate(8192, (index) => (index * 23 + 11) & 0xff),
        ),
        restoreStoragePolicy: const _AllowRestoreStorage(),
        kdfParameters: kdf,
        ocrEngine: const _JourneyOcrEngine(),
      );
      final restored = await target.restoreBackup(
        archive: pending.archive,
        recoveryPassphrase: passphrase,
      );
      final restoredDetail = await restored.ingestionController.document(
        review.documentId,
      );
      expect(restoredDetail, isNotNull);
      expect(restoredDetail!.summary.isArchived, isTrue);
      expect(
        await restored.ingestionController.search('ABCDE1234F'),
        hasLength(1),
      );
      await restored.close();

      final reopened = await target.unlock(recoveryPassphrase: passphrase);
      expect(
        await reopened.ingestionController.document(review.documentId),
        isNotNull,
      );
      await reopened.close();
    },
  );

  test(
    'corrupted portable backup is rejected without creating a vault',
    () async {
      final sourceRoot = Directory.systemTemp.createTempSync(
        'ownkeep_corrupt_source_',
      );
      final targetRoot = Directory.systemTemp.createTempSync(
        'ownkeep_corrupt_target_',
      );
      addTearDown(() {
        if (sourceRoot.existsSync()) sourceRoot.deleteSync(recursive: true);
        if (targetRoot.existsSync()) targetRoot.deleteSync(recursive: true);
      });
      const passphrase = 'corruption recovery test phrase';
      const kdf = RecoveryKdfParameters.productionPbkdf2Fallback();
      final source = LocalVaultLifecycle(
        rootDirectory: sourceRoot,
        random: DeterministicCryptographicRandom(
          List<int>.generate(4096, (index) => (index * 29 + 5) & 0xff),
        ),
        restoreStoragePolicy: const _AllowRestoreStorage(),
        kdfParameters: kdf,
      );
      final sourceHandle = await source.create(recoveryPassphrase: passphrase);
      final pending = await sourceHandle.createBackup(
        recoveryPassphrase: passphrase,
      );
      await sourceHandle.close();
      addTearDown(pending.dispose);

      final corruptArchive = File('${targetRoot.path}/corrupted.cvault');
      final bytes = pending.archive.readAsBytesSync();
      bytes[bytes.length - 1] ^= 0xff;
      corruptArchive.writeAsBytesSync(bytes, flush: true);

      final target = LocalVaultLifecycle(
        rootDirectory: targetRoot,
        random: DeterministicCryptographicRandom(
          List<int>.generate(4096, (index) => (index * 31 + 9) & 0xff),
        ),
        restoreStoragePolicy: const _AllowRestoreStorage(),
        kdfParameters: kdf,
      );
      await expectLater(
        target.restoreBackup(
          archive: corruptArchive,
          recoveryPassphrase: passphrase,
        ),
        throwsA(isA<VaultLifecycleFailure>()),
      );
      expect(await target.exists(), isFalse);
    },
  );
}

final class _JourneyOcrEngine implements OcrEngine {
  const _JourneyOcrEngine();

  @override
  String get engineId => 'journey-ocr';

  @override
  String get engineVersion => '1';

  @override
  Future<OcrCapabilities> capabilities() async => OcrCapabilities(
    supportedMimeTypes: const <String>{'image/png'},
    supportedScripts: const <String>{'Latn', 'Deva'},
    supportedLanguages: const <String>{'en', 'hi'},
    supportsLayout: true,
    supportsTables: false,
  );

  @override
  Future<OcrResult> recognize(OcrRequest request) async {
    expect(request.preferredLanguages, contains('hi'));
    const text =
        'INCOME TAX DEPARTMENT\nPERMANENT ACCOUNT NUMBER\n'
        'ABCDE1234F\nDate of Birth 15/08/1990';
    return OcrResult(
      engineId: engineId,
      engineVersion: engineVersion,
      detectedLanguages: const <String>['en'],
      detectedScripts: const <String>['Latn'],
      pages: <OcrPage>[
        OcrPage(
          pageNumber: 1,
          blocks: <OcrBlock>[
            OcrBlock(
              id: 'block-1',
              text: text,
              lines: <OcrLine>[
                OcrLine(
                  id: 'line-1',
                  text: text,
                  words: const <OcrWord>[
                    OcrWord(id: 'word-1', text: 'ABCDE1234F'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      warnings: const <String>[],
      rawText: text,
    );
  }
}

final class _AllowRestoreStorage implements RestoreStoragePolicy {
  const _AllowRestoreStorage();

  @override
  Future<void> ensureCapacity(Directory parent, int requiredBytes) async {}
}

final class _FakeBiometrics implements BiometricAuthenticator {
  int authenticationCount = 0;

  @override
  Future<bool> authenticate() async {
    authenticationCount += 1;
    return true;
  }

  @override
  Future<bool> isAvailable() async => true;
}

final class _MemoryDeviceEnvelopeStore implements DeviceEnvelopeStore {
  SecretBytes? _masterKey;

  @override
  Future<void> delete(String keyAlias) async {
    _masterKey?.destroy();
    _masterKey = null;
  }

  @override
  Future<SecretBytes> unwrap(DeviceEnvelope envelope) async {
    final key = _masterKey;
    if (key == null) throw const PlatformKeyInvalidatedFailure();
    return SecretBytes(key.extractBytes());
  }

  @override
  Future<DeviceEnvelope> wrap({
    required String keyAlias,
    required SecretBytes masterKey,
    required bool invalidatedByBiometricEnrollment,
    required Duration authenticationValidity,
  }) async {
    _masterKey?.destroy();
    _masterKey = SecretBytes(masterKey.extractBytes());
    return DeviceEnvelope(
      keyAlias: keyAlias,
      nonce: List<int>.filled(12, 1),
      ciphertext: List<int>.filled(32, 2),
      authenticationTag: List<int>.filled(16, 3),
      requiresAuthentication: true,
      invalidatedByBiometricEnrollment: invalidatedByBiometricEnrollment,
      createdAt: DateTime.utc(2026, 7, 25),
      hardwareBacked: true,
    );
  }

  void dispose() {
    _masterKey?.destroy();
    _masterKey = null;
  }
}
