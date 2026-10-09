@Tags(['ffi'])
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_broadcast_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/bitcoin_signed_fixture.dart';

class BroadcastNetwork extends Fake implements BitcoinNetworkApi {
  final String hash;
  Object? error;
  int calls = 0;
  String? raw;
  BroadcastNetwork(this.hash);
  @override
  Future<String> broadcast(
    String identity,
    BitcoinProductNetwork network,
    String transaction,
  ) async {
    expect(identity, '0xwallet');
    expect(network, BitcoinProductNetwork.mainnet);
    calls++;
    raw = transaction;
    if (error != null) throw error!;
    return hash;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  setUp(WalletVaultService.unlock);
  tearDown(WalletVaultService.lockAll);
  test(
    'submits exact signed bytes, matches txid and deduplicates concurrent calls',
    () async {
      final signed = await signedFixture();
      final provider = BroadcastNetwork(signed.transaction.txid);
      final service = BitcoinBroadcastService(network: provider);
      final outcomes = await Future.wait([
        service.broadcast(signed, isCurrent: () => true),
        service.broadcast(signed, isCurrent: () => true),
      ]);
      expect(provider.raw, signed.transaction.rawTransactionHex);
      expect(provider.calls, 1);
      expect(
        outcomes.every(
          (value) => value.status == BitcoinSubmissionStatus.accepted,
        ),
        isTrue,
      );
    },
  );
  test('wrong backend txid fails closed', () async {
    final signed = await signedFixture();
    final provider = BroadcastNetwork(List.filled(64, '0').join());
    await expectLater(
      BitcoinBroadcastService(
        network: provider,
      ).broadcast(signed, isCurrent: () => true),
      throwsA(isA<BitcoinBroadcastMismatch>()),
    );
    expect(provider.calls, 1);
  });
  test('timeout is unknown and never automatically resubmitted', () async {
    final signed = await signedFixture();
    final provider = BroadcastNetwork(signed.transaction.txid)
      ..error = TimeoutException('Fixture');
    final service = BitcoinBroadcastService(network: provider);
    final first = await service.broadcast(signed, isCurrent: () => true);
    final second = await service.broadcast(signed, isCurrent: () => true);
    expect(first.status, BitcoinSubmissionStatus.unknown);
    expect(second.txid, signed.transaction.txid);
    expect(provider.calls, 1);
  });
  test(
    'lock and reauthentication cannot revive old broadcast authorization',
    () async {
      final signed = await signedFixture();
      final provider = BroadcastNetwork(signed.transaction.txid);
      await WalletVaultService.lockAll();
      WalletVaultService.unlock();
      await expectLater(
        BitcoinBroadcastService(
          network: provider,
        ).broadcast(signed, isCurrent: () => true),
        throwsStateError,
      );
      expect(provider.calls, 0);
    },
  );
  test('wallet switch prevents submission', () async {
    final signed = await signedFixture();
    final provider = BroadcastNetwork(signed.transaction.txid);
    await expectLater(
      BitcoinBroadcastService(
        network: provider,
      ).broadcast(signed, isCurrent: () => false),
      throwsStateError,
    );
    expect(provider.calls, 0);
  });
}
