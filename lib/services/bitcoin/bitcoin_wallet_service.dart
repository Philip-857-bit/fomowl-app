import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_wallet_balance.dart';
import '../../models/chain.dart';
import '../storage_service.dart';
import 'bitcoin_discovery_service.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_provisioning_service.dart';

abstract interface class BitcoinWalletApi {
  Future<BitcoinWalletSnapshot> refresh(
    String walletIdentity,
    BitcoinProductNetwork network, {
    bool force = false,
    bool Function()? isCurrent,
  });
  BitcoinWalletSnapshot? cached(
    String walletIdentity,
    BitcoinProductNetwork network,
  );
  void invalidate(String walletIdentity, BitcoinProductNetwork network);
}

class _WalletCache {
  final snapshots = <String, BitcoinWalletSnapshot>{};
  final inFlight = <String, Future<BitcoinWalletSnapshot>>{};
  final epochs = <String, int>{};
}

/// Account state and host orchestration only. The SDK owns addresses and all transaction rules.
class BitcoinWalletService implements BitcoinWalletApi {
  final StorageService storage;
  final BitcoinCryptoApi crypto;
  final BitcoinNetworkApi network;
  final Duration cacheTtl;
  BitcoinWalletService({
    StorageService? storage,
    BitcoinCryptoApi? crypto,
    BitcoinNetworkApi? network,
    this.cacheTtl = const Duration(seconds: 30),
  }) : storage = storage ?? StorageService(),
       crypto = crypto ?? const NativeBitcoinCrypto(),
       network = network ?? BitcoinNetworkService();
  static final Expando<_WalletCache> _caches = Expando();
  _WalletCache get _cache =>
      _caches[storage.bitcoinAccounts.secureStore] ??= _WalletCache();
  String _key(String identity, BitcoinProductNetwork network) =>
      '${identity.toLowerCase()}:${network.id}';
  @override
  BitcoinWalletSnapshot? cached(
    String walletIdentity,
    BitcoinProductNetwork network,
  ) => _cache.snapshots[_key(walletIdentity, network)];
  @override
  void invalidate(String walletIdentity, BitcoinProductNetwork network) {
    final key = _key(walletIdentity, network);
    _cache.epochs[key] = (_cache.epochs[key] ?? 0) + 1;
    _cache.snapshots.remove(key);
    _cache.inFlight.remove(key);
  }

  @override
  Future<BitcoinWalletSnapshot> refresh(
    String walletIdentity,
    BitcoinProductNetwork network, {
    bool force = false,
    bool Function()? isCurrent,
  }) async {
    final key = _key(walletIdentity, network);
    final epoch = _cache.epochs[key] ?? 0;
    bool current() =>
        (_cache.epochs[key] ?? 0) == epoch && (isCurrent?.call() ?? true);
    if (!current()) throw StateError('Bitcoin wallet context changed');
    final previous = _cache.snapshots[key];
    if (!force &&
        previous != null &&
        DateTime.now().toUtc().difference(previous.discovery.scannedAt) <
            cacheTtl) {
      return previous;
    }
    final pending = _cache.inFlight[key];
    if (pending != null) {
      final result = await pending;
      if (!current()) throw StateError('Bitcoin wallet context changed');
      return result;
    }
    final operation = _refresh(walletIdentity, network, current);
    _cache.inFlight[key] = operation;
    try {
      final result = await operation;
      if (!current()) throw StateError('Bitcoin wallet context changed');
      _cache.snapshots[key] = result;
      return result;
    } finally {
      if (identical(_cache.inFlight[key], operation)) {
        _cache.inFlight.remove(key);
      }
    }
  }

  Future<BitcoinWalletSnapshot> _refresh(
    String identity,
    BitcoinProductNetwork network,
    bool Function() current,
  ) async {
    final wallet = (await storage.getWalletAccounts())
        .where(
          (wallet) => wallet.address.toLowerCase() == identity.toLowerCase(),
        )
        .firstOrNull;
    if (wallet == null || !wallet.supportsFamily(ChainFamily.bitcoin)) {
      throw StateError('Bitcoin requires a provisioned seed wallet');
    }
    final index = wallet.derivationIndex ?? 0;
    final state =
        await storage.bitcoinAccounts.readWalletState(
          identity,
          network,
          index,
        ) ??
        await BitcoinProvisioningService(
          storage: storage,
          crypto: crypto,
        ).ensureWallet(identity, network: network);
    if (state == null) throw StateError('Bitcoin account is not provisioned');
    final discovery = await BitcoinDiscoveryService(
      store: storage.bitcoinAccounts,
      network: this.network,
      crypto: crypto,
    ).scan(state, isCurrent: current);
    return BitcoinWalletSnapshot(discovery);
  }
}
