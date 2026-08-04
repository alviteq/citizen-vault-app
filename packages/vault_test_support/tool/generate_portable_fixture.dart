// Generates synthetic interoperability artifacts; never use real vault data.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:vault_test_support/vault_test_support.dart';

Future<void> main(List<String> arguments) async {
  final outputDirectory = Directory(
    arguments.isEmpty
        ? 'apps/citizen_vault_app/assets/fixtures'
        : arguments.single,
  )..createSync(recursive: true);
  final archive = File(
    '${outputDirectory.path}/portable_reference_backup_v1.cvault',
  );
  final contractFile = File(
    '${outputDirectory.path}/portable_reference_backup_v1.json',
  );
  final random = DeterministicCryptographicRandom(
    List<int>.generate(4096, (index) => (index + 1) & 0xFF),
  );
  final contract = await PortableVaultFixtureBuilder(random: random).create(
    workingRoot: Directory.systemTemp.createTempSync(
      'citizen_vault_portable_fixture_',
    ),
    archive: archive,
    producerPlatform: 'portable-dart-reference',
  );
  contractFile.writeAsStringSync('${contract.encode()}\n', flush: true);
  print('Wrote ${archive.path} (${archive.lengthSync()} bytes)');
  print('Wrote ${contractFile.path}');
}
