import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_discovery.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/bitcoin_wallet_balance.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_history_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_wallet_service.dart';
import 'package:fomowl_wallet/services/wallet_history_service.dart';

const owner = '0xwallet';
String address(int index) => 'bc1q_fixture_$index';
String get hash => List.filled(64, '1').join();
BitcoinWalletSnapshot snapshot() {
  final account = BitcoinHdAccountMetadata(
    network: BitcoinProductNetwork.mainnet,
    purpose: BitcoinPurpose.bip84,
    accountIndex: 0,
    masterFingerprint: '73c5da0a',
    accountXpub: 'xpub-public-fixture',
  );
  return BitcoinWalletSnapshot(
    BitcoinDiscoverySnapshot(
      state: BitcoinWalletAccountState(
        walletIdentity: owner,
        network: account.network,
        accountIndex: 0,
        accounts: {
          BitcoinPurpose.bip84: BitcoinPurposeAccountState(metadata: account),
        },
      ),
      ownership: {
        for (var i = 0; i < 41; i++)
          address(i): BitcoinDerivedAddress(
            account: account,
            keychain: BitcoinKeychain.receive,
            addressIndex: i,
            address: address(i),
          ),
      },
      activity: {},
      scannedAt: DateTime.utc(2026, 1, 1),
    ),
  );
}

class HistoryWallet extends Fake implements BitcoinWalletApi {
  @override
  Future<BitcoinWalletSnapshot> refresh(
    String identity,
    BitcoinProductNetwork network, {
    bool force = false,
    bool Function()? isCurrent,
  }) async => snapshot();
}

class LocalHistory extends Fake implements WalletHistoryService {
  List<WalletHistoryEntry> entries = [];
  @override
  Future<WalletHistoryResponse> fetchWalletHistory({
    required String walletAddress,
    int? chainId,
    String type = 'all',
    int limit = 100,
  }) async => WalletHistoryResponse(history: entries, partial: false);
}

Map<String, dynamic> row(List<String> batch, {bool conflicting = false}) {
  final ownsInput = batch.contains(address(40));
  final ownsChange = batch.contains(address(0));
  final delta = (ownsChange ? 60 : 0) - (ownsInput ? 100 : 0);
  return {
    'txid': hash,
    'timestamp': 100,
    'confirmations': 0,
    'ownedInputs': [
      if (ownsInput) {'address': address(40), 'valueSats': 100},
    ],
    'ownedOutputs': [
      if (ownsChange) ...[
        {'address': address(0), 'valueSats': 30},
        {'address': address(0), 'valueSats': 30},
      ],
    ],
    'inputs': [
      {'position': 0, 'address': address(40), 'valueSats': 100},
    ],
    'outputs': [
      {'position': 0, 'address': address(0), 'valueSats': 30},
      {'position': 1, 'address': address(0), 'valueSats': 30},
      {'position': 2, 'address': 'foreign', 'valueSats': conflicting ? 29 : 30},
    ],
    'netWalletDeltaSats': delta,
    'feeSats': conflicting ? 11 : 10,
    'direction': delta < 0
        ? 'outgoing'
        : delta > 0
        ? 'incoming'
        : 'self',
  };
}

class HistoryNetwork extends Fake implements BitcoinNetworkApi {
  int calls = 0;
  bool duplicate = false;
  bool conflicting = false;
  @override
  Future<BitcoinHistoryBatch> fetchAccountHistory(
    String identity,
    BitcoinProductNetwork network,
    List<String> addresses, {
    int limit = 100,
  }) async {
    expect(identity, owner);
    expect(addresses.length, lessThanOrEqualTo(40));
    expect(addresses.any((value) => value.contains('xpub')), isFalse);
    calls++;
    return BitcoinHistoryBatch(
      network,
      calls == 1 || duplicate
          ? [
              BitcoinHistoryTransaction.fromJson(
                row(addresses, conflicting: calls > 1 && conflicting),
              ),
            ]
          : [],
      false,
    );
  }
}

class ResolvedReceipt extends Fake implements BitcoinResolvedSubmission {
  @override
  final String txid;
  ResolvedReceipt(this.txid);
}

class ResolvedJournal extends Fake implements BitcoinSubmissionJournal {
  final Map<String, BitcoinResolvedSubmission> aliases;
  ResolvedJournal(this.aliases);
  @override
  Future<Map<String, BitcoinResolvedSubmission>> resolvedAliases(
    String identity,
    BitcoinProductNetwork network,
  ) async => aliases;
  @override
  Future<List<BitcoinPendingSubmission>> pending(
    String identity,
    BitcoinProductNetwork network,
  ) async => [];
}

