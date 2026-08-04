import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_objects/src/errors/object_store_failure.dart';

/// Random opaque 128-bit logical identifier encoded with Crockford base32.
@immutable
final class ObjectId {
  const ObjectId._(this.value);

  /// Parses a canonical opaque identifier.
  factory ObjectId.parse(String value) {
    if (!_pattern.hasMatch(value)) {
      throw const InvalidObjectInputFailure('object_id');
    }
    return ObjectId._(value);
  }

  static final RegExp _pattern = RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$');
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Generates a new identifier using exactly 128 random bits.
  static Future<ObjectId> generate(CryptographicRandom random) async {
    final bytes = await random.secureBytes(16);
    if (bytes.length != 16) {
      throw const InvalidObjectInputFailure('object_id_entropy');
    }
    return ObjectId._(_encode128(bytes));
  }

  /// Canonical 26-character value used as the filename stem.
  final String value;

  static String _encode128(Uint8List bytes) {
    var buffer = 0;
    var bits = 2; // Two leading zero bits make 128 bits fit 26 symbols.
    final output = StringBuffer();
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        output.write(_alphabet[(buffer >> bits) & 31]);
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) {
      output.write(_alphabet[(buffer << (5 - bits)) & 31]);
    }
    final value = output.toString();
    if (value.length != 26) {
      throw StateError('Invalid object identifier encoding');
    }
    return value;
  }

  @override
  bool operator ==(Object other) => other is ObjectId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ObjectId($value)';
}
