import 'dart:typed_data';

import 'package:vault_crypto/src/envelope/recovery_envelope.dart';
import 'package:vault_crypto/src/errors/crypto_failure.dart';
import 'package:vault_crypto/src/kdf/kdf_parameters.dart';
import 'package:vault_crypto/src/policy/import_policy.dart';

/// Canonical portable binary codec for [RecoveryEnvelope].
///
/// Integers are unsigned big-endian. Fields are emitted in this exact order:
/// `CVRE`, version(u16), wrapping(u8), kdf(u8), iterations(u32),
/// memoryKiB(u32), parallelism(u16), outputLength(u16), saltLen(u16), salt,
/// nonceLen(u8), nonce, createdAtUnixSeconds(u64), headerSha256(32),
/// ciphertextLen(u16), ciphertext, tagLen(u8), tag.
abstract final class RecoveryEnvelopeCodec {
  static const List<int> _magic = <int>[0x43, 0x56, 0x52, 0x45];

  /// Encodes a recovery envelope canonically.
  static Uint8List encode(RecoveryEnvelope envelope) {
    final builder = BytesBuilder(copy: false)
      ..add(
        baseHeaderBytes(
          formatVersion: envelope.formatVersion,
          wrappingAlgorithm: envelope.wrappingAlgorithm,
          kdfParameters: envelope.kdfParameters,
          salt: envelope.salt,
          nonce: envelope.nonce,
          createdAt: envelope.createdAt,
        ),
      )
      ..add(envelope.headerDigest)
      ..add(_u16(envelope.ciphertext.length))
      ..add(envelope.ciphertext)
      ..addByte(envelope.authenticationTag.length)
      ..add(envelope.authenticationTag);
    return builder.toBytes();
  }

  /// Canonical fields hashed for `headerDigest` and bound as AES-GCM AAD.
  static Uint8List baseHeaderBytes({
    required int formatVersion,
    required KeyWrappingAlgorithm wrappingAlgorithm,
    required RecoveryKdfParameters kdfParameters,
    required List<int> salt,
    required List<int> nonce,
    required DateTime createdAt,
  }) {
    final seconds = createdAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final builder = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(_u16(formatVersion))
      ..addByte(wrappingAlgorithm.wireId)
      ..addByte(kdfParameters.algorithm.wireId)
      ..add(_u32(kdfParameters.iterations))
      ..add(_u32(kdfParameters.memoryKiB))
      ..add(_u16(kdfParameters.parallelism))
      ..add(_u16(kdfParameters.outputLength))
      ..add(_u16(salt.length))
      ..add(salt)
      ..addByte(nonce.length)
      ..add(nonce)
      ..add(_u64(seconds));
    return builder.toBytes();
  }

  /// Returns the authenticated header consisting of base fields plus digest.
  static Uint8List authenticatedHeader({
    required Uint8List baseHeader,
    required List<int> headerDigest,
  }) {
    return (BytesBuilder(copy: false)
          ..add(baseHeader)
          ..add(headerDigest))
        .toBytes();
  }

