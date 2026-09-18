import 'package:flutter/foundation.dart';

bool forceLocalScopedReadForReason(String reason) {
  return switch (reason.trim().toLowerCase()) {
    'manual' || 'transaction' => true,
    _ => false,
  };
}

/// Shared Home/mini-app coordinator. Deduplicates refresh hints by wallet and
/// exact network, and exposes a generation that late results must match.
class BalanceRefreshCoordinator {
  BalanceRefreshCoordinator._();

  static final BalanceRefreshCoordinator instance =
      BalanceRefreshCoordinator._();

  final Map<String, Future<void>> _inflight = {};
  final Map<String, int> _generations = {};

  int generationFor(String wallet, String networkKey) {
    return _generations[_scopeKey(wallet, networkKey)] ?? 0;
  }

  bool isCurrent(String wallet, String networkKey, int generation) {
    return generationFor(wallet, networkKey) == generation;
  }

  void invalidate(String wallet, String networkKey) {
    final key = _scopeKey(wallet, networkKey);
    _generations[key] = (_generations[key] ?? 0) + 1;
  }

  Future<void> runExclusive({
    required String wallet,
    required String networkKey,
    required String reason,
    required Future<void> Function(int generation) work,
  }) {
    final scope = _scopeKey(wallet, networkKey);
    final requestKey = '$scope|$reason';
    final existing = _inflight[requestKey];
    if (existing != null) return existing;
    invalidate(wallet, networkKey);
    final generation = generationFor(wallet, networkKey);
    final future = () async {
      try {
        await work(generation);
      } finally {
        _inflight.remove(requestKey);
      }
    }();
    _inflight[requestKey] = future;
    return future;
  }

  String _scopeKey(String wallet, String networkKey) {
    final normalizedNetwork = networkKey.trim().toLowerCase();
    final trimmedWallet = wallet.trim();
    final normalizedWallet = normalizedNetwork.startsWith('evm:')
        ? trimmedWallet.toLowerCase()
        : trimmedWallet;
    return '$normalizedWallet|$normalizedNetwork';
  }
}

@visibleForTesting
void resetBalanceRefreshCoordinatorForTest() {
  BalanceRefreshCoordinator.instance._inflight.clear();
  BalanceRefreshCoordinator.instance._generations.clear();
}
