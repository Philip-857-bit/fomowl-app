import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_reconciliation_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_wallet_service.dart';
import 'bitcoin_discovery_service_test.dart'
    show initialize, PublicCrypto, ActivityNetwork;
import 'bitcoin_submission_journal_test.dart' show input;
import 'bitcoin_submission_reconciliation_test.dart'
    show StatusNetwork, confirmed;
import 'helpers/bitcoin_memory_store.dart';

class WalletStorage extends Fake implements StorageService {
  @override
  final BitcoinAccountStore bitcoinAccounts;
  WalletStorage(this.bitcoinAccounts);
  @override
  Future<List<WalletAccount>> getWalletAccounts() async => [
    WalletAccount(
      address: '0xwallet',
      name: 'Seed wallet',
      origin: WalletOrigin.derived,
      derivationIndex: 0,
      supportsBitcoin: true,
      createdAt: DateTime.utc(2026),
    ),
  ];
}

class WalletNetwork extends StatusNetwork {
  @override
  Future<List<BitcoinAddressActivity>> fetchAccountState(
    String identity,
    BitcoinProductNetwork network,
    List<String> addresses,
  ) => ActivityNetwork(
    (_) => false,
  ).fetchAccountState(identity, network, addresses);
}

void main() {
  for (final invalidate in [false, true]) {
    test(
      'real wallet refresh starts non-blocking reconciliation; invalidated=$invalidate',
      () async {
        final store = BitcoinAccountStore(MemoryStore());
        await initialize(store);
        final journal = BitcoinSubmissionJournal(store);
        await journal.reserve(
          '0xwallet',
          BitcoinProductNetwork.mainnet,
          '33' * 32,
          [input()],
        );
        final network = WalletNetwork()..gate = Completer();
        final wallet = BitcoinWalletService(
          storage: WalletStorage(store),
          crypto: PublicCrypto(),
          network: network,
        );
        final snapshot = await wallet.refresh(
          '0xwallet',
          BitcoinProductNetwork.mainnet,
          force: true,
        );
        expect(snapshot.totalSats, BigInt.zero);
        await network.started.future;
        expect(
          await journal.reserved('0xwallet', BitcoinProductNetwork.mainnet),
          {'${'11' * 32}:0'},
        );
        if (invalidate) {
          wallet.invalidate('0xwallet', BitcoinProductNetwork.mainnet);
        }
        final background =
            BitcoinSubmissionReconciliationService(
              journal: journal,
              network: network,
            ).reconcile(
              '0xwallet',
              BitcoinProductNetwork.mainnet,
              isCurrent: () => true,
            );
        network.gate!.complete(confirmed());
        expect(await background, invalidate ? 0 : 1);
        expect(
          await journal.reserved('0xwallet', BitcoinProductNetwork.mainnet),
          invalidate ? {'${'11' * 32}:0'} : isEmpty,
        );
      },
    );
  }
}
