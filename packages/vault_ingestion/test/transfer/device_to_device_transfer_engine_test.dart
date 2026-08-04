import 'package:test/test.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('DeviceToDeviceTransferEngine (Milestone 23 Gate)', () {
    late DeviceToDeviceTransferEngine transferEngine;

    setUp(() {
      transferEngine = DeviceToDeviceTransferEngine();
    });

    test('initiates ephemeral pairing session with 6-digit PIN', () {
      final session = transferEngine.initiatePairingSession(
        senderDeviceId: 'moto-g67',
      );

      expect(session.senderDeviceId, 'moto-g67');
      expect(session.pairingPin.length, 6);
      expect(transferEngine.activeSession, isNotNull);
    });

    test('prepares payload package and updates progress steps', () {
      final pkg = transferEngine.preparePayloadPackage(
        rawVaultBackupBytesHex: '0102030405060708',
      );

      expect(pkg.totalChunks, greaterThanOrEqualTo(1));

      final prog = transferEngine.updateTransferStep(
        package: pkg,
        completedChunks: pkg.totalChunks,
      );

      expect(prog.fraction, 1.0);
      expect(prog.status, contains('Complete'));
    });

    test('authenticates transfer payload hash equivalence', () {
      final isEquiv = transferEngine.verifyTransferEquivalence(
        sourceHash: 'hash-abc-123',
        destinationHash: 'hash-abc-123',
      );

      expect(isEquiv, isTrue);
    });
  });
}
