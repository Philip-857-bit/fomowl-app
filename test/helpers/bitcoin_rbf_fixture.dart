import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/bitcoin_replacement_observation.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_saved_transaction.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_signing_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_account.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_memory_store.dart';

class RbfNetwork extends Fake
    implements BitcoinNetworkApi, BitcoinReplacementNetworkApi {
  bool supported = true;
  bool confirmed = false;
  bool descendants = false;
  bool wrongNetwork = false;
  bool wrongTxid = false;
  int relayRate = 1;
  int contextCalls = 0;
  int broadcasts = 0;
  Object? broadcastError;
  String? responseTxid;
  Future<String> Function(String raw)? accept;
  final outputCounts = <String, int>{};
  @override
  Future<bool> replacementAvailable(BitcoinProductNetwork network) async =>
      supported;
  @override
  Future<BitcoinReplacementObservation> fetchReplacementContext(
    BitcoinProductNetwork network,
    String txid,
  ) async {
    contextCalls++;
    return BitcoinReplacementObservation.fromJson({
      'networkKey': wrongNetwork
          ? (network == BitcoinProductNetwork.mainnet
                    ? BitcoinProductNetwork.testnet4
                    : BitcoinProductNetwork.mainnet)
                .networkKey
          : network.networkKey,
      'txid': wrongTxid ? 'ff' * 32 : txid,
      'originalUnconfirmed': !confirmed,
      'hasDescendants': descendants,
      'outputCount': outputCounts[txid] ?? 2,
      'incrementalRelayFeeSatVb': relayRate,
    });
  }

  @override
  Future<BitcoinFeeRates> fetchFeeRates(BitcoinProductNetwork network) async =>
      BitcoinFeeRates.fromJson({
        'economy': 2,
        'normal': 3,
        'priority': 7,
        'minimum': 1,
        'stale': false,
      });
  @override
  Future<String> broadcast(
    String walletIdentity,
    BitcoinProductNetwork network,
    String signedTransaction,
  ) async {
    broadcasts++;
    if (broadcastError != null) throw broadcastError!;
    if (responseTxid != null) return responseTxid!;
    return accept!(signedTransaction);
  }
}

class RbfFixture {
  static const identity = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final MemoryStore memory;
  final BitcoinAccountStore store;
  final BitcoinSigningService signing;
  final BitcoinSignedTransfer original;
  final RbfNetwork network;
  RbfFixture(
    this.memory,
    this.store,
    this.signing,
    this.original,
    this.network,
  );
  BitcoinSubmissionJournal get journal => BitcoinSubmissionJournal(store);
  BitcoinSavedTransaction get saved =>
      BitcoinSavedTransaction(original.transfer.plan, original.transaction);
  Future<String> acceptPlan(BitcoinTransactionPlanDto plan, String raw) async {
    final verified = await verifyBitcoinTransfer(
      plan: plan,
      rawTransactionHex: raw,
    );
    network.outputCounts[verified.txid] =
        plan.recipients.length + (plan.changeSat > BigInt.zero ? 1 : 0);
    return verified.txid;
  }
}

// Offline, unfunded outpoints and a published BIP-39 vector only.
Future<RbfFixture> rbfFixture({
  BitcoinPurpose purpose = BitcoinPurpose.bip84,
  BitcoinProductNetwork network = BitcoinProductNetwork.testnet4,
  int inputSats = 100000,
  int recipientSats = 10000,
  bool rbf = true,
}) async {
  const crypto = NativeBitcoinCrypto();
  final seed = await crypto.mnemonicToSeed(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
  );
  final key = Uint8List.fromList(List.filled(32, 7));
  final memory = MemoryStore();
  final store = BitcoinAccountStore(memory);
  late BitcoinHdAccountMetadata account;
  try {
    final sealed = await crypto.sealSeedAccount(seed, network, 0, purpose, key);
    account = sealed.metadata;
    final slot = BitcoinAccountSlot(
      walletIdentity: RbfFixture.identity,
      network: network,
      accountIndex: 0,
      purpose: purpose,
    );
    final record = ProtectedBitcoinRecord(
      walletIdentity: RbfFixture.identity,
      state: BitcoinPurposeAccountState(metadata: account),
      encryptedVault: sealed.encryptedVault,
      wrappingKey: Uint8List.fromList(key),
    );
    try {
      await store.createIfAbsent(slot, record);
    } finally {
      record.dispose();
    }
  } finally {
    seed.fillRange(0, seed.length, 0);
    key.fillRange(0, key.length, 0);
  }
  final recipient = await crypto.deriveAddress(
    account,
    BitcoinKeychain.receive,
    1,
  );
  final script = await crypto.deriveScript(account, BitcoinKeychain.receive, 0);
  final plan = await crypto.plan(
    account,
    [
      BitcoinUtxoDto(
        txid: '11' * 32,
        vout: 0,
        valueSat: BigInt.from(inputSats),
        scriptPubkeyHex: script,
        keychain: BitcoinKeychainDto.external_,
        addressIndex: 0,
      ),
    ],
    [
      BitcoinRecipientDto(
        address: recipient,
        amountSat: BigInt.from(recipientSats),
      ),
    ],
    BigInt.one,
    0,
    rbf,
  );
  final prepared = BitcoinPreparedTransfer(
    walletIdentity: RbfFixture.identity,
    network: network,
    purpose: purpose,
    plan: plan,
  );
  WalletVaultService.unlock();
  final signing = BitcoinSigningService(store: store);
  final signed = await signing.sign(
    prepared,
    authenticate: () async => true,
    isCurrent: () => true,
  );
  final journal = BitcoinSubmissionJournal(store);
  final reservation = await journal.reserveAttempt(
    RbfFixture.identity,
    network,
    signed.transaction.txid,
    plan.selectedUtxos,
    transaction: BitcoinSavedTransaction(plan, signed.transaction),
  );
  journal.retainPending(reservation!);
  final provider = RbfNetwork();
  provider.outputCounts[signed.transaction.txid] =
      plan.recipients.length + (plan.changeSat > BigInt.zero ? 1 : 0);
  return RbfFixture(memory, store, signing, signed, provider);
}
