import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:vault_objects/src/errors/object_store_failure.dart';
import 'package:vault_objects/src/model/object_id.dart';

/// Reviewed bounds for encrypted object files.
final class ObjectStoreLimits {
  /// Creates a limits policy.
  const ObjectStoreLimits({
    this.minimumChunkSize = 64 * 1024,
    this.maximumChunkSize = 4 * 1024 * 1024,
    this.maximumPlaintextSize = 64 * 1024 * 1024 * 1024,
  });

  /// Smallest supported authenticated chunk.
  final int minimumChunkSize;

  /// Largest supported authenticated chunk.
  final int maximumChunkSize;

  /// Maximum declared and streamed plaintext bytes.
  final int maximumPlaintextSize;

  /// Validates values before allocation or cryptographic work.
  void validateChunkSize(int chunkSize) {
    if (chunkSize < minimumChunkSize || chunkSize > maximumChunkSize) {
      throw const InvalidObjectInputFailure('chunk_size');
    }
  }
}

/// Canonical constants and nonce/AAD construction for object format version 1.
abstract final class ObjectFormatV1 {
  /// Current serialized format version.
  static const int version = 1;

  /// AES-256-GCM algorithm identifier.
  static const int algorithmAes256Gcm = 1;

  /// Default one-mebibyte chunk size.
  static const int defaultChunkSize = 1024 * 1024;

  /// AES-GCM authentication tag bytes.
  static const int authenticationTagLength = 16;

  /// Random nonce prefix bytes followed by a 32-bit chunk index.
  static const int chunkNoncePrefixLength = 8;

  /// Maximum supported header bytes before any allocation is accepted.
  static const int maximumHeaderLength = 512;

  /// ASCII `CVOB` object magic.
  static const List<int> magic = <int>[0x43, 0x56, 0x4F, 0x42];

  /// ASCII `CVCH` chunk-record magic.
  static const List<int> chunkMagic = <int>[0x43, 0x56, 0x43, 0x48];
  static final List<int> _bindingLabel = utf8.encode(
    'citizen-vault/object-binding/v1',
  );
  static final List<int> _chunkAadLabel = utf8.encode(
    'citizen-vault/object-chunk/v1',
  );
  static final List<int> _keyWrapAadLabel = utf8.encode(
    'citizen-vault/file-key-wrap/v1',
  );

  /// Constructs the unique 96-bit AES-GCM nonce for [chunkIndex].
  static Uint8List chunkNonce(List<int> prefix, int chunkIndex) {
    if (prefix.length != chunkNoncePrefixLength ||
        chunkIndex < 0 ||
        chunkIndex > 0xFFFFFFFF) {
      throw const InvalidObjectInputFailure('chunk_nonce');
    }
    return Uint8List.fromList(<int>[...prefix, ..._u32(chunkIndex)]);
  }

  /// Computes the stable identity binding known before streaming starts.
  static Uint8List objectBinding({
    required ObjectId objectId,
    required int keyVersion,
    required int chunkSize,
    required List<int> noncePrefix,
  }) {
    final bytes = <int>[
      ..._bindingLabel,
      ..._u16(version),
      algorithmAes256Gcm,
      ..._lengthPrefixedObjectId(objectId),
      ..._u32(keyVersion),
      ..._u32(chunkSize),
      ...noncePrefix,
    ];
    return Uint8List.fromList(
      crypto.Sha256().toSync().hashSync(bytes).bytes,
    );
  }

  /// Authenticated data binding a chunk to object, order, and exact length.
  static Uint8List chunkAad({
    required List<int> objectBinding,
    required int chunkIndex,
    required int plaintextLength,
  }) => Uint8List.fromList(<int>[
    ..._chunkAadLabel,
    ...objectBinding,
    ..._u32(chunkIndex),
    ..._u32(plaintextLength),
  ]);

  /// Authenticated data for the File Data Key envelope.
  static Uint8List keyWrapAad({
    required List<int> baseHeader,
    required List<int> headerDigest,
  }) => Uint8List.fromList(<int>[
    ..._keyWrapAadLabel,
    ...baseHeader,
    ...headerDigest,
  ]);

  static List<int> _lengthPrefixedObjectId(ObjectId objectId) {
    final bytes = ascii.encode(objectId.value);
    return <int>[bytes.length, ...bytes];
  }

  static List<int> _u16(int value) => <int>[
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];

  static List<int> _u32(int value) => <int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}

/// Internal authenticated header representation shared by writer and reader.
final class ObjectHeaderV1 {
  /// Creates a structurally validated header.
  ObjectHeaderV1({
    required this.objectId,
    required this.keyVersion,
    required this.chunkSize,
    required this.plaintextSize,
    required this.chunkCount,
    required List<int> noncePrefix,
    required List<int> wrapNonce,
    required List<int> wrappedFileKey,
    required List<int> wrappingTag,
    required List<int> headerDigest,
  }) : noncePrefix = Uint8List.fromList(noncePrefix),
       wrapNonce = Uint8List.fromList(wrapNonce),
       wrappedFileKey = Uint8List.fromList(wrappedFileKey),
       wrappingTag = Uint8List.fromList(wrappingTag),
       headerDigest = Uint8List.fromList(headerDigest);

  /// Logical identifier authenticated into the key envelope.
  final ObjectId objectId;

  /// File Root Key rotation version.
  final int keyVersion;

  /// Maximum plaintext bytes per chunk.
  final int chunkSize;

