// This command-line benchmark intentionally prints machine-readable results.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';

Future<void> main(List<String> arguments) async {
  final rowCount = arguments.isEmpty ? 1000 : int.parse(arguments.single);
  if (rowCount < 1 || rowCount > 100000) {
    throw ArgumentError.value(rowCount, 'rowCount', 'must be 1..100000');
  }

  final directory = Directory.systemTemp.createTempSync(
    'citizen_vault_snapshot_benchmark_',
  );
  final key = SecretBytes(List<int>.generate(32, (index) => index + 1));
  VaultDatabaseSession? session;
  try {
    session = await EncryptedDatabaseOpener.open(
      file: File('${directory.path}/source.db'),
      databaseKey: key,
      runInBackground: false,
    );
    await session.write((database) async {
      await database.transaction(() async {
        for (var index = 0; index < rowCount; index += 1) {
          await database.customStatement(
            '''
            INSERT INTO documents(
              id, logical_filename, mime_type, source_type, status,
              primary_object_id, plaintext_sha256, plaintext_size,
              encrypted_size, imported_at, updated_at, integrity_status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            <Object>[
              'document-$index',
              'document-$index.pdf',
              'application/pdf',
              'BENCHMARK',
              'READY',
              'object-$index',
              Uint8List(32),
              4096,
              4200,
              index,
              index,
              'VERIFIED',
            ],
          );
        }
        await database.rebuildFtsIndex();
      });
    });

    final result =
        await SqlCipherDatabaseSnapshotService(
          session,
        ).createSnapshot(
          generationId: BackupGenerationId('benchmark-$rowCount'),
          outputPath: '${directory.path}/snapshot.db',
        );
    print('rows=$rowCount');
    print('encrypted_bytes=${result.encryptedBytes}');
    print('barrier_elapsed_ms=${result.elapsed.inMilliseconds}');
  } finally {
    await session?.close();
    key.destroy();
    directory.deleteSync(recursive: true);
  }
}