  /// Parses an envelope with bounded field lengths.
  static RecoveryEnvelope decode(
    List<int> bytes, {
    VaultImportPolicy policy = const VaultImportPolicy(),
  }) {
    policy.validatePublicHeaderLength(bytes.length);
    try {
      final reader = _Reader(Uint8List.fromList(bytes));
      if (!_constantTimeEquals(reader.bytes(_magic.length), _magic)) {
        throw const UnsupportedRecoveryEnvelopeFailure('magic');
      }
      final version = reader.u16();
      if (version != RecoveryEnvelope.currentFormatVersion) {
        throw const UnsupportedRecoveryEnvelopeFailure('format_version');
      }
      final wrappingId = reader.u8();
      if (wrappingId != KeyWrappingAlgorithm.aes256Gcm.wireId) {
        throw const UnsupportedRecoveryEnvelopeFailure('wrapping_algorithm');
      }
      final kdfId = reader.u8();
      RecoveryKdfAlgorithm? kdfAlgorithm;
      for (final candidate in RecoveryKdfAlgorithm.values) {
        if (candidate.wireId == kdfId) {
          kdfAlgorithm = candidate;
        }
      }
      if (kdfAlgorithm == null) {
        throw const UnsupportedRecoveryEnvelopeFailure('kdf_algorithm');
      }
      final parameters = RecoveryKdfParameters(
        algorithm: kdfAlgorithm,
        iterations: reader.u32(),
        memoryKiB: reader.u32(),
        parallelism: reader.u16(),
        outputLength: reader.u16(),
      );
      final salt = reader.lengthPrefixedU16(maximum: 64);
      final nonce = reader.lengthPrefixedU8(maximum: 32);
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        reader.u64() * 1000,
        isUtc: true,
      );
      final headerDigest = reader.bytes(32);
      final ciphertext = reader.lengthPrefixedU16(maximum: 64);
      final tag = reader.lengthPrefixedU8(maximum: 32);
      if (!reader.isDone) {
        throw const UnsupportedRecoveryEnvelopeFailure('trailing_bytes');
      }
      policy.validateKdf(parameters, saltLength: salt.length);
      if (nonce.length != 12 || ciphertext.length != 32 || tag.length != 16) {
        throw const UnsupportedRecoveryEnvelopeFailure('cipher_shape');
      }
      final envelope = RecoveryEnvelope(
        formatVersion: version,
        wrappingAlgorithm: KeyWrappingAlgorithm.aes256Gcm,
        kdfParameters: parameters,
        salt: salt,
        nonce: nonce,
        ciphertext: ciphertext,
        authenticationTag: tag,
        headerDigest: headerDigest,
        createdAt: createdAt,
      );
      if (!_constantTimeEquals(encode(envelope), bytes)) {
        throw const UnsupportedRecoveryEnvelopeFailure('non_canonical');
      }
      return envelope;
    } on VaultCryptoFailure {
      rethrow;
    } on Object catch (error) {
      throw UnsupportedRecoveryEnvelopeFailure('malformed', cause: error);
    }
  }

  static Uint8List _u16(int value) {
    if (value < 0 || value > 0xffff) {
      throw RangeError.range(value, 0, 0xffff);
    }
    return Uint8List(2)..buffer.asByteData().setUint16(0, value);
  }

  static Uint8List _u32(int value) {
    if (value < 0 || value > 0xffffffff) {
      throw RangeError.range(value, 0, 0xffffffff);
    }
    return Uint8List(4)..buffer.asByteData().setUint32(0, value);
  }

  static Uint8List _u64(int value) {
    if (value < 0) {
      throw RangeError.value(value);
    }
    return Uint8List(8)..buffer.asByteData().setUint64(0, value);
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < left.length; index += 1) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}

final class _Reader {
  _Reader(this.data);

  final Uint8List data;
  int _offset = 0;

  bool get isDone => _offset == data.length;

  int u8() {
    _require(1);
    return data[_offset++];
  }

  int u16() {
    _require(2);
    final value = data.buffer.asByteData().getUint16(_offset);
    _offset += 2;
    return value;
  }

  int u32() {
    _require(4);
    final value = data.buffer.asByteData().getUint32(_offset);
    _offset += 4;
    return value;
  }

  int u64() {
    _require(8);
    final value = data.buffer.asByteData().getUint64(_offset);
    _offset += 8;
    return value;
  }

  Uint8List bytes(int length) {
    _require(length);
    final value = Uint8List.fromList(data.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }

  Uint8List lengthPrefixedU8({required int maximum}) {
    final length = u8();
    if (length > maximum) {
      throw const UnsupportedRecoveryEnvelopeFailure('field_length');
    }
    return bytes(length);
  }

  Uint8List lengthPrefixedU16({required int maximum}) {
    final length = u16();
    if (length > maximum) {
      throw const UnsupportedRecoveryEnvelopeFailure('field_length');
    }
    return bytes(length);
  }

  void _require(int length) {
    if (length < 0 || _offset + length > data.length) {
      throw const UnsupportedRecoveryEnvelopeFailure('truncated');
    }
  }
}