  /// Total authenticated plaintext bytes.
  final int plaintextSize;

  /// Total authenticated chunk records.
  final int chunkCount;

  /// Random 64-bit per-file chunk nonce prefix.
  final Uint8List noncePrefix;

  /// Random nonce for wrapping the File Data Key.
  final Uint8List wrapNonce;

  /// AES-GCM ciphertext of the File Data Key.
  final Uint8List wrappedFileKey;

  /// AES-GCM tag authenticating the wrapped key and header fields.
  final Uint8List wrappingTag;

  /// SHA-256 of canonical base header fields, authenticated as wrap AAD.
  final Uint8List headerDigest;

  /// Fixed length for a canonical 26-character object identifier.
  static const int encodedLength = 159;

  /// Canonical fields authenticated as File Data Key envelope AAD.
  Uint8List baseBytes() {
    final writer = _BinaryWriter()
      ..bytes(ObjectFormatV1.magic)
      ..u16(ObjectFormatV1.version)
      ..u8(ObjectFormatV1.algorithmAes256Gcm)
      ..u8(0)
      ..u16(encodedLength)
      ..ascii8(objectId.value)
      ..u32(keyVersion)
      ..u32(chunkSize)
      ..u64(plaintextSize)
      ..u32(chunkCount)
      ..bytes(noncePrefix)
      ..bytes(wrapNonce)
      ..u16(32);
    return writer.takeBytes();
  }

  /// Canonically encodes the complete header.
  Uint8List encode() {
    final writer = _BinaryWriter()
      ..bytes(baseBytes())
      ..bytes(wrappedFileKey)
      ..bytes(wrappingTag)
      ..bytes(headerDigest);
    final result = writer.takeBytes();
    if (result.length != encodedLength) {
      throw StateError('Unexpected object header length');
    }
    return result;
  }

  /// Decodes bounded untrusted header bytes without cryptographic trust.
  static ObjectHeaderV1 decode(List<int> bytes, ObjectStoreLimits limits) {
    if (bytes.length != encodedLength) {
      throw const CorruptObjectFailure();
    }
    final reader = _BinaryReader(bytes);
    if (!_equal(reader.bytes(4), ObjectFormatV1.magic)) {
      throw const CorruptObjectFailure();
    }
    final version = reader.u16();
    if (version != ObjectFormatV1.version) {
      throw const UnsupportedObjectFormatFailure();
    }
    if (reader.u8() != ObjectFormatV1.algorithmAes256Gcm) {
      throw const UnsupportedObjectFormatFailure();
    }
    if (reader.u8() != 0 || reader.u16() != encodedLength) {
      throw const CorruptObjectFailure();
    }
    final objectId = ObjectId.parse(reader.ascii8());
    final keyVersion = reader.u32();
    final chunkSize = reader.u32();
    limits.validateChunkSize(chunkSize);
    final plaintextSize = reader.u64();
    final chunkCount = reader.u32();
    if (keyVersion < 1 || plaintextSize > limits.maximumPlaintextSize) {
      throw const InvalidObjectInputFailure('object_header');
    }
    final expectedChunks = plaintextSize == 0
        ? 0
        : (plaintextSize + chunkSize - 1) ~/ chunkSize;
    if (chunkCount != expectedChunks) {
      throw const CorruptObjectFailure();
    }
    final noncePrefix = reader.bytes(8);
    final wrapNonce = reader.bytes(12);
    if (reader.u16() != 32) {
      throw const CorruptObjectFailure();
    }
    final header = ObjectHeaderV1(
      objectId: objectId,
      keyVersion: keyVersion,
      chunkSize: chunkSize,
      plaintextSize: plaintextSize,
      chunkCount: chunkCount,
      noncePrefix: noncePrefix,
      wrapNonce: wrapNonce,
      wrappedFileKey: reader.bytes(32),
      wrappingTag: reader.bytes(16),
      headerDigest: reader.bytes(32),
    );
    if (!reader.isDone) {
      throw const CorruptObjectFailure();
    }
    return header;
  }
}

final class _BinaryWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  void u8(int value) => _builder.addByte(value);
  void u16(int value) => bytes(<int>[(value >> 8) & 0xFF, value & 0xFF]);
  void u32(int value) => bytes(<int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
  void u64(int value) {
    if (value < 0) throw const InvalidObjectInputFailure('integer');
    for (var shift = 56; shift >= 0; shift -= 8) {
      u8((value >> shift) & 0xFF);
    }
  }

  void ascii8(String value) {
    final encoded = ascii.encode(value);
    u8(encoded.length);
    bytes(encoded);
  }

  void bytes(List<int> value) => _builder.add(value);
  Uint8List takeBytes() => _builder.takeBytes();
}

final class _BinaryReader {
  _BinaryReader(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  int _offset = 0;
  bool get isDone => _offset == _bytes.length;

  int u8() => bytes(1).single;
  int u16() {
    final value = bytes(2);
    return (value[0] << 8) | value[1];
  }

  int u32() {
    final value = bytes(4);
    return (value[0] << 24) | (value[1] << 16) | (value[2] << 8) | value[3];
  }

  int u64() {
    var result = 0;
    for (final value in bytes(8)) {
      result = (result << 8) | value;
    }
    return result;
  }

  String ascii8() => ascii.decode(bytes(u8()), allowInvalid: false);

  Uint8List bytes(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw const CorruptObjectFailure();
    }
    final result = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return result;
  }
}

bool _equal(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
