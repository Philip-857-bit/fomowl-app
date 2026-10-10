import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../models/bitcoin_wallet_balance.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_address_allocator.dart';
import 'bitcoin_protected_record.dart';
import '../storage_service.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_wallet_service.dart';
import 'bitcoin_submission_journal.dart';

class BitcoinSplitFundsException implements Exception {
  const BitcoinSplitFundsException();
  @override
  String toString() =>
      'Funds are split across Native SegWit and Taproot. One address format must cover the amount and network fee.';
}

class BitcoinPreparedTransfer {
  final String walletIdentity;
  final BitcoinProductNetwork network;
  final BitcoinPurpose purpose;
  final BitcoinTransactionPlanDto plan;

  /// Friendly presentation only; neither field overrides the verified plan.
  final BitcoinFeeTier requestedFeeTier;
  final bool showFeeTier;
  BitcoinPreparedTransfer({
    required this.walletIdentity,
    required this.network,
    required this.purpose,
    required BitcoinTransactionPlanDto plan,
    this.requestedFeeTier = BitcoinFeeTier.normal,
    this.showFeeTier = false,
  }) : plan = BitcoinTransactionPlanDto(
         account: plan.account,
         unsignedTxHex: plan.unsignedTxHex,
         selectedUtxos: List.unmodifiable(plan.selectedUtxos),
         recipients: List.unmodifiable(plan.recipients),
         changeIndex: plan.changeIndex,
         rbf: plan.rbf,
         feeRateSatVb: plan.feeRateSatVb,
         recipientTotalSat: plan.recipientTotalSat,
         changeSat: plan.changeSat,
         feeSat: plan.feeSat,
         estimatedVbytes: plan.estimatedVbytes,
       );
}

class BitcoinSendService {
  final BitcoinWalletApi wallet;
  final BitcoinNetworkApi network;
  final BitcoinCryptoApi crypto;
  final BitcoinAccountStore store;
  BitcoinSendService({
    BitcoinWalletApi? wallet,
    BitcoinNetworkApi? network,
    BitcoinCryptoApi? crypto,
    BitcoinAccountStore? store,
  }) : wallet = wallet ?? BitcoinWalletService(),
       network = network ?? BitcoinNetworkService(),
       crypto = crypto ?? const NativeBitcoinCrypto(),
       store = store ?? StorageService().bitcoinAccounts;

