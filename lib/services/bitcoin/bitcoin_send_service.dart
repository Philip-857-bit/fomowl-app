import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../models/bitcoin_wallet_balance.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_wallet_service.dart';

class BitcoinSendService {
  final BitcoinWalletApi wallet;
  final BitcoinNetworkApi network;
  final BitcoinCryptoApi crypto;
  BitcoinSendService({
    BitcoinWalletApi? wallet,
    BitcoinNetworkApi? network,
    BitcoinCryptoApi? crypto,
  }) : wallet = wallet ?? BitcoinWalletService(),
       network = network ?? BitcoinNetworkService(),
       crypto = crypto ?? const NativeBitcoinCrypto();

  Future<List<BitcoinUtxoDto>> ownedInputs(
    BitcoinWalletSnapshot snapshot,
    BitcoinPurpose purpose,
  ) async {
    final inputs = <BitcoinUtxoDto>[];
    final outpoints = <String>{};
    for (final utxo in snapshot.discovery.utxos) {
      if (!outpoints.add(utxo.outpoint)) {
        throw StateError('Duplicate Bitcoin outpoint');
      }
      final owner = snapshot.discovery.ownership[utxo.address];
      if (owner == null) throw StateError('Unknown Bitcoin UTXO ownership');
      if (owner.account.purpose != purpose) continue;
      final script = await crypto.deriveScript(
        owner.account,
        owner.keychain,
        owner.addressIndex,
      );
      if (script.toLowerCase() != utxo.scriptPubkeyHex.toLowerCase()) {
        throw StateError('Bitcoin UTXO ownership mismatch');
      }
      inputs.add(
        BitcoinUtxoDto(
          txid: utxo.txid,
          vout: utxo.vout,
          valueSat: utxo.valueSats,
          scriptPubkeyHex: script,
          keychain: NativeBitcoinCrypto.keychainDto(owner.keychain),
          addressIndex: owner.addressIndex,
        ),
      );
    }
    return inputs;
  }

  /// Ask the SDK for fundable amounts. This does not implement fees, dust or weight rules.
  Future<BigInt> maximumAmount(
    String identity,
    BitcoinProductNetwork productNetwork,
    String recipient, {
    bool Function()? isCurrent,
  }) async {
    final snapshot = await wallet.refresh(
      identity,
      productNetwork,
      force: true,
      isCurrent: isCurrent,
    );
    final fees = await network.fetchFeeRates(productNetwork);
    for (final purpose in BitcoinPurpose.values) {
      final state = snapshot.discovery.state.accounts[purpose];
      if (state == null) continue;
      final inputs = await ownedInputs(snapshot, purpose);
      final available = inputs.fold(
        BigInt.zero,
        (sum, input) => sum + input.valueSat,
      );
      if (available == BigInt.zero) continue;
      Future<BitcoinTransactionPlanDto?> probe(BigInt amount) async {
        if (isCurrent?.call() == false) {
          throw StateError('Bitcoin wallet context changed');
        }
        try {
          return await crypto.plan(
            state.metadata,
            inputs,
            [BitcoinRecipientDto(address: recipient, amountSat: amount)],
            fees.rate(BitcoinFeeTier.normal),
            state.nextInternal,
            true,
          );
        } catch (error) {
          if (error != 'Insufficient Bitcoin funds') rethrow;
          return null;
        }
      }

      var lower = BigInt.one;
      var upper = available;
      BigInt? maximum;
      // Ask the SDK on each probe. Dust is the lower boundary; insufficient
      // funds is the upper boundary. No consensus threshold is copied here.
      while (lower <= upper) {
        final middle = (lower + upper) >> 1;
        BitcoinTransactionPlanDto? plan;
        try {
          plan = await probe(middle);
        } catch (error) {
          if (error != 'Dust Bitcoin recipient') rethrow;
          lower = middle + BigInt.one;
          continue;
        }
        if (plan == null) {
          upper = middle - BigInt.one;
        } else {
          maximum = middle;
          lower = middle + BigInt.one;
        }
      }
      if (maximum == null) continue;
      if (isCurrent?.call() == false) {
        throw StateError('Bitcoin wallet context changed');
      }
      return maximum;
    }
    throw StateError('Insufficient Bitcoin funds including network fee');
  }
}
