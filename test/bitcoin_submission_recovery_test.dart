import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_discovery.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/bitcoin_wallet_balance.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_recovery_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_wallet_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_wallet_vault_service.dart';
import 'helpers/bitcoin_memory_store.dart';
import 'bitcoin_submission_journal_test.dart' show input;

const identity = '0xwallet';
final txid = '33' * 32;
final point = '${'11' * 32}:0';
final script = '0014${'22' * 20}';

class RecoveryNetwork extends Fake implements BitcoinNetworkApi {
  Completer<void>? gate;
  int calls = 0;
  bool found = false;
  bool outage = false;
  bool appearsOnSecondCheck = false;
  @override
  Future<BitcoinTransactionStatus> fetchTransactionStatus(
    BitcoinProductNetwork network,
    String requested,
  ) async {
    expect(requested, txid);
    calls++;
    await gate?.future;
    if (outage) throw const BitcoinNetworkException(503);
    return BitcoinTransactionStatus.fromJson({
      'status': 'pending',
      'confirmed': false,
      'confirmations': 0,
      'found': found || appearsOnSecondCheck && calls > 1,
      'blockHeight': null,
      'blockHash': null,
      'timestamp': null,
    });
  }
}

class RecoveryCrypto extends Fake implements BitcoinCryptoApi {
  int calls = 0;
  String result = script;
  @override
  Future<String> deriveScript(
    BitcoinHdAccountMetadata account,
    BitcoinKeychain keychain,
    int index,
  ) async {
    calls++;
    return result;
  }
}

class RecoveryWallet extends Fake implements BitcoinWalletApi {
  int calls = 0;
  bool spent = false;
  bool confirmed = true;
  Future<void> Function()? onRefresh;
  @override
  Future<BitcoinWalletSnapshot> refresh(
    String requested,
    BitcoinProductNetwork network, {
    bool force = false,
    bool Function()? isCurrent,
  }) async {
    calls++;
    expect(force, isTrue);
    expect(requested, identity);
    await onRefresh?.call();
    final account = BitcoinHdAccountMetadata(
      network: network,
      purpose: BitcoinPurpose.bip84,
      accountIndex: 0,
      masterFingerprint: '73c5da0a',
      accountXpub: network == BitcoinProductNetwork.mainnet
          ? 'xpub-public-fixture'
          : 'tpub-public-fixture',
    );
    const address = 'tb1q_public_fixture';
    return BitcoinWalletSnapshot(
      BitcoinDiscoverySnapshot(
        state: BitcoinWalletAccountState(
          walletIdentity: identity,
          network: network,
          accountIndex: 0,
          accounts: {
            BitcoinPurpose.bip84: BitcoinPurposeAccountState(metadata: account),
          },
        ),
        ownership: {
          address: BitcoinDerivedAddress(
            account: account,
            keychain: BitcoinKeychain.receive,
            addressIndex: 0,
            address: address,
          ),
        },
        activity: {
          address: BitcoinAddressActivity.fromJson({
            'address': address,
            'used': true,
            'txCount': 1,
            'confirmedBalanceSats': 10000,
            'mempoolBalanceSats': 0,
            'utxos': [
              if (!spent)
                {
                  'txid': '11' * 32,
                  'vout': 0,
                  'valueSats': 10000,
                  'address': address,
                  'scriptPubkeyHex': script,
                  'confirmed': confirmed,
                  'blockHeight': confirmed ? 1 : null,
                },
            ],
          }),
        },
        scannedAt: DateTime.utc(2026),
      ),
    );
  }
}

class RecoveryFixture {
  final MemoryStore memory = MemoryStore();
  final RecoveryNetwork network = RecoveryNetwork();
  final RecoveryWallet wallet = RecoveryWallet();
  final RecoveryCrypto crypto = RecoveryCrypto();
  late final BitcoinSubmissionJournal journal;
  RecoveryFixture({
    bool enabled = true,
    BitcoinProductNetwork network = BitcoinProductNetwork.testnet4,
  }) {
    memory.values['bitcoin_submission_v1_$identity'] = jsonEncode({
      'version': 1,
      'identity': identity,
      'entries': {
        '${network.id}|$txid': [point],
      },
    });
    journal = BitcoinSubmissionJournal(
      BitcoinAccountStore(memory),
      internalTestnetRecovery: enabled,
    );
  }
  BitcoinSubmissionRecoveryService get service =>
      BitcoinSubmissionRecoveryService(
        journal: journal,
        network: network,
        wallet: wallet,
        crypto: crypto,
      );
  Future<BitcoinPendingSubmission> entry([
    BitcoinProductNetwork network = BitcoinProductNetwork.testnet4,
  ]) async => (await journal.pending(identity, network)).single;
  Future<bool> recover({
    bool acknowledged = true,
    bool authenticated = true,
    bool Function()? current,
  }) async => service.recover(
    await entry(),
    acknowledgedPreBroadcastRejection: acknowledged,
    authenticate: () async => authenticated,
    isCurrent: current ?? () => true,
  );
}

