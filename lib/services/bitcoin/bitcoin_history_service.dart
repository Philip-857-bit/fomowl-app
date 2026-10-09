import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_account_history.dart';
import '../../models/bitcoin_network_data.dart';
import '../../utils/bitcoin_amount_utils.dart';
import '../wallet_history_service.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_wallet_service.dart';

class BitcoinHistoryService {
  final BitcoinWalletApi wallet;
  final BitcoinNetworkApi network;
  final WalletHistoryService local;
  final int maximumQueriedAddresses;
  BitcoinHistoryService({
    BitcoinWalletApi? wallet,
    BitcoinNetworkApi? network,
    WalletHistoryService? local,
    this.maximumQueriedAddresses = 1024,
  }) : wallet = wallet ?? BitcoinWalletService(),
       network = network ?? BitcoinNetworkService(),
       local = local ?? WalletHistoryService();
  Future<WalletHistoryResponse> fetch(
    String identity,
    BitcoinProductNetwork productNetwork, {
    int limit = 120,
    bool Function()? isCurrent,
  }) async {
    if (limit < 1 ||
        limit > 200 ||
        maximumQueriedAddresses < 40 ||
        maximumQueriedAddresses > 4096) {
      throw ArgumentError('Invalid Bitcoin history window');
    }
    void check() {
      if (isCurrent?.call() == false) {
        throw StateError('Bitcoin wallet context changed');
      }
    }

    check();
    final snapshot = await wallet.refresh(
      identity,
      productNetwork,
      isCurrent: isCurrent,
    );
    if (snapshot.discovery.state.walletIdentity.toLowerCase() !=
            identity.toLowerCase() ||
        snapshot.discovery.state.network != productNetwork) {
      throw StateError('Bitcoin history account mismatch');
    }
    final addresses = snapshot.discovery.ownership.values.toList()
      ..sort((a, b) {
        final leftUsed = snapshot.discovery.activity[a.address]?.used ?? false;
        final rightUsed = snapshot.discovery.activity[b.address]?.used ?? false;
        if (leftUsed != rightUsed) return leftUsed ? -1 : 1;
        final index = b.addressIndex.compareTo(a.addressIndex);
        if (index != 0) return index;
        final purpose = a.account.purpose.number.compareTo(
          b.account.purpose.number,
        );
        if (purpose != 0) return purpose;
        final keychain = a.keychain.index.compareTo(b.keychain.index);
        return keychain != 0 ? keychain : a.address.compareTo(b.address);
      });
    final queried = addresses
        .take(maximumQueriedAddresses)
        .map((value) => value.address)
        .toList();
    final owned = snapshot.discovery.ownership.keys.toSet();
    final transactions = <String, BitcoinHistoryTransaction>{};
    var partial = addresses.length > queried.length;
    final localFuture = local
        .fetchWalletHistory(walletAddress: identity, limit: limit)
        .then<WalletHistoryResponse?>(
          (value) => value,
          onError: (Object _) => null,
        );
    final elapsed = Stopwatch()..start();
    for (var offset = 0; offset < queried.length; offset += 40) {
      check();
      final remaining = const Duration(seconds: 30) - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        partial = true;
        break;
      }
      final end = offset + 40 < queried.length ? offset + 40 : queried.length;
      BitcoinHistoryBatch batch;
      try {
        batch = await network
            .fetchAccountHistory(
              identity,
              productNetwork,
              queried.sublist(offset, end),
              limit: limit,
            )
            .timeout(remaining);
      } catch (_) {
        partial = true;
        break;
      }
      check();
      if (batch.network != productNetwork) {
        throw StateError('Bitcoin history network mismatch');
      }
      partial |= batch.truncated;
      for (final tx in batch.transactions) {
        final previous = transactions[tx.txid];
        if (previous != null && !_sameTransaction(previous, tx)) {
          throw const FormatException(
            'Conflicting Bitcoin history observations',
          );
        }
        transactions[tx.txid] = tx;
      }
    }
    final localResult = await localFuture;
    check();
    partial |= localResult == null || localResult.partial;
    final entries = <String, WalletHistoryEntry>{};
    for (final entry in localResult?.history ?? const <WalletHistoryEntry>[]) {
      if (entry.networkKey != productNetwork.networkKey ||
          entry.walletAddress.toLowerCase() != identity.toLowerCase() ||
          entry.txHash == null) {
        continue;
      }
      try {
        entries[bitcoinTxid(entry.txHash)] = entry;
      } on FormatException {
        partial = true;
      }
    }
    for (final tx in transactions.values) {
      final accountEntry = BitcoinAccountHistoryEntry(
        productNetwork,
        tx,
        owned,
      );
      final previous = entries[tx.txid];
      final amount = BitcoinAmountUtils.format(accountEntry.deltaSats.abs());
      entries[tx.txid] = WalletHistoryEntry(
        id: tx.txid,
        walletAddress: identity,
        networkKey: productNetwork.networkKey,
        networkName: productNetwork == BitcoinProductNetwork.mainnet
            ? 'Bitcoin'
            : 'Bitcoin Testnet4',
        eventType: accountEntry.incoming ? 'receive' : 'send',
        title: accountEntry.incoming ? 'Bitcoin received' : 'Bitcoin sent',
        message: 'Wallet change: $amount BTC',
        isIncoming: accountEntry.incoming,
        createdAt: tx.timestamp == null
            ? previous?.createdAt ?? snapshot.discovery.scannedAt
            : DateTime.fromMillisecondsSinceEpoch(
                tx.timestamp! * 1000,
                isUtc: true,
              ),
        source: 'bitcoin-chain',
        txHash: tx.txid,
        tokenName: 'Bitcoin',
        tokenSymbol: 'BTC',
        amount: double.parse(amount),
        bitcoin: accountEntry,
      );
    }
    final result = entries.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    partial |= result.length > limit;
    return WalletHistoryResponse(
      history: List.unmodifiable(result.take(limit)),
      partial: partial,
      message: partial
          ? 'Bitcoin history is a bounded window; some activity may be unavailable.'
          : null,
    );
  }

  bool _sameTransaction(
    BitcoinHistoryTransaction a,
    BitcoinHistoryTransaction b,
  ) {
    bool same(
      List<BitcoinHistoryObservation> x,
      List<BitcoinHistoryObservation> y,
    ) =>
        x.length == y.length &&
        List.generate(
          x.length,
          (index) => x[index].sameAs(y[index]),
        ).every((value) => value);
    return a.feeSats == b.feeSats &&
        same(a.inputs, b.inputs) &&
        same(a.outputs, b.outputs);
  }
}
