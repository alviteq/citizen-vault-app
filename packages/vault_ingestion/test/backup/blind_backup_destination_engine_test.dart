import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('BlindBackupDestinationEngine (Milestone 24 Gate)', () {
    late BlindBackupDestinationEngine engine;

    setUp(() {
      engine = BlindBackupDestinationEngine();
    });

    test('configures provider destination cleanly', () {
      expect(
        engine.activeConfig.destinationKind,
        BlindBackupDestinationKind.googleDrive,
      );

      engine.activeConfig = const BlindBackupConfig(
        destinationKind: BlindBackupDestinationKind.webDav,
        accountIdentifier: 'https://nas.local/webdav',
        remoteDirectoryPath: '/vault/',
      );

      expect(
        engine.activeConfig.destinationKind,
        BlindBackupDestinationKind.webDav,
      );
    });

    test('triggers blind sync using encrypted archive bytes only', () {
      final status = engine.triggerBlindSync(
        encryptedArchiveBytesHex: '0102030405060708090a',
      );

      expect(status.isSyncing, isFalse);
      expect(status.statusMessage, contains('Blind Sync Complete'));
      expect(engine.activeConfig.lastSyncAt, isNotNull);
    });

    test('verifies zero provider token policy (Milestone 24 Gate)', () {
      expect(engine.verifyZeroTokenPolicy(), isTrue);
    });
  });
}