void main() {
  test(
    'full local ownership includes change outside the batch that returned the transaction',
    () async {
      final network = HistoryNetwork();
      final result = await BitcoinHistoryService(
        wallet: HistoryWallet(),
        network: network,
        local: LocalHistory(),
      ).fetch(owner, BitcoinProductNetwork.mainnet);
      expect(network.calls, 2);
      expect(result.history, hasLength(1));
      final entry = result.history.single;
      expect(entry.walletAddress, owner);
      expect(entry.networkKey, 'bitcoin:mainnet');
      expect(entry.bitcoin!.deltaSats, BigInt.from(-40));
      expect(entry.bitcoin!.ownedOutputs, hasLength(2));
      expect(result.partial, isFalse);
    },
  );
  test(
    'deduplicates identical txids across batches and merges local events by stable identity',
    () async {
      final network = HistoryNetwork()..duplicate = true;
      final local = LocalHistory()
        ..entries = [
          WalletHistoryEntry(
            id: 'local',
            walletAddress: owner,
            networkName: 'Bitcoin',
            eventType: 'send',
            title: 'Submitted',
            message: '',
            isIncoming: false,
            createdAt: DateTime.utc(2026),
            source: 'local_history',
            txHash: hash,
            networkKey: 'bitcoin:mainnet',
          ),
        ];
      final result = await BitcoinHistoryService(
        wallet: HistoryWallet(),
        network: network,
        local: local,
      ).fetch(owner, BitcoinProductNetwork.mainnet);
      expect(result.history, hasLength(1));
      expect(result.history.single.source, 'bitcoin-chain');
      expect(result.history.single.bitcoin!.deltaSats, BigInt.from(-40));
    },
  );
  test('rejects conflicting transaction data for the same txid', () async {
    final network = HistoryNetwork()
      ..duplicate = true
      ..conflicting = true;
    await expectLater(
      BitcoinHistoryService(
        wallet: HistoryWallet(),
        network: network,
        local: LocalHistory(),
      ).fetch(owner, BitcoinProductNetwork.mainnet),
      throwsFormatException,
    );
  });
  test(
    'bounded query window is explicitly partial while ownership still uses all known addresses',
    () async {
      final network = HistoryNetwork();
      final result = await BitcoinHistoryService(
        wallet: HistoryWallet(),
        network: network,
        local: LocalHistory(),
        maximumQueriedAddresses: 40,
      ).fetch(owner, BitcoinProductNetwork.mainnet);
      expect(network.calls, 1);
      expect(result.partial, isTrue);
      expect(result.history.single.bitcoin!.deltaSats, BigInt.from(-40));
    },
  );
  test('rejects missing full observations and duplicate output positions', () {
    final malformed = row([address(40)]);
    malformed.remove('outputs');
    expect(
      () => BitcoinHistoryTransaction.fromJson(malformed),
      throwsFormatException,
    );
    final duplicate = row([address(40)]);
    (duplicate['outputs'] as List)[1]['position'] = 0;
    expect(
      () => BitcoinHistoryTransaction.fromJson(duplicate),
      throwsFormatException,
    );
  });
  for (final providerStillReportsOriginal in [false, true]) {
    test(
      'confirmed replacement archive filters only local stale events; fresh provider original=$providerStillReportsOriginal',
      () async {
        final old = providerStillReportsOriginal ? hash : '22' * 32;
        final local = LocalHistory()
          ..entries = [
            WalletHistoryEntry(
              id: 'old-submission',
              walletAddress: owner,
              networkName: 'Bitcoin',
              eventType: 'send',
              title: 'Submitted',
              message: '',
              isIncoming: false,
              createdAt: DateTime.utc(2026),
              source: 'local_history',
              txHash: old,
              networkKey: 'bitcoin:mainnet',
            ),
          ];
        final result = await BitcoinHistoryService(
          wallet: HistoryWallet(),
          network: HistoryNetwork(),
          local: local,
          journal: ResolvedJournal({old: ResolvedReceipt('33' * 32)}),
        ).fetch(owner, BitcoinProductNetwork.mainnet);
        expect(result.history, hasLength(1));
        expect(result.history.single.txHash, hash);
        expect(result.history.single.source, 'bitcoin-chain');
        expect(result.partial, isFalse);
      },
    );
  }
}
