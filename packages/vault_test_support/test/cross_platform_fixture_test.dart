import 'dart:io';

import 'package:test/test.dart';
import 'package:vault_test_support/vault_test_support.dart';

void main() {
  final workspace = Directory('apps/citizen_vault_app').existsSync()
      ? Directory.current
      : Directory('../..');
  final fixtureDirectory = Directory(
    '${workspace.path}/apps/citizen_vault_app/assets/fixtures',
  );
  final archive = File(
    '${fixtureDirectory.path}/portable_reference_backup_v1.cvault',
  );
  final contractFile = File(
    '${fixtureDirectory.path}/portable_reference_backup_v1.json',
  );

  test(
    'portable fixture restores with byte-identical objects and rows',
    () async {
      final contract = PortableVaultFixtureContract.decode(
        contractFile.readAsStringSync(),
      );
      final root = Directory.systemTemp.createTempSync(
        'citizen_vault_interop_restore_',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });

      final report = await PortableVaultFixtureVerifier.verify(
        archive: archive,
        contract: contract,
        restoreParent: Directory('${root.path}/vaults'),
        random: DeterministicCryptographicRandom(
          List<int>.generate(512, (index) => (index + 31) & 0xFF),
        ),
      );

      expect(report.vaultId, portableFixtureVaultId);
      expect(report.objectCount, 2);
      expect(report.databaseTableCount, 11);
    },
  );

  test('fixture contract records portable producer provenance', () {
    final contract = PortableVaultFixtureContract.decode(
      contractFile.readAsStringSync(),
    );
    expect(contract.fixtureId, 'portable-vault-v1');
    expect(contract.producerPlatform, isNotEmpty);
    expect(contract.objects.map((object) => object.objectId), <String>[
      portableFixtureTextObjectId.value,
      portableFixtureBinaryObjectId.value,
    ]);
  });

  test('reverse-direction producer creates a restorable fixture', () async {
    final root = Directory.systemTemp.createTempSync(
      'citizen_vault_reverse_interop_',
    );
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final archive = File('${root.path}/ios-reference.cvault');
    final contract =
        await PortableVaultFixtureBuilder(
          random: DeterministicCryptographicRandom(
            List<int>.generate(4096, (index) => (index + 71) & 0xFF),
          ),
        ).create(
          workingRoot: Directory('${root.path}/source-work'),
          archive: archive,
          producerPlatform: 'ios-compatible-reference',
        );

    final report = await PortableVaultFixtureVerifier.verify(
      archive: archive,
      contract: contract,
      restoreParent: Directory('${root.path}/reverse-restore'),
      random: DeterministicCryptographicRandom(
        List<int>.generate(512, (index) => (index + 101) & 0xFF),
      ),
    );

    expect(report.vaultId, portableFixtureVaultId);
    expect(report.objectCount, contract.objects.length);
  });
}
