import 'dart:async';
import '../../models/bitcoin_account_state.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_submission_journal.dart';

class _ReconciliationState {
  final active = <String, Future<int>>{};
  final cursors = <String, int>{};
}

/// Public chain observations only. Confirmation is the only automatic release
/// condition; absence, provider errors and elapsed time never release inputs.
class BitcoinSubmissionReconciliationService {
  final BitcoinSubmissionJournal journal;
  final BitcoinNetworkApi network;
  final Duration requestTimeout;
  final Duration batchTimeout;
  final int maximumChecks;
  BitcoinSubmissionReconciliationService({
    required this.journal,
    required this.network,
    this.requestTimeout = const Duration(seconds: 8),
    this.batchTimeout = const Duration(seconds: 30),
    this.maximumChecks = 32,
  }) {
    if (requestTimeout <= Duration.zero ||
        batchTimeout <= Duration.zero ||
        maximumChecks < 1 ||
        maximumChecks > 128) {
      throw ArgumentError('Invalid Bitcoin reconciliation bounds');
    }
  }
  static final Expando<_ReconciliationState> _states = Expando();
  _ReconciliationState get _state =>
      _states[journal.store.secureStore] ??= _ReconciliationState();

  Future<int> reconcile(
    String identity,
    BitcoinProductNetwork productNetwork, {
    required bool Function() isCurrent,
  }) {
    final canonical = identity.trim().toLowerCase();
    final key = '$canonical|${productNetwork.id}';
    final existing = _state.active[key];
    if (existing != null) return existing;
    late final Future<int> operation;
    operation = _reconcile(canonical, productNetwork, key, isCurrent)
        .whenComplete(() {
          if (identical(_state.active[key], operation)) {
            _state.active.remove(key);
          }
        });
    _state.active[key] = operation;
    return operation;
  }

  Future<int> _reconcile(
    String identity,
    BitcoinProductNetwork productNetwork,
    String key,
    bool Function() isCurrent,
  ) async {
    var expired = false;
    final timer = Timer(batchTimeout, () => expired = true);
    bool current() => !expired && isCurrent();
    var removed = 0;
    try {
      if (!current()) return 0;
      final initial = await journal.pending(identity, productNetwork);
      if (!current() || initial.isEmpty) return 0;
      final start = (_state.cursors[key] ?? 0) % initial.length;
      final count = initial.length < maximumChecks
          ? initial.length
          : maximumChecks;
      for (var offset = 0; offset < count && current(); offset++) {
        final position = (start + offset) % initial.length;
        _state.cursors[key] = (position + 1) % initial.length;
        // Capture immediately before this entry's lookup. Earlier successful
        // removals must not invalidate every subsequent entry in the batch.
        final entries = await journal.pending(identity, productNetwork);
        if (!current()) break;
        final snapshot = entries
            .where((entry) => entry.txid == initial[position].txid)
            .firstOrNull;
        if (snapshot == null) continue;
        try {
          final status = await network
              .fetchTransactionStatus(productNetwork, snapshot.txid)
              .timeout(requestTimeout);
          if (!current()) break;
          if (await journal.reconcileConfirmed(
            snapshot,
            status,
            isCurrent: current,
          )) {
            removed++;
          }
        } catch (_) {
          // Keep the exact reservation on malformed status, transport failure,
          // rate limiting, unavailable protected storage or lost wallet context.
        }
      }
      return removed;
    } finally {
      timer.cancel();
    }
  }
}
