// This manual acceptance probe prints bounded-memory timing and size evidence.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_objects/vault_objects.dart';

Future<void> main(List<String> arguments) async {
  final mebibytes = arguments.isEmpty ? 1024 : int.parse(arguments.single);
  if (mebibytes < 1 || mebibytes > 1024) {
    throw ArgumentError.value(mebibytes, 'mebibytes', 'must be 1..1024');
  }
  final totalBytes = mebibytes * 1024 * 1024;
  final directory = Directory.systemTemp.createTempSync(
    'citizen_vault_large_object_probe_',
  );
  final key = VaultFileRootKey.fromBytes(
    List<int>.generate(32, (index) => index),
    keyVersion: 1,
  );
  try {
    final stopwatch = Stopwatch()..start();
    final store = FileEncryptedObjectStore(
      rootDirectory: directory,
      random: _ProbeRandom(),
    );
    final result = await store.put(
      plaintext: _generatedBytes(totalBytes),
      objectId: ObjectId.parse('00000000000000000000000001'),
      fileRootKey: key,
    );
    stopwatch.stop();
    print('plaintext_bytes=${result.plaintextSize}');
    print('encrypted_bytes=${result.encryptedSize}');
    print('chunk_count=${result.chunkCount}');
    print('elapsed_ms=${stopwatch.elapsedMilliseconds}');
    print('source_segment_bytes=65536');
  } finally {
    key.destroy();
    directory.deleteSync(recursive: true);
  }
}

Stream<List<int>> _generatedBytes(int totalBytes) async* {
  final segment = Uint8List.fromList(
    List<int>.generate(64 * 1024, (index) => index & 0xFF),
  );
  var remaining = totalBytes;
  while (remaining > 0) {
    final length = remaining < segment.length ? remaining : segment.length;
    yield length == segment.length
        ? segment
        : Uint8List.sublistView(segment, 0, length);
    remaining -= length;
  }
}

final class _ProbeRandom implements CryptographicRandom {
  var _next = 1;

  @override
  Future<Uint8List> secureBytes(int length) async => Uint8List.fromList(
    List<int>.generate(length, (_) => _next++ & 0xFF),
  );
}
