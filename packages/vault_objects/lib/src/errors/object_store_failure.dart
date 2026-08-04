/// Base class for safe encrypted object-store failures.
sealed class ObjectStoreFailure implements Exception {
  /// Creates a stable failure code with an internal-only cause.
  const ObjectStoreFailure(this.code, {this.cause});

  /// Stable machine-readable code.
  final String code;

  /// Internal cause. Never expose it directly to users or logs.
  final Object? cause;

  @override
  String toString() => 'ObjectStoreFailure($code)';
}

/// An object identifier, range, chunk size, or declared length is invalid.
final class InvalidObjectInputFailure extends ObjectStoreFailure {
  /// Creates the failure.
  const InvalidObjectInputFailure(this.field, {super.cause})
    : super('invalid_object_input');

  /// Safe field identifier.
  final String field;
}

/// The requested object does not exist.
final class ObjectMissingFailure extends ObjectStoreFailure {
  /// Creates the failure.
  const ObjectMissingFailure() : super('object_missing');
}

/// An existing logical object prevents an overwrite.
final class ObjectAlreadyExistsFailure extends ObjectStoreFailure {
  /// Creates the failure.
  const ObjectAlreadyExistsFailure() : super('object_already_exists');
}

/// Object authentication or key unwrapping failed.
final class ObjectAuthenticationFailure extends ObjectStoreFailure {
  /// Creates the failure.
  const ObjectAuthenticationFailure({super.cause})
    : super('object_authentication_failed');
}

/// The serialized object is malformed, truncated, reordered, or corrupted.
final class CorruptObjectFailure extends ObjectStoreFailure {
  /// Creates the failure. [chunkIndex] is for internal diagnostics only.
  const CorruptObjectFailure({this.chunkIndex, super.cause})
    : super('object_corrupted');

  /// Exact failing chunk when known. Do not expose it in user-facing text.
  final int? chunkIndex;
}

/// The serialized object uses a future or unsupported format.
final class UnsupportedObjectFormatFailure extends ObjectStoreFailure {
  /// Creates the failure.
  const UnsupportedObjectFormatFailure() : super('object_format_unsupported');
}

/// A read or write was cancelled cooperatively.
final class ObjectOperationCancelledFailure extends ObjectStoreFailure {
  /// Creates the failure.
  const ObjectOperationCancelledFailure() : super('object_operation_cancelled');
}

/// Atomic object writing or publication failed.
final class ObjectWriteFailure extends ObjectStoreFailure {
  /// Creates the failure.
  const ObjectWriteFailure({super.cause}) : super('object_write_failed');
}

/// Physical deletion is not yet permitted by reference and retention policy.
final class ObjectRetentionFailure extends ObjectStoreFailure {
  /// Creates the failure.
  const ObjectRetentionFailure() : super('object_retention_blocked');
}