  Future<List<BitcoinUtxoDto>> ownedInputs(
    BitcoinWalletSnapshot snapshot,
    BitcoinPurpose purpose, {
    Set<String> reserved = const {},
  }) async {
    final inputs = <BitcoinUtxoDto>[];
    final outpoints = <String>{};
    for (final utxo in snapshot.discovery.utxos) {
      if (!outpoints.add(utxo.outpoint)) {
        throw StateError('Duplicate Bitcoin outpoint');
      }
      if (reserved.contains(utxo.outpoint)) continue;
      final owner = snapshot.discovery.ownership[utxo.address];
      if (owner == null) throw StateError('Unknown Bitcoin UTXO ownership');
      if (snapshot.discovery.state.accounts[owner.account.purpose]?.metadata !=
          owner.account) {
        throw StateError('Bitcoin UTXO account identity mismatch');
      }
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

  Future<BitcoinPurpose> selectPurpose(
    BitcoinWalletSnapshot snapshot,
    String recipient,
    BigInt amount,
    BigInt feeRate, {
    bool rbf = true,
    bool Function()? isCurrent,
    Set<String> reserved = const {},
  }) async {
    var fundedFormats = 0;
    var total = BigInt.zero;
    for (final purpose in BitcoinPurpose.values) {
      final state = snapshot.discovery.state.accounts[purpose];
      if (state == null) continue;
      final inputs = await ownedInputs(snapshot, purpose, reserved: reserved);
      if (inputs.isEmpty) continue;
      fundedFormats++;
      total += inputs.fold(BigInt.zero, (sum, input) => sum + input.valueSat);
      if (isCurrent?.call() == false) {
        throw StateError('Bitcoin wallet context changed');
      }
      try {
        await crypto.plan(
          state.metadata,
          inputs,
          [BitcoinRecipientDto(address: recipient, amountSat: amount)],
          feeRate,
          state.nextInternal,
          rbf,
        );
        if (isCurrent?.call() == false) {
          throw StateError('Bitcoin wallet context changed');
        }
        return purpose;
      } catch (error) {
        if (error != 'Insufficient Bitcoin funds') rethrow;
      }
    }
    if (fundedFormats > 1 && total >= amount) {
      throw const BitcoinSplitFundsException();
    }
    throw StateError('Insufficient Bitcoin funds including network fee');
  }

  Future<BitcoinPreparedTransfer> prepareTransfer(
    String identity,
    BitcoinProductNetwork productNetwork,
    String recipient,
    BigInt amount, {
    BitcoinPurpose? purpose,
    BitcoinFeeTier feeTier = BitcoinFeeTier.normal,
    bool feeTierWasSelected = false,
    bool rbf = true,
    bool Function()? isCurrent,
  }) async {
    void check() {
      if (isCurrent?.call() == false) {
        throw StateError('Bitcoin wallet context changed');
      }
    }

    check();
    final snapshot = await wallet.refresh(
      identity,
      productNetwork,
      force: true,
      isCurrent: isCurrent,
    );
    final state = snapshot.discovery.state;
    if (state.walletIdentity.toLowerCase() != identity.toLowerCase() ||
        state.network != productNetwork) {
      throw StateError('Bitcoin account identity mismatch');
    }
    final fees = await network.fetchFeeRates(productNetwork);
    final reserved = await BitcoinSubmissionJournal(
      store,
    ).reserved(identity, productNetwork);
    check();
    final selectedPurpose =
        purpose ??
        await selectPurpose(
          snapshot,
          recipient,
          amount,
          fees.rate(feeTier),
          rbf: rbf,
          isCurrent: isCurrent,
          reserved: reserved,
        );
    final account = state.accounts[selectedPurpose]?.metadata;
    if (account == null) {
      throw StateError('Bitcoin address format is unavailable');
    }
    final inputs = await ownedInputs(
      snapshot,
      selectedPurpose,
      reserved: reserved,
    );
    check();
    final change = await BitcoinAddressAllocator(store: store, crypto: crypto)
        .reserveChange(
          BitcoinAccountSlot(
            walletIdentity: identity,
            network: productNetwork,
            accountIndex: state.accountIndex,
            purpose: selectedPurpose,
          ),
        );
    if (change.account != account) {
      throw StateError('Bitcoin change account identity mismatch');
    }
    check();
    final plan = await crypto.plan(
      account,
      inputs,
      [BitcoinRecipientDto(address: recipient, amountSat: amount)],
      fees.rate(feeTier),
      change.addressIndex,
      rbf,
    );
    check();
    return BitcoinPreparedTransfer(
      walletIdentity: identity,
      network: productNetwork,
      purpose: selectedPurpose,
      plan: plan,
      requestedFeeTier: feeTier,
      showFeeTier: feeTierWasSelected && fees.hasDistinctTiers,
    );
  }

  /// Ask the SDK for fundable amounts. This does not implement fees, dust or weight rules.
  Future<BigInt> maximumAmount(
    String identity,
    BitcoinProductNetwork productNetwork,
    String recipient, {
    BitcoinFeeTier feeTier = BitcoinFeeTier.normal,
    bool Function()? isCurrent,
  }) async {
    final snapshot = await wallet.refresh(
      identity,
      productNetwork,
      force: true,
      isCurrent: isCurrent,
    );
    final fees = await network.fetchFeeRates(productNetwork);
    final reserved = await BitcoinSubmissionJournal(
      store,
    ).reserved(identity, productNetwork);
    for (final purpose in BitcoinPurpose.values) {
      final state = snapshot.discovery.state.accounts[purpose];
      if (state == null) continue;
      final inputs = await ownedInputs(snapshot, purpose, reserved: reserved);
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
            fees.rate(feeTier),
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
