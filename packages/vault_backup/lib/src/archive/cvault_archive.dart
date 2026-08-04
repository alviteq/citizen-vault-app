import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:meta/meta.dart';
import 'package:vault_backup/src/errors/backup_failure.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_objects/vault_objects.dart';

/// One streaming archive-entry source with a precomputed digest.
final class CvaultEntrySource {
  /// Creates an entry source.
  const CvaultEntrySource({
    required this.name,
    required this.length,
    required this.sha256,
    required this.open,
  });

  /// Creates a bounded in-memory metadata entry.
  static Future<CvaultEntrySource> bytes(String name, List<int> bytes) async {
    final owned = Uint8List.fromList(bytes);
    return CvaultEntrySource(
      name: name,
      length: owned.length,
      sha256: Uint8List.fromList(
        crypto.Sha256().toSync().hashSync(owned).bytes,
      ),
      open: () => Stream<List<int>>.value(owned),
    );
  }

  final String name;
  final int length;
  final Uint8List sha256;
  final Stream<List<int>> Function() open;
}

/// Verified archive entry metadata.
@immutable
final class CvaultArchiveEntryInfo {
  const CvaultArchiveEntryInfo({
    required this.name,
    required this.length,
    required this.sha256,
    required this.dataOffset,
  });

  final String name;
  final int length;
  final Uint8List sha256;

  /// Byte offset used only by the verified reader, never persisted.
  final int dataOffset;
}

/// Uncompressed deterministic streaming `.cvault` container writer.
abstract final class CvaultArchiveWriter {
  static const List<int> _magic = <int>[0x43, 0x56, 0x41, 0x31]; // CVA1
  static const List<int> _entryMagic = <int>[0x43, 0x56, 0x45, 0x31];
  static const List<int> _footerMagic = <int>[0x43, 0x56, 0x41, 0x46];

  /// Writes canonical ordered entries and flushes the output.
  static Future<void> write(
    File output,
    List<CvaultEntrySource> entries,
  ) async {
    _validateOrdering(entries.map((entry) => entry.name).toList());
    final writer = await output.open(mode: FileMode.write);
    try {
      await writer.writeFrom(_magic);
      for (final entry in entries) {
        final nameBytes = utf8.encode(entry.name);
        if (nameBytes.length > 512 || entry.sha256.length != 32) {
          throw const InvalidBackupFormatFailure('entry_header');
        }
        await writer.writeFrom(<int>[
          ..._entryMagic,
          ..._u16(nameBytes.length),
          ...nameBytes,
          ..._u64(entry.length),
          ...entry.sha256,
        ]);
        final sink = crypto.Sha256().toSync().newHashSink();
        var written = 0;
        await for (final chunk in entry.open()) {
          if (written + chunk.length > entry.length) {
            throw const BackupCreationFailure();
          }
          sink.add(chunk);
          await writer.writeFrom(chunk);
          written += chunk.length;
        }
        sink.close();
        if (written != entry.length ||
            !_equal(sink.hashSync().bytes, entry.sha256)) {
          throw const BackupCreationFailure();
        }
      }
      await writer.writeFrom(<int>[..._footerMagic, ..._u32(entries.length)]);
      await writer.flush();
    } finally {
      await writer.close();
    }
  }

  static void _validateOrdering(List<String> names) {
    if (names.length < 4 ||
        names[0] != 'header.cbor' ||
        names[1] != 'recovery-envelope.cbor' ||
        names[2] != 'encrypted-manifest.bin' ||
        names[3] != 'database/snapshot.bin') {
      throw const InvalidBackupFormatFailure('entry_order');
    }
    final objectNames = names.skip(4).toList();
    final sorted = List<String>.from(objectNames)..sort();
    if (!_listEqual(objectNames, sorted) ||
        objectNames.toSet().length != objectNames.length ||
        objectNames.any((name) => !name.startsWith('objects/'))) {
      throw const InvalidBackupFormatFailure('object_entry_order');
    }
    names.forEach(_validateName);
  }

  static void _validateName(String name) {
    if (name.isEmpty ||
        name.startsWith('/') ||
        name.contains(r'\') ||
        name
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw const InvalidBackupFormatFailure('entry_name');
    }
    if (name.startsWith('objects/')) {
      final parts = name.split('/');
      if (parts.length != 2 || !parts[1].endsWith('.bin')) {
        throw const InvalidBackupFormatFailure('object_entry_name');
      }
      try {
        ObjectId.parse(parts[1].substring(0, parts[1].length - 4));
      } on ObjectStoreFailure catch (error) {
        throw InvalidBackupFormatFailure('object_entry_name', cause: error);
      }
    }
  }
}

/// Strict bounded reader for the custom uncompressed container.
final class CvaultArchiveReader {
  /// Creates a reader.
  const CvaultArchiveReader(
    this.archive, {
    this.policy = const VaultImportPolicy(),
  });

  final File archive;
  final VaultImportPolicy policy;

