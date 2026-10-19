import 'bitcoin_account_state.dart';
import 'bitcoin_network_data.dart';

/// Public provider observations, not a replacement authorization.
class BitcoinReplacementObservation {
  final String networkKey;
  final String txid;
  final bool originalUnconfirmed;
  final bool hasDescendants;
  final int outputCount;
  final BigInt incrementalRelayFeeSatVb;
  BitcoinReplacementObservation.fromJson(Map<String, dynamic> json)
    : networkKey = bitcoinJsonString(json['networkKey'], maxLength: 32),
      txid = bitcoinTxid(json['txid']),
      originalUnconfirmed = bitcoinJsonBool(json['originalUnconfirmed']),
      hasDescendants = bitcoinJsonBool(json['hasDescendants']),
      outputCount = bitcoinJsonInt(json['outputCount'], maximum: 10000),
      incrementalRelayFeeSatVb = BigInt.from(
        bitcoinJsonInt(json['incrementalRelayFeeSatVb'], maximum: 10000),
      ) {
    if (json.length != 6 ||
        outputCount < 1 ||
        incrementalRelayFeeSatVb < BigInt.one ||
        ![
          BitcoinProductNetwork.mainnet.networkKey,
          BitcoinProductNetwork.testnet4.networkKey,
        ].contains(networkKey)) {
      throw const FormatException('Invalid Bitcoin replacement observations');
    }
  }
  void requireOriginal(
    BitcoinProductNetwork network,
    String originalTxid,
    int expectedOutputs,
  ) {
    if (networkKey != network.networkKey ||
        txid != originalTxid ||
        outputCount != expectedOutputs ||
        !originalUnconfirmed ||
        hasDescendants) {
      throw StateError(
        'Bitcoin replacement is unavailable for this transaction',
      );
    }
  }

  @override
  String toString() => 'BitcoinReplacementObservation';
}
