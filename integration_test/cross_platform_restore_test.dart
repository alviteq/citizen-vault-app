import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vault_backup/vault_backup.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_platform/vault_platform.dart';
import 'package:vault_test_support/vault_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('portable backup restores on the current mobile platform', (
    tester,
  ) async {
    final root = Directory(
      '${Directory.systemTemp.path}/citizen_vault_portable_restore',
    );
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    addTearDown(() async {
      await const PlatformDeviceEnvelopeStore().delete(
        _PlatformFixtureProvisioner.alias,
      );
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final archive = File('${root.path}/fixture.cvault');
    final archiveData = await rootBundle.load(
      'assets/fixtures/portable_reference_backup_v1.cvault',
    );
    archive.writeAsBytesSync(
      archiveData.buffer.asUint8List(
        archiveData.offsetInBytes,
        archiveData.lengthInBytes,
      ),
      flush: true,
    );
    final contractSource = await rootBundle.loadString(
      'assets/fixtures/portable_reference_backup_v1.json',
    );
    final report = await PortableVaultFixtureVerifier.verify(
      archive: archive,
      contract: PortableVaultFixtureContract.decode(contractSource),
      restoreParent: Directory('${root.path}/vaults'),
      random: const PlatformCryptographicRandom(),
      provisioner: const _PlatformFixtureProvisioner(),
    );

    expect(report.vaultId, portableFixtureVaultId);
    expect(report.objectCount, 2);
  });

  testWidgets('current platform can produce a reverse-direction fixture', (
    tester,
  ) async {
    final work = Directory(
      '${Directory.systemTemp.path}/citizen_vault_fixture_capture_work',
    );
    final archive = File(
      '${Directory.systemTemp.path}/citizen_vault_${Platform.operatingSystem}'
      '_backup_v1.cvault',
    );
    final contractFile = File(
      '${Directory.systemTemp.path}/citizen_vault_${Platform.operatingSystem}'
      '_backup_v1.json',
    );
    final contract =
        await PortableVaultFixtureBuilder(
          random: const PlatformCryptographicRandom(),
        ).create(
          workingRoot: work,
          archive: archive,
          producerPlatform: Platform.operatingSystem,
          producerRuntime: Platform.version,
        );
    contractFile.writeAsStringSync('${contract.encode()}\n', flush: true);

    expect(archive.existsSync(), isTrue);
    expect(
      jsonDecode(contractFile.readAsStringSync()),
      isA<Map<String, Object?>>(),
    );
  });
}

final class _PlatformFixtureProvisioner implements RestoredVaultProvisioner {
  const _PlatformFixtureProvisioner();

  static const String alias = 'citizen_vault.interop.restore.v1';

  @override
  Future<void> provision({
    required SecretBytes masterKey,
    required List<int> vaultHkdfSalt,
    required String recoveryPassphrase,
    required String vaultId,
    required Directory stagingDirectory,
  }) async {
    const store = PlatformDeviceEnvelopeStore();
    await store.delete(alias);
    await store.wrap(
      keyAlias: alias,
      masterKey: masterKey,
      invalidatedByBiometricEnrollment: false,
      authenticationValidity: const Duration(seconds: 300),
    );
  }
}
