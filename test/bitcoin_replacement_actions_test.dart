@Tags(['ffi'])
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/transaction/widgets/bitcoin_replacement_actions.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_broadcast_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_rbf_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'package:fomowl_wallet/theme/app_chain_theme.dart';
import 'package:fomowl_wallet/theme/theme_controller.dart';
import 'package:fomowl_wallet/utils/bitcoin_amount_utils.dart';
import 'bitcoin_adaptive_theme_test.dart' as themes;
import 'helpers/bitcoin_memory_store.dart';
import 'helpers/bitcoin_rbf_fixture.dart';
import 'helpers/test_fonts.dart';

Future<void> nativeUntil(WidgetTester tester, bool Function() complete) async {
  for (var attempt = 0; attempt < 100 && !complete(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    complete(),
    isTrue,
    reason: 'Native operation must complete within the bounded test wait',
  );
}

Widget host(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await RustLib.init();
  });
  setUp(() async {
    await installTestFonts();
    SharedPreferences.setMockInitialValues({});
    WalletVaultService.unlock();
  });
  tearDown(WalletVaultService.lockAll);

  for (final mode in AppThemeMode.values) {
    testWidgets(
      '$mode reviews exact higher fees, authenticates and submits only once',
      (tester) async {
        final f = (await tester.runAsync(() => rbfFixture()))!;
        final coordinator = BitcoinRbfService(
          store: f.store,
          network: f.network,
          signing: f.signing,
        );
        final preview = (await tester.runAsync(
          () => coordinator.prepare(
            RbfFixture.identity,
            f.original.transfer.network,
            f.original.transaction.txid,
            BigInt.from(3),
            isCurrent: () => true,
          ),
        ))!;
        f.network.accept = (raw) => f.acceptPlan(preview.transfer.plan, raw);
        final theme = ThemeController(
          storage: StorageService(secureStore: MemoryStore()),
        );
        await theme.setThemeMode(mode);
        final chain = themes.BitcoinThemeChain();
        final submitted = Completer<BitcoinBroadcastOutcome>();
        var authentications = 0;
        await tester.pumpWidget(
          themes.host(
            BitcoinReplacementActions(
              walletIdentity: RbfFixture.identity,
              network: f.original.transfer.network,
              txid: f.original.transaction.txid,
              service: coordinator,
              isCurrent: () => true,
              authenticate: (_) async {
                authentications++;
                WalletVaultService.unlock();
                return true;
              },
              onSubmitted: (approval, outcome) async {
                expect(
                  approval.transfer.plan.feeSat,
                  preview.transfer.plan.feeSat,
                );
                submitted.complete(outcome);
              },
            ),
            chain,
            theme,
          ),
        );
        await nativeUntil(
          tester,
          () => find.byKey(const Key('bitcoin-speed-up')).evaluate().isNotEmpty,
        );
        final expected = mode == AppThemeMode.classic
            ? AppChainTheme.fomowlSignature
            : AppChainTheme.bitcoin;
        final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('bitcoin-speed-up')),
        );
        expect(
          button.style!.foregroundColor!.resolve({}),
          expected.accentColor,
        );
        expect(find.text('Cancel transaction'), findsNothing);
        await tester.tap(find.byKey(const Key('bitcoin-speed-up')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('bitcoin-rbf-rate')))
              .controller!
              .text,
          '3',
        );
        await tester.enterText(find.byKey(const Key('bitcoin-rbf-rate')), '1');
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('bitcoin-rbf-prepare')),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(find.byKey(const Key('bitcoin-rbf-rate')), '3');
        await tester.pump();
        await tester.tap(find.byKey(const Key('bitcoin-rbf-prepare')));
        await nativeUntil(
          tester,
          () => find
              .byKey(const Key('bitcoin-rbf-approve'))
              .evaluate()
              .isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text('Original network fee'), findsOneWidget);
        expect(find.text('Replacement network fee'), findsOneWidget);
        expect(find.text('Additional fee'), findsOneWidget);
        expect(find.text('3 sat/vB'), findsOneWidget);
        expect(
          find.text(
            '${BitcoinAmountUtils.format(preview.replacementFeeSat)} BTC (${preview.replacementFeeSat} sats)',
          ),
          findsOneWidget,
        );
        expect(authentications, 0);
        expect(f.network.broadcasts, 0);
        await tester.tap(find.byKey(const Key('bitcoin-rbf-approve')));
        await nativeUntil(tester, () => submitted.isCompleted);
        await tester.pumpAndSettle();
        expect(
          (await submitted.future).status,
          BitcoinSubmissionStatus.accepted,
        );
        expect(authentications, 1);
        expect(f.network.broadcasts, 1);
        expect(
          find.text('Replacement submitted. Confirmation is still pending.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        theme.dispose();
        chain.dispose();
      },
    );
  }
  for (final reason in ['confirmed', 'unsupported']) {
    testWidgets('$reason transactions never expose Speed Up', (tester) async {
      final f = (await tester.runAsync(() => rbfFixture()))!;
      if (reason == 'confirmed') {
        f.network.confirmed = true;
      } else {
        f.network.supported = false;
      }
      final coordinator = BitcoinRbfService(
        store: f.store,
        network: f.network,
        signing: f.signing,
      );
      await tester.pumpWidget(
        host(
          BitcoinReplacementActions(
            walletIdentity: RbfFixture.identity,
            network: f.original.transfer.network,
            txid: f.original.transaction.txid,
            service: coordinator,
            isCurrent: () => true,
          ),
        ),
      );
      var availabilityChecked = false;
      bool? observedAvailability;
      unawaited(
        coordinator
            .available(
              RbfFixture.identity,
              f.original.transfer.network,
              f.original.transaction.txid,
              isCurrent: () => true,
            )
            .then((available) {
              observedAvailability = available;
              availabilityChecked = true;
            }),
      );
      await nativeUntil(tester, () => availabilityChecked);
      expect(observedAvailability, isFalse);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bitcoin-speed-up')), findsNothing);
      expect(f.network.broadcasts, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('review cancellation performs no authentication or broadcast', (
    tester,
  ) async {
    final f = (await tester.runAsync(() => rbfFixture()))!;
    final coordinator = BitcoinRbfService(
      store: f.store,
      network: f.network,
      signing: f.signing,
    );
    var authentications = 0;
    await tester.pumpWidget(
      host(
        BitcoinReplacementActions(
          walletIdentity: RbfFixture.identity,
          network: f.original.transfer.network,
          txid: f.original.transaction.txid,
          service: coordinator,
          isCurrent: () => true,
          authenticate: (_) async {
            authentications++;
            return true;
          },
        ),
      ),
    );
    await nativeUntil(
      tester,
      () => find.byKey(const Key('bitcoin-speed-up')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('bitcoin-speed-up')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bitcoin-rbf-prepare')));
    await nativeUntil(
      tester,
      () => find.byKey(const Key('bitcoin-rbf-approve')).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(authentications, 0);
    expect(f.network.broadcasts, 0);
    expect(
      await tester.runAsync(
        () => f.journal.reserved(
          RbfFixture.identity,
          f.original.transfer.network,
        ),
      ),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
