@Tags(['ffi'])
library;

import 'dart:async';
import 'dart:convert';
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
  for (final status in [400, 401, 403]) {
    test(
      'proven $status rejection releases exact inputs without automatically resending',
      () async {
        final signed = await signedFixture();
        final data = switch (status) {
          400 => {'error': 'Invalid Bitcoin transaction encoding'},
          401 => {
            'error': 'Authentication required',
            'message': 'The wallet session has expired.',
          },
          _ => {
            'error': 'Forbidden',
            'message':
                'The wallet session does not match the requested wallet.',
          },
        };
        final error = BitcoinPreProviderRejection.fromBackendResponse(
          status,
          jsonEncode(data),
        )!;
        final provider = BroadcastNetwork(signed.transaction.txid)
          ..error = error;
        final service = BitcoinBroadcastService(network: provider);
        for (var i = 0; i < 2; i++) {
          await expectLater(
            service.broadcast(signed, isCurrent: () => true),
            throwsA(same(error)),
          );
        }
        expect(provider.calls, 1);
        expect(
          await signed.submissionJournal.reserved(
            '0xwallet',
            signed.transfer.network,
          ),
          isEmpty,
        );
        // A new attempt can reserve these inputs only after fresh signing/approval.
        expect(
          await signed.submissionJournal.reserve(
            '0xwallet',
            signed.transfer.network,
            signed.transaction.txid,
            signed.transfer.plan.selectedUtxos,
          ),
          isTrue,
        );
      },
    );
  }
  for (final error in <Object>[
    BitcoinNetworkException(400),
    BitcoinNetworkException(401),
    BitcoinNetworkException(403),
    BitcoinNetworkException(404),
    BitcoinNetworkException(429),
    BitcoinNetworkException(500),
    BitcoinNetworkException(503),
    BitcoinNetworkException(),
    TimeoutException('Public timeout fixture'),
    FormatException('Public malformed response fixture'),
  ]) {
    test(
      'unproven/ambiguous ${error.runtimeType} ${error is BitcoinNetworkException ? error.statusCode : ""} retains exact reservation',
      () async {
        final signed = await signedFixture();
        final provider = BroadcastNetwork(signed.transaction.txid)
          ..error = error;
        final service = BitcoinBroadcastService(network: provider);
        final outcome = await service.broadcast(signed, isCurrent: () => true);
        expect(outcome.status, BitcoinSubmissionStatus.unknown);
        await service.broadcast(signed, isCurrent: () => true);
        expect(provider.calls, 1);
        expect(
          await signed.submissionJournal.reserved(
            '0xwallet',
            signed.transfer.network,
          ),
          signed.transfer.plan.selectedUtxos
              .map((input) => '${input.txid}:${input.vout}')
              .toSet(),
        );
      },
    );
  }
  test('successful broadcast keeps the reservation', () async {
    final signed = await signedFixture();
    final provider = BroadcastNetwork(signed.transaction.txid);
    expect(
      (await BitcoinBroadcastService(
        network: provider,
      ).broadcast(signed, isCurrent: () => true)).status,
      BitcoinSubmissionStatus.accepted,
    );
    expect(
      await signed.submissionJournal.reserved(
        '0xwallet',
        signed.transfer.network,
      ),
      isNotEmpty,
    );
  });
  test(
    'context change after reserve but before network releases without submitting',
    () async {
      final signed = await signedFixture();
      final provider = BroadcastNetwork(signed.transaction.txid);
      var checks = 0;
      await expectLater(
        BitcoinBroadcastService(
          network: provider,
        ).broadcast(signed, isCurrent: () => ++checks < 3),
        throwsStateError,
      );
      expect(provider.calls, 0);
      expect(
        await signed.submissionJournal.reserved(
          '0xwallet',
          signed.transfer.network,
        ),
        isEmpty,
      );
    },
  );
  test('legacy reservation cannot be silently retried or released', () async {
    final signed = await signedFixture();
    await signed.submissionJournal.reserve(
      '0xwallet',
      signed.transfer.network,
      signed.transaction.txid,
      signed.transfer.plan.selectedUtxos,
    );
    final provider = BroadcastNetwork(signed.transaction.txid);
    expect(
      (await BitcoinBroadcastService(
        network: provider,
      ).broadcast(signed, isCurrent: () => true)).status,
      BitcoinSubmissionStatus.unknown,
    );
    expect(provider.calls, 0);
    expect(
      await signed.submissionJournal.reserved(
        '0xwallet',
        signed.transfer.network,
      ),
      isNotEmpty,
    );
  });
}
