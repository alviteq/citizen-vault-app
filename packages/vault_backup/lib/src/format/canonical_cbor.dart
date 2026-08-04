import 'dart:convert';
import 'dart:typed_data';

import 'package:vault_backup/src/errors/backup_failure.dart';

/// Tiny canonical-CBOR writer limited to definite arrays and required scalars.
final class CanonicalCborWriter {
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  void array(int length) => _head(4, length);
  void uint(int value) => _head(0, value);
  void byteString(List<int> value) {
    _head(2, value.length);
    _bytes.add(value);
  }

  void text(String value) {
    final encoded = utf8.encode(value);
    _head(3, encoded.length);
    _bytes.add(encoded);
  }

  Uint8List takeBytes() => _bytes.takeBytes();

  void _head(int major, int value) {
    if (value < 0) throw const InvalidBackupFormatFailure('negative_integer');
    final prefix = major << 5;
    if (value < 24) {
      _bytes.addByte(prefix | value);
    } else if (value <= 0xFF) {
      _bytes.add(<int>[prefix | 24, value]);
    } else if (value <= 0xFFFF) {
      _bytes.add(<int>[prefix | 25, value >> 8, value]);
    } else if (value <= 0xFFFFFFFF) {
      _bytes.add(<int>[
        prefix | 26,
        value >> 24,
        value >> 16,
        value >> 8,
        value,
      ]);
    } else {
      _bytes.addByte(prefix | 27);
      for (var shift = 56; shift >= 0; shift -= 8) {
        _bytes.addByte((value >> shift) & 0xFF);
      }
    }
  }
}

/// Strict canonical-CBOR reader for the same deliberately narrow subset.
final class CanonicalCborReader {
  /// Creates a reader over already size-bounded bytes.
  CanonicalCborReader(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  var _offset = 0;

  bool get isDone => _offset == _bytes.length;

  int array({required int maximumLength}) {
    final value = _head(4);
    if (value > maximumLength) {
      throw const InvalidBackupFormatFailure('array_length');
    }
    return value;
  }

  int uint({int maximum = 0x7FFFFFFFFFFFFFFF}) {
    final value = _head(0);
    if (value > maximum) {
      throw const InvalidBackupFormatFailure('integer_limit');
    }
    return value;
  }

  Uint8List byteString({required int maximumLength}) {
    final length = _head(2);
    if (length > maximumLength) {
      throw const InvalidBackupFormatFailure('bytes_length');
    }
    return _take(length);
  }

  String text({required int maximumBytes}) {
    final length = _head(3);
    if (length > maximumBytes) {
      throw const InvalidBackupFormatFailure('text_length');
    }
    try {
      return utf8.decode(_take(length), allowMalformed: false);
    } on FormatException catch (error) {
      throw InvalidBackupFormatFailure('utf8', cause: error);
    }
  }

  int _head(int expectedMajor) {
    final first = _take(1).single;
    if (first >> 5 != expectedMajor) {
      throw const InvalidBackupFormatFailure('cbor_type');
    }
    final additional = first & 31;
    if (additional < 24) return additional;
    final int length;
    switch (additional) {
      case 24:
        length = 1;
      case 25:
        length = 2;
      case 26:
        length = 4;
      case 27:
        length = 8;
      default:
        throw const InvalidBackupFormatFailure('indefinite_cbor');
    }
    final encoded = _take(length);
    var value = 0;
    for (final byte in encoded) {
      value = (value << 8) | byte;
    }
    if ((length == 1 && value < 24) ||
        (length == 2 && value <= 0xFF) ||
        (length == 4 && value <= 0xFFFF) ||
        (length == 8 && value <= 0xFFFFFFFF)) {
      throw const InvalidBackupFormatFailure('non_canonical_integer');
    }
    return value;
  }

  Uint8List _take(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw const InvalidBackupFormatFailure('truncated');
    }
    final result = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return result;
  }
}

// This deliberately tiny internal CBOR surface is documented by its codecs.
// ignore_for_file: public_member_api_docs
