import 'dart:async';

/// Coordinates application writes with consistent database snapshots.
final class DatabaseWriteBarrier {
  int _activeWriters = 0;
  bool _snapshotActive = false;
  Completer<void>? _writersDrained;
  Completer<void>? _snapshotReleased;
  Future<void> _snapshotAcquisitionTail = Future<void>.value();

  /// Runs one application write, waiting while a snapshot barrier is active.
  Future<T> runWrite<T>(Future<T> Function() action) async {
    while (_snapshotActive) {
      await _snapshotReleased!.future;
    }
    _activeWriters += 1;
    try {
      return await action();
    } finally {
      _activeWriters -= 1;
      if (_activeWriters == 0) {
        _writersDrained?.complete();
        _writersDrained = null;
      }
    }
  }

  /// Prevents new writes and waits for active writers to finish.
  Future<DatabaseSnapshotLease> acquireSnapshot() async {
    final acquiredTurn = Completer<void>();
    final previousTurn = _snapshotAcquisitionTail;
    _snapshotAcquisitionTail = acquiredTurn.future;
    await previousTurn;
    _snapshotActive = true;
    _snapshotReleased = Completer<void>();
    if (_activeWriters > 0) {
      _writersDrained = Completer<void>();
      await _writersDrained!.future;
    }
    return DatabaseSnapshotLease._(this, acquiredTurn);
  }

  void _release(DatabaseSnapshotLease lease) {
    lease
      ..assertActiveFor(this)
      .._active = false;
    _snapshotActive = false;
    _snapshotReleased?.complete();
    _snapshotReleased = null;
    lease._acquiredTurn.complete();
  }
}

/// Exclusive snapshot-barrier ownership token.
final class DatabaseSnapshotLease {
  DatabaseSnapshotLease._(this._owner, this._acquiredTurn);

  final DatabaseWriteBarrier _owner;
  final Completer<void> _acquiredTurn;
  bool _active = true;

  /// Whether the lease still owns the barrier.
  bool get isActive => _active;

  /// Verifies ownership before privileged work.
  void assertActiveFor(DatabaseWriteBarrier barrier) {
    if (!_active || !identical(_owner, barrier)) {
      throw StateError('Invalid or released database snapshot lease');
    }
  }

  /// Releases the barrier. Calling twice is an error.
  void release() => _owner._release(this);
}
