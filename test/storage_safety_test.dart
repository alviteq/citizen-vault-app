import 'package:citizen_vault_app/src/backup/backup_archive_transfer.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('vault storage summary totals measured categories', () {
    const summary = VaultStorageSummary(
      databaseBytes: 10,
      objectBytes: 20,
      temporaryBytes: 30,
      otherBytes: 40,
      fileCount: 4,
    );

    expect(summary.totalBytes, 100);
    expect(summary.fileCount, 4);
  });

  test(
    'restore capacity query fails closed when platform is unavailable',
    () async {
      const channel = MethodChannel('ownkeep.test/storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      const transfer = PlatformBackupArchiveTransfer(channel: channel);
      await expectLater(
        transfer.availableBytes('/private/owned-vault'),
        throwsA(
          isA<BackupArchiveTransferFailure>().having(
            (failure) => failure.code,
            'code',
            'storage_unavailable',
          ),
        ),
      );
    },
  );
}
