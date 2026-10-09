import 'bitcoin_account_state.dart';
import 'bitcoin_discovery.dart';
import 'bitcoin_network_data.dart';

class BitcoinPurposeBalance {
  final BigInt confirmedSats;
  final BigInt mempoolDeltaSats;
  final BigInt spendableSats;
  const BitcoinPurposeBalance(
    this.confirmedSats,
    this.mempoolDeltaSats,
    this.spendableSats,
  );
  BigInt get totalSats => confirmedSats + mempoolDeltaSats;
}

class BitcoinWalletSnapshot {
  final BitcoinDiscoverySnapshot discovery;
  final Map<BitcoinPurpose, BitcoinPurposeBalance> balances;
  BitcoinWalletSnapshot(this.discovery) : balances = _balances(discovery);
  static Map<BitcoinPurpose, BitcoinPurposeBalance> _balances(
    BitcoinDiscoverySnapshot snapshot,
  ) {
    final result = <BitcoinPurpose, BitcoinPurposeBalance>{};
    for (final purpose in BitcoinPurpose.values) {
      var confirmed = BigInt.zero;
      var mempool = BigInt.zero;
      var spendable = BigInt.zero;
      for (final entry in snapshot.activity.entries) {
        final owner = snapshot.ownership[entry.key];
        if (owner == null) {
          throw const FormatException('Bitcoin balance ownership is unknown');
        }
        if (owner.account.purpose != purpose) continue;
        confirmed += entry.value.confirmedBalanceSats;
        mempool += entry.value.mempoolBalanceSats;
        spendable += entry.value.utxos.fold(
          BigInt.zero,
          (sum, utxo) => sum + utxo.valueSats,
        );
      }
      if (confirmed > bitcoinMaxMoneySats ||
          mempool.abs() > bitcoinMaxMoneySats ||
          spendable > bitcoinMaxMoneySats ||
          confirmed + mempool < BigInt.zero ||
          confirmed + mempool > bitcoinMaxMoneySats) {
        throw const FormatException('Inconsistent Bitcoin account balances');
      }
      result[purpose] = BitcoinPurposeBalance(confirmed, mempool, spendable);
    }
    final total = result.values.fold(
      BigInt.zero,
      (sum, balance) => sum + balance.totalSats,
    );
    if (total > bitcoinMaxMoneySats) {
      throw const FormatException('Bitcoin account balance overflow');
    }
    return Map.unmodifiable(result);
  }

  BigInt get totalSats => balances.values.fold(
    BigInt.zero,
    (sum, balance) => sum + balance.totalSats,
  );
  BigInt get spendableSats => balances.values.fold(
    BigInt.zero,
    (sum, balance) => sum + balance.spendableSats,
  );
}