  /// Streams through every entry, verifies digests, and rejects trailing data.
  Future<List<CvaultArchiveEntryInfo>> inspect() async {
    if (!archive.existsSync()) {
      throw const InvalidBackupFormatFailure('archive_missing');
    }
    final reader = await archive.open();
    final entries = <CvaultArchiveEntryInfo>[];
    var totalDeclared = 0;
    try {
      if (!_equal(await _readExact(reader, 4), CvaultArchiveWriter._magic)) {
        throw const InvalidBackupFormatFailure('archive_magic');
      }
      while (true) {
        final marker = await _readExact(reader, 4);
        if (_equal(marker, CvaultArchiveWriter._footerMagic)) {
          final count = _readU32(await _readExact(reader, 4), 0);
          if (count != entries.length ||
              await reader.position() != await reader.length()) {
            throw const InvalidBackupFormatFailure('archive_footer');
          }
          break;
        }
        if (!_equal(marker, CvaultArchiveWriter._entryMagic)) {
          throw const InvalidBackupFormatFailure('entry_magic');
        }
        if (entries.length >= policy.maximumArchiveEntries) {
          throw const InvalidBackupFormatFailure('entry_count');
        }
        final nameLength = _readU16(await _readExact(reader, 2), 0);
        if (nameLength < 1 || nameLength > policy.maximumPathBytes) {
          throw const InvalidBackupFormatFailure('entry_name_length');
        }
        final name = utf8.decode(
          await _readExact(reader, nameLength),
          allowMalformed: false,
        );
        CvaultArchiveWriter._validateName(name);
        final length = _readU64(await _readExact(reader, 8), 0);
        if (length > policy.maximumObjectBytes) {
          throw const InvalidBackupFormatFailure('entry_size');
        }
        totalDeclared += length;
        if (totalDeclared > policy.maximumDeclaredPlaintextBytes) {
          throw const InvalidBackupFormatFailure('archive_size');
        }
        final expectedDigest = await _readExact(reader, 32);
        final dataOffset = await reader.position();
        final sink = crypto.Sha256().toSync().newHashSink();
        var remaining = length;
        while (remaining > 0) {
          final amount = remaining < 1024 * 1024 ? remaining : 1024 * 1024;
          final chunk = await _readExact(reader, amount);
          sink.add(chunk);
          remaining -= amount;
        }
        sink.close();
        if (!_equal(sink.hashSync().bytes, expectedDigest)) {
          throw const BackupVerificationFailure('entry_digest');
        }
        entries.add(
          CvaultArchiveEntryInfo(
            name: name,
            length: length,
            sha256: Uint8List.fromList(expectedDigest),
            dataOffset: dataOffset,
          ),
        );
      }
      CvaultArchiveWriter._validateOrdering(
        entries.map((entry) => entry.name).toList(),
      );
      return List<CvaultArchiveEntryInfo>.unmodifiable(entries);
    } on BackupFailure {
      rethrow;
    } on FormatException catch (error) {
      throw InvalidBackupFormatFailure('entry_utf8', cause: error);
    } on Object catch (error) {
      throw InvalidBackupFormatFailure('archive_read', cause: error);
    } finally {
      await reader.close();
    }
  }

  /// Reads one already-inspected small metadata entry.
  Future<Uint8List> readSmall(
    CvaultArchiveEntryInfo entry, {
    required int maximumBytes,
  }) async {
    if (entry.length > maximumBytes) {
      throw const InvalidBackupFormatFailure('small_entry_size');
    }
    final reader = await archive.open();
    try {
      await reader.setPosition(entry.dataOffset);
      return await _readExact(reader, entry.length);
    } finally {
      await reader.close();
    }
  }

  /// Streams verified data into caller-selected safe destination files.
  Future<void> extract(Map<String, File> destinations) async {
    final entries = await inspect();
    final byName = <String, CvaultArchiveEntryInfo>{
      for (final entry in entries) entry.name: entry,
    };
    if (!destinations.keys.every(byName.containsKey)) {
      throw const InvalidBackupFormatFailure('extract_inventory');
    }
    for (final MapEntry(key: name, value: destination)
        in destinations.entries) {
      final entry = byName[name]!;
      destination.parent.createSync(recursive: true);
      final source = await archive.open();
      final target = await destination.open(mode: FileMode.write);
      try {
        await source.setPosition(entry.dataOffset);
        var remaining = entry.length;
        while (remaining > 0) {
          final amount = remaining < 1024 * 1024 ? remaining : 1024 * 1024;
          final chunk = await _readExact(source, amount);
          await target.writeFrom(chunk);
          remaining -= amount;
        }
        await target.flush();
      } finally {
        await target.close();
        await source.close();
      }
    }
  }
}

/// Computes a streaming SHA-256 digest for a file.
Future<Uint8List> sha256File(File file) async {
  final sink = crypto.Sha256().toSync().newHashSink();
  await file.openRead().forEach(sink.add);
  sink.close();
  return Uint8List.fromList(sink.hashSync().bytes);
}

List<int> _u16(int value) => <int>[(value >> 8) & 0xFF, value & 0xFF];
List<int> _u32(int value) => <int>[
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];
List<int> _u64(int value) => <int>[
  for (var shift = 56; shift >= 0; shift -= 8) (value >> shift) & 0xFF,
];

int _readU16(List<int> bytes, int offset) =>
    (bytes[offset] << 8) | bytes[offset + 1];
int _readU32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
int _readU64(List<int> bytes, int offset) {
  var value = 0;
  for (var index = 0; index < 8; index += 1) {
    value = (value << 8) | bytes[offset + index];
  }
  return value;
}

Future<Uint8List> _readExact(RandomAccessFile file, int length) async {
  final output = Uint8List(length);
  var offset = 0;
  while (offset < length) {
    final chunk = await file.read(length - offset);
    if (chunk.isEmpty) {
      throw const InvalidBackupFormatFailure('truncated_archive');
    }
    output.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return output;
}

bool _equal(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

bool _listEqual<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

// Wire fields are documented in docs/backup_format/README.md.
// ignore_for_file: public_member_api_docs
