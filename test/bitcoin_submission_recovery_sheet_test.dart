import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/send/bitcoin_submission_recovery_sheet.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_wallet_vault_service.dart';
import 'bitcoin_submission_recovery_test.dart';

Widget host(RecoveryFixture fixture, Future<bool> Function() authenticate) =>
    MaterialApp(
      theme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BitcoinSubmissionRecoverySheet(
          identity: identity,
          network: BitcoinProductNetwork.testnet4,
          service: fixture.service,
          authenticate: authenticate,
          isCurrent: () => true,
        ),
      ),
    );

void main() {
  setUp(BitcoinWalletVaultService.unlock);
  tearDown(BitcoinWalletVaultService.lockAll);
  testWidgets('dismissal while checks are pending cannot release the entry', (
    tester,
  ) async {
    final value = RecoveryFixture();
    value.network.gate = Completer<void>();
    await tester.pumpWidget(host(value, () async => true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('bitcoin-recover-$txid')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bitcoin-recovery-proceed')));
    await tester.pump();
    expect(value.network.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    value.network.gate!.complete();
    await tester.pumpAndSettle();
    expect(
      await value.journal.reserved(identity, BitcoinProductNetwork.testnet4),
      {point},
    );
  });
  testWidgets(
    'inspect exact attempt, explicit acknowledgement, auth and recovery',
    (tester) async {
      final value = RecoveryFixture();
      var authentications = 0;
      await tester.pumpWidget(
        host(value, () async {
          authentications++;
          return true;
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text(txid), findsOneWidget);
      await tester.tap(find.byKey(Key('bitcoin-recover-$txid')));
      await tester.pumpAndSettle();
      final proceed = find.byKey(const Key('bitcoin-recovery-proceed'));
      expect(tester.widget<FilledButton>(proceed).onPressed, isNull);
      expect(authentications, 0);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(proceed);
      await tester.pumpAndSettle();
      expect(authentications, 1);
      expect(
        find.text('Reservation recovered. You can prepare a new transfer.'),
        findsOneWidget,
      );
      expect(
        await value.journal.pending(identity, BitcoinProductNetwork.testnet4),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('cancel leaves the exact entry intact and never authenticates', (
    tester,
  ) async {
    final value = RecoveryFixture();
    await tester.pumpWidget(
      host(value, () async => throw StateError('must not authenticate')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('bitcoin-recover-$txid')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(
      await value.journal.reserved(identity, BitcoinProductNetwork.testnet4),
      {point},
    );
    expect(value.network.calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final legacy in [true, false]) {
    testWidgets(
      'production or nonlegacy entries offer inspection without recovery (legacy=$legacy)',
      (tester) async {
        final value = RecoveryFixture(enabled: !legacy);
        if (!legacy) {
          value.memory.values['bitcoin_submission_v1_$identity'] = jsonEncode({
            'version': 2,
            'identity': identity,
            'entries': {
              'testnet4|$txid': [point],
            },
            'legacyEntries': [],
          });
        }
        await tester.pumpWidget(host(value, () async => true));
        await tester.pumpAndSettle();
        expect(find.text(txid), findsOneWidget);
        expect(find.byKey(Key('bitcoin-recover-$txid')), findsNothing);
        expect(find.text('Check transaction status'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
