import 'dart:async';

import 'package:vault_objects/src/errors/object_store_failure.dart';

/// Cooperative cancellation shared by object reads and writes.
final class CancellationToken {
  bool _isCancelled = false;
  final Completer<void> _cancelled = Completer<void>();

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Completes once cancellation is requested.
  Future<void> get whenCancelled => _cancelled.future;

  /// Requests cancellation. Repeated calls are harmless.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelled.complete();
  }

  /// Throws the stable cancellation failure when cancellation was requested.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw const ObjectOperationCancelledFailure();
    }
  }
}