void main() {
  setUp(BitcoinWalletVaultService.unlock);
  tearDown(BitcoinWalletVaultService.lockAll);
  test(
    'exact legacy recovery migrates schema and stale snapshot cannot clear a later attempt',
    () async {
      final value = RecoveryFixture();
      final before = await value.entry();
      expect(before.legacy, isTrue);
      expect(before.inputs, [point]);
      expect(() => before.inputs.clear(), throwsUnsupportedError);
      expect(await value.recover(), isTrue);
      expect(value.network.calls, 2);
      expect(
        await value.journal.reserved(identity, BitcoinProductNetwork.testnet4),
        isEmpty,
      );
      expect(jsonDecode(value.memory.values.values.single)['version'], 3);
      await value.journal.reserve(
        identity,
        BitcoinProductNetwork.testnet4,
        txid,
        [input()],
      );
      expect((await value.entry()).legacy, isFalse);
      await expectLater(
        value.service.recover(
          before,
          acknowledgedPreBroadcastRejection: true,
          authenticate: () async => true,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(
        await value.journal.reserved(identity, BitcoinProductNetwork.testnet4),
        {point},
      );
    },
  );
  for (final condition in [
    'production',
    'no-ack',
    'cancel-auth',
    'found',
    'outage',
    'spent',
    'unconfirmed',
    'script',
    'appeared',
    'locked',
    'wallet-switch',
    'write-failed',
  ]) {
    test('$condition never clears the reservation', () async {
      final value = RecoveryFixture(enabled: condition != 'production');
      var current = true;
      if (condition == 'found') value.network.found = true;
      if (condition == 'outage') value.network.outage = true;
      if (condition == 'spent') value.wallet.spent = true;
      if (condition == 'unconfirmed') value.wallet.confirmed = false;
      if (condition == 'script') value.crypto.result = '0014${'44' * 20}';
      if (condition == 'appeared') value.network.appearsOnSecondCheck = true;
      if (condition == 'locked') {
        value.wallet.onRefresh = BitcoinWalletVaultService.lockAll;
      }
      if (condition == 'write-failed') value.memory.dropWrites = true;
      if (condition == 'wallet-switch') {
        value.wallet.onRefresh = () async {
          current = false;
        };
      }
      await expectLater(
        value.recover(
          acknowledged: condition != 'no-ack',
          authenticated: condition != 'cancel-auth',
          current: () => current,
        ),
        throwsA(anything),
      );
      if ([
        'spent',
        'unconfirmed',
        'script',
        'appeared',
        'write-failed',
      ].contains(condition)) {
        expect(value.wallet.calls, 1);
      }
      if (['script', 'appeared', 'write-failed'].contains(condition)) {
        expect(value.crypto.calls, 1);
      }
      if (['appeared', 'write-failed'].contains(condition)) {
        expect(value.network.calls, 2);
      }
      expect(
        await value.journal.reserved(identity, BitcoinProductNetwork.testnet4),
        {point},
      );
    });
  }
  test(
    'migration and exact release preserve other transactions and networks',
    () async {
      final value = RecoveryFixture();
      final other = '${'22' * 32}:1';
      final main = '${'66' * 32}:2';
      value.memory.values['bitcoin_submission_v1_$identity'] = jsonEncode({
        'version': 1,
        'identity': identity,
        'entries': {
          'testnet4|$txid': [point],
          'testnet4|${'44' * 32}': [other],
          'mainnet|${'55' * 32}': [main],
        },
      });
      final selected = (await value.journal.pending(
        identity,
        BitcoinProductNetwork.testnet4,
      )).singleWhere((entry) => entry.txid == txid);
      await value.service.recover(
        selected,
        acknowledgedPreBroadcastRejection: true,
        authenticate: () async => true,
        isCurrent: () => true,
      );
      expect(
        await value.journal.reserved(identity, BitcoinProductNetwork.testnet4),
        {other},
      );
      expect(
        await value.journal.reserved(identity, BitcoinProductNetwork.mainnet),
        {main},
      );
    },
  );
  test('corrupt v2 legacy metadata fails closed', () async {
    final value = RecoveryFixture();
    value.memory.values['bitcoin_submission_v1_$identity'] = jsonEncode({
      'version': 2,
      'identity': identity,
      'entries': {
        'testnet4|$txid': [point],
      },
      'legacyEntries': ['testnet4|${'44' * 32}'],
    });
    await expectLater(
      value.journal.pending(identity, BitcoinProductNetwork.testnet4),
      throwsFormatException,
    );
  });
  test(
    'mainnet, foreign storage and revoked authorization cannot use manual recovery',
    () async {
      final mainnet = RecoveryFixture(network: BitcoinProductNetwork.mainnet);
      await expectLater(
        mainnet.service.recover(
          await mainnet.entry(BitcoinProductNetwork.mainnet),
          acknowledgedPreBroadcastRejection: true,
          authenticate: () async => true,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      final first = RecoveryFixture();
      final foreign = RecoveryFixture();
      await expectLater(
        first.journal.recoverLegacyTestnet4(
          await foreign.entry(),
          checkAuthorization: () {},
        ),
        throwsStateError,
      );
      await expectLater(
        first.journal.recoverLegacyTestnet4(
          await first.entry(),
          checkAuthorization: () => throw StateError('revoked'),
        ),
        throwsStateError,
      );
      expect(
        await first.journal.reserved(identity, BitcoinProductNetwork.testnet4),
        {point},
      );
    },
  );
}
