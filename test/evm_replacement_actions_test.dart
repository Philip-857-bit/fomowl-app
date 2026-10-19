@Tags(['ffi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/evm_outbound_transaction.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/evm_replacement_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/screens/transaction/widgets/evm_replacement_actions.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/test_fonts.dart';
import 'evm_replacement_service_test.dart' as fixtures;

class Recording extends EvmReplacementService {
  final fixtures.Fixture fixture;
  bool pending = true;
  bool canCancel = true;
  int submissions = 0;
  EvmPreparedReplacement? prepared;
  EvmPreparedReplacement? received;
  final Map<EvmReplacementKind, EvmPreparedReplacement> ready;
  Recording(this.fixture, this.ready)
    : super(
        journal: fixture.journal,
        client: fixture.rpc.client,
        currentSender: () async => fixtures.sender,
        openSigner: fixture.wallet.getEvmSigningAccount,
      );
  @override
  Future<EvmReplacementAvailability> availability(
    String sender,
    int chainId,
    String hash, {
    required bool Function() isCurrent,
  }) async =>
      EvmReplacementAvailability(pending: pending, canCancel: canCancel);
  @override
  Future<EvmPreparedReplacement> prepare(
    String sender,
    int chainId,
    String hash,
    EvmReplacementKind kind, {
    required bool Function() isCurrent,
  }) async {
    prepared = ready[kind]!;
    return prepared!;
  }

  @override
  Future<String> submit(
    EvmPreparedReplacement approved, {
    required bool Function() isCurrent,
  }) async {
    submissions++;
    received = approved;
    pending = false;
    return '0x${'cc' * 32}';
  }
}

Future<(fixtures.Fixture, Recording)> mount(
  WidgetTester tester, {
  bool cancel = true,
  required Future<bool> Function(BuildContext) authenticate,
  bool Function()? current,
}) async {
  final f = fixtures.Fixture();
  await tester.runAsync(f.init);
  addTearDown(f.rpc.client.dispose);
  final ready = <EvmReplacementKind, EvmPreparedReplacement>{};
  for (final kind in EvmReplacementKind.values) {
    ready[kind] = (await tester.runAsync(() => f.prepare(kind)))!;
  }
  final service = Recording(f, ready)..canCancel = cancel;

  final chain = BlockchainService().activeChain;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EvmReplacementActions(
          wallet: f.wallet,
          chain: chain,
          sender: fixtures.sender,
          hash: f.original.hash,
          service: service,
          isCurrent: current ?? () => true,
          authenticate: authenticate,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (f, service);
}

void main() {
  setUp(installTestFonts);
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await RustLib.init();
  });
  setUp(WalletVaultService.unlock);
  testWidgets(
    'pending controls disappear when subsequent status is confirmed',
    (tester) async {
      final (_, service) = await mount(
        tester,
        authenticate: (_) async => false,
      );
      expect(find.byKey(const Key('evm-speed-up')), findsOneWidget);
      expect(find.byKey(const Key('evm-cancel-transaction')), findsOneWidget);
      service.pending = false;
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('evm-speed-up')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('unsafe Cancel is hidden while Speed Up stays available', (
    tester,
  ) async {
    await mount(tester, cancel: false, authenticate: (_) async => false);
    expect(find.byKey(const Key('evm-speed-up')), findsOneWidget);
    expect(find.byKey(const Key('evm-cancel-transaction')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('dismissing explicit review never authenticates or submits', (
    tester,
  ) async {
    int authentications = 0;
    final (_, service) = await mount(
      tester,
      authenticate: (_) async {
        authentications++;
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('evm-speed-up')));
    await tester.pumpAndSettle();
    expect(find.text('Old estimated fee'), findsOneWidget);
    expect(find.text('New estimated fee'), findsOneWidget);
    expect(find.text('Additional estimated cost'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(authentications, 0);
    expect(service.submissions, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('canceled unlock aborts exact approved replacement safely', (
    tester,
  ) async {
    int authentications = 0;
    final (_, service) = await mount(
      tester,
      authenticate: (_) async {
        authentications++;
        return false;
      },
    );
    await tester.tap(find.byKey(const Key('evm-speed-up')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('evm-approve-replacement')));
    await tester.pumpAndSettle();
    expect(authentications, 1);
    expect(service.submissions, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'explicit approval and authentication submit the same reviewed object',
    (tester) async {
      final (_, service) = await mount(
        tester,
        authenticate: (_) async {
          WalletVaultService.unlock();
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('evm-cancel-transaction')));
      await tester.pumpAndSettle();
      expect(service.prepared!.kind, EvmReplacementKind.cancel);
      expect(service.prepared!.fields.destination, fixtures.sender);
      expect(
        find.textContaining('original transaction may confirm first'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('evm-approve-replacement')));
      await tester.pumpAndSettle();
      expect(service.submissions, 1);
      expect(identical(service.received, service.prepared), isTrue);
      expect(
        find.text('Replacement submitted. Confirmation is still pending.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('evm-speed-up')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'wallet/network switch during review prevents authentication and submission',
    (tester) async {
      bool active = true;
      int authentications = 0;
      final (_, service) = await mount(
        tester,
        current: () => active,
        authenticate: (_) async {
          authentications++;
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('evm-speed-up')));
      await tester.pumpAndSettle();
      active = false;
      await tester.tap(find.byKey(const Key('evm-approve-replacement')));
      await tester.pumpAndSettle();
      expect(authentications, 0);
      expect(service.submissions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
