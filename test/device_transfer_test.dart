import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/transfer/device_transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

final class _TestIngestionController extends IngestionUiController {
  final _transferEngine = DeviceToDeviceTransferEngine();

  @override
  bool get isBusy => false;

  @override
  bool get isVaultAvailable => true;

  @override
  String? get notice => null;

  @override
  List<DocumentProcessingView> get jobs => const <DocumentProcessingView>[];

  @override
  List<DocumentReviewView> get reviews => const <DocumentReviewView>[];

  @override
  Future<void> captureImage() async {}

  @override
  Future<void> confirmReview({
    required String documentId,
    required DocumentType documentType,
    required List<ConfirmedFieldEdit> fields,
    String? profileEntityId,
  }) async {}

  @override
  Future<void> importFile() async {}

  @override
  Future<void> importGalleryImage() async {}

  @override
  Future<void> recover() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<List<DocumentSearchResult>> search(String query) async =>
      const <DocumentSearchResult>[];

  @override
  DeviceToDeviceTransferEngine get transferEngine => _transferEngine;

  @override
  TransferPairingSession initiateDeviceTransferPairing(String deviceId) {
    final sess =
        _transferEngine.initiatePairingSession(senderDeviceId: deviceId);
    notifyListeners();
    return sess;
  }

  @override
  TransferProgress simulateDeviceTransferStep() {
    final pkg = _transferEngine.preparePayloadPackage(
      rawVaultBackupBytesHex: '0102030405060708',
    );
    final prog = _transferEngine.updateTransferStep(
      package: pkg,
      completedChunks: pkg.totalChunks,
    );
    notifyListeners();
    return prog;
  }
}

void main() {
  group('Device Transfer Screen (Milestone 23)', () {
    late _TestIngestionController controller;

    setUp(() {
      controller = _TestIngestionController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders device transfer screen and pairing trigger', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceTransferScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Device-to-Device Transfer'), findsOneWidget);
      expect(find.text('Encrypted P2P Transfer (No Server)'), findsOneWidget);
      expect(find.text('Generate Pairing PIN'), findsOneWidget);
    });

    testWidgets('initiates pairing session and generates 6-digit PIN', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceTransferScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Pairing PIN'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Direct device transfer is not available yet'),
        findsOneWidget,
      );
      expect(controller.transferEngine.activeSession, isNull);
    });
  });
}
