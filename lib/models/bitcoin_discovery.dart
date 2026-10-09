import 'bitcoin_account_state.dart';
import 'bitcoin_network_data.dart';

class BitcoinDerivedAddress {
  final BitcoinHdAccountMetadata account;
  final BitcoinKeychain keychain;
  final int addressIndex;
  final String address;
  const BitcoinDerivedAddress({
    required this.account,
    required this.keychain,
    required this.addressIndex,
    required this.address,
  });
}

class BitcoinDiscoverySnapshot {
  final BitcoinWalletAccountState state;
  final Map<String, BitcoinDerivedAddress> ownership;
  final Map<String, BitcoinAddressActivity> activity;
  final DateTime scannedAt;
  BitcoinDiscoverySnapshot({
    required this.state,
    required Map<String, BitcoinDerivedAddress> ownership,
    required Map<String, BitcoinAddressActivity> activity,
    required this.scannedAt,
  }) : ownership = Map.unmodifiable(ownership),
       activity = Map.unmodifiable(activity);
  List<BitcoinNetworkUtxo> get utxos =>
      List.unmodifiable(activity.values.expand((address) => address.utxos));
}
