import 'dart:async';

/// Bounded public-state refreshes tolerate delayed mempool/provider indexing.
class BitcoinPostTransactionRefresh {
  final List<Duration> delays;
  int _generation = 0;
  bool _disposed = false;
  Timer? _timer;
  Completer<void>? _wake;
  Future<void>? _inFlight;
  BitcoinPostTransactionRefresh({
    this.delays = const [
      Duration.zero,
      Duration(seconds: 3),
      Duration(seconds: 10),
    ],
  });
  void schedule({
    required Future<void> Function() refresh,
    required bool Function() isCurrent,
  }) {
    if (_disposed) return;
    _cancelDelay();
    final generation = ++_generation;
    unawaited(_run(generation, refresh, isCurrent));
  }

  Future<void> _run(
    int generation,
    Future<void> Function() refresh,
    bool Function() isCurrent,
  ) async {
    bool current() => !_disposed && generation == _generation && isCurrent();
    for (final delay in delays) {
      if (!current()) return;
      if (delay > Duration.zero) {
        final wake = Completer<void>();
        _wake = wake;
        _timer = Timer(delay, wake.complete);
        await wake.future;
      }
      if (!current()) return;
      final previous = _inFlight;
      if (previous != null) await previous;
      if (!current()) return;
      final done = Completer<void>();
      _inFlight = done.future;
      try {
        await refresh();
      } catch (_) {
        // A later bounded retry may observe indexing that was unavailable earlier.
      } finally {
        done.complete();
        if (identical(_inFlight, done.future)) _inFlight = null;
      }
    }
  }

  void _cancelDelay() {
    _timer?.cancel();
    _timer = null;
    final wake = _wake;
    _wake = null;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _cancelDelay();
  }
}
