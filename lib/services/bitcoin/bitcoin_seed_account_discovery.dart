import 'dart:typed_data';
import '../../models/bitcoin_account_state.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_wallet_vault_service.dart';

abstract interface class BitcoinSeedDiscoveryApi {
  Future<bool> hasActivity(
    Uint8List seed,
    String authenticationIdentity,
    int accountIndex,
  );
}

/// Public discovery only. Hardened account derivation and child addresses come from the SDK.
class BitcoinSeedAccountDiscovery implements BitcoinSeedDiscoveryApi {
  final BitcoinCryptoApi crypto;
  final BitcoinNetworkApi network;
  BitcoinSeedAccountDiscovery({
    BitcoinCryptoApi? crypto,
    BitcoinNetworkApi? network,
  }) : crypto = crypto ?? const NativeBitcoinCrypto(),
       network = network ?? BitcoinNetworkService();
  @override
  Future<bool> hasActivity(
    Uint8List seed,
    String authenticationIdentity,
    int accountIndex,
  ) async {
    if (accountIndex < 0 || accountIndex >= 20) {
      throw ArgumentError('Bitcoin seed recovery account limit exceeded');
    }
    final generation = BitcoinWalletVaultService.beginOperation();
    final addresses = <String>[];
    for (final purpose in BitcoinPurpose.values) {
      final account = await crypto.deriveAccount(
        seed,
        BitcoinProductNetwork.mainnet,
        accountIndex,
        purpose,
      );
      for (var index = 0; index < 20; index++) {
        addresses.add(
          await crypto.deriveAddress(account, BitcoinKeychain.receive, index),
        );
      }
      BitcoinWalletVaultService.checkOperation(generation);
    }
    final rows = await network.fetchAccountState(
      authenticationIdentity,
      BitcoinProductNetwork.mainnet,
      addresses,
    );
    BitcoinWalletVaultService.checkOperation(generation);
    if (rows.length != addresses.length ||
        rows.map((row) => row.address).toSet().length != addresses.length ||
        rows.any((row) => !addresses.contains(row.address))) {
      throw StateError('Incomplete Bitcoin seed account discovery');
    }
    return rows.any((row) => row.used);
  }
}
