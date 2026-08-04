// Named dependencies intentionally initialize private owned fields.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_ocr/src/model/ocr_models.dart';

/// Creates short-lived plaintext inputs in an app-private directory.
final class DecryptedAssetLeaseManager {
  /// Creates a manager with bounded plaintext and lifetime.
  DecryptedAssetLeaseManager({
    required Directory directory,
    required CryptographicRandom random,
    this.maximumBytes = 32 * 1024 * 1024,
    this.lifetime = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _directory = directory,
       _random = random,
       _clock = clock ?? DateTime.now;

  final Directory _directory;
  final CryptographicRandom _random;
  final DateTime Function() _clock;

  /// Maximum plaintext written into one lease.
  final int maximumBytes;

  /// Maximum lifetime for live and crash-recovered lease files.
  final Duration lifetime;

  static final RegExp _suffixPattern = RegExp(r'^\.[a-z0-9]{1,8}$');
  static final RegExp _leaseNamePattern = RegExp(
    r'^ocr-[0-9a-f]{32}\.[a-z0-9]{1,8}$',
  );

  /// Streams authenticated plaintext into an opaque exclusive file.
  Future<DecryptedAssetLease> create({
    required Stream<List<int>> plaintext,
    required String suffix,
  }) async {
    final normalizedSuffix = suffix.toLowerCase();
    if (!_suffixPattern.hasMatch(normalizedSuffix)) {
      throw ArgumentError.value(suffix, 'suffix');
    }
    _directory.createSync(recursive: true);
    final token = _hex(await _random.secureBytes(16));
    final file = File('${_directory.path}/ocr-$token$normalizedSuffix');
    RandomAccessFile? output;
    var total = 0;
    try {
      if (file.existsSync()) {
        throw const OcrFailure('temporary_input_collision', transient: true);
      }
      output = await file.open(mode: FileMode.write);
      await for (final bytes in plaintext) {
        total += bytes.length;
        if (total > maximumBytes) {
          throw const OcrFailure('ocr_input_too_large', transient: false);
        }
        await output.writeFrom(bytes);
      }
      await output.flush();
      await output.close();
      output = null;
      return DecryptedAssetLease._(
        file: file,
        expiresAt: _clock().toUtc().add(lifetime),
        clock: _clock,
      );
    } on OcrFailure {
      await output?.close();
      if (file.existsSync()) file.deleteSync();
      rethrow;
    } on Object catch (error) {
      await output?.close();
      if (file.existsSync()) file.deleteSync();
      throw OcrFailure(
        'temporary_input_unavailable',
        transient: true,
        cause: error,
      );
    }
  }

  /// Removes recognized stale leases after process termination.
  Future<int> cleanupExpired() async {
    if (!_directory.existsSync()) return 0;
    var removed = 0;
    final now = _clock().toUtc();
    for (final entity in _directory.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!_leaseNamePattern.hasMatch(name)) continue;
      final modified = entity.lastModifiedSync().toUtc();
      if (modified.add(lifetime).isAfter(now)) continue;
      entity.deleteSync();
      removed += 1;
    }
    return removed;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

/// Owned, expiring plaintext lease.
final class DecryptedAssetLease implements DecryptedAssetInput {
  DecryptedAssetLease._({
    required File file,
    required this.expiresAt,
    required DateTime Function() clock,
  }) : _file = file,
       _clock = clock;

  final File _file;
  final DateTime Function() _clock;

  /// UTC expiry time.
  final DateTime expiresAt;

  var _closed = false;

  @override
  Future<T> usePrivatePath<T>(Future<T> Function(String path) action) async {
    if (_closed || !_clock().toUtc().isBefore(expiresAt)) {
      throw const OcrFailure('decrypted_lease_expired', transient: true);
    }
    if (!_file.existsSync()) {
      throw const OcrFailure('decrypted_lease_missing', transient: true);
    }
    return action(_file.path);
  }

  /// Deletes the plaintext input. Safe to call repeatedly.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_file.existsSync()) _file.deleteSync();
  }
}
