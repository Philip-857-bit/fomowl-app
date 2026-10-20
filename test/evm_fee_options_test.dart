import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/evm_fee_quote.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/transfer_confirmation/evm_fee_options.dart';

EvmFeeQuotes quotes({
  bool equal = false,
  bool legacy = false,
  bool partial = false,
  DateTime? quotedAt,
}) {
  final intent = EvmFeeIntent(
    chainId: 1,
    sender: '0x1111111111111111111111111111111111111111',
    destination: '0x2222222222222222222222222222222222222222',
    valueWei: BigInt.one,
    data: Uint8List(0),
    rpcScope: Object(),
  );
  final now = quotedAt ?? DateTime.now();
  int price(EvmFeeTier tier) => equal
      ? 3
      : partial && tier == EvmFeeTier.economy
      ? 2
      : tier.index + 1;
  return EvmFeeQuotes({
    for (final tier in EvmFeeTier.values)
      tier: EvmFeeQuote(
        intent: intent,
        tier: tier,
        type: legacy
            ? EvmTransactionType.legacy
            : EvmTransactionType.dynamicFee,
        gasLimit: 23100,
        quotedAt: now,
        gasPriceWei: legacy ? BigInt.from(price(tier)) : null,
        baseFeePerGasWei: legacy ? null : BigInt.from(1000000000),
        maxPriorityFeePerGasWei: legacy ? null : BigInt.from(price(tier)),
        maxFeePerGasWei: legacy ? null : BigInt.from(2000000000 + price(tier)),
      ),
  });
}

Widget host(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
void main() {
  for (final legacy in [true, false]) {
    testWidgets(
      'equivalent Economy and Normal fees share one choice ($legacy)',
      (tester) async {
        EvmFeeTier? selected;
        final fees = quotes(legacy: legacy, partial: true);
        await tester.pumpWidget(
          host(
            EvmFeeOptions(
              quotes: fees,
              selected: EvmFeeTier.economy,
              onChanged: (tier) => selected = tier,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(fees.distinctTiers, [EvmFeeTier.normal, EvmFeeTier.priority]);
        expect(find.byKey(const Key('evm-fee-tier-economy')), findsNothing);
        await tester.tap(find.byKey(const Key('evm-fee-tier-normal')));
        expect(selected, EvmFeeTier.normal);
        expect(
          fees.forTier(EvmFeeTier.economy).maximumTotalFeeWei,
          fees.forTier(EvmFeeTier.normal).maximumTotalFeeWei,
        );
      },
    );
  }
  testWidgets('distinct tiers remain selectable and Normal is the default', (
    tester,
  ) async {
    EvmFeeTier? selected;
    await tester.pumpWidget(
      host(
        EvmFeeOptions(quotes: quotes(), onChanged: (tier) => selected = tier),
      ),
    );
    await tester.pumpAndSettle();
    final options = tester.widget<EvmFeeOptions>(find.byType(EvmFeeOptions));
    expect(options.selected, EvmFeeTier.normal);
    for (final tier in EvmFeeTier.values) {
      await tester.tap(find.byKey(Key('evm-fee-tier-${tier.name}')));
      expect(selected, tier);
    }
    expect(find.byKey(const Key('evm-fee-tiers-equal')), findsNothing);
  });
  testWidgets('equal actual prices hide redundant options', (tester) async {
    await tester.pumpWidget(
      host(
        EvmFeeOptions(
          quotes: quotes(equal: true),
          onChanged: (_) => fail('No selection'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evm-fee-tiers-equal')), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });
  testWidgets('busy controls cannot change approved tier', (tester) async {
    await tester.pumpWidget(
      host(
        EvmFeeOptions(
          quotes: quotes(),
          enabled: false,
          onChanged: (_) => fail('Disabled'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final button in tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    )) {
      expect(button.onPressed, isNull);
    }
  });
  for (final legacy in [true, false]) {
    testWidgets(
      '${legacy ? 'legacy' : 'type-2'} protocol details are collapsed and accurate',
      (tester) async {
        await tester.pumpWidget(
          host(
            EvmFeeOptions(
              quotes: quotes(legacy: legacy),
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Gas limit'), findsNothing);
        expect(find.text('23100'), findsNothing);
        await tester.tap(
          find.byKey(const Key('advanced-transaction-details-toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.text('23100'), findsOneWidget);
        expect(find.text(legacy ? 'Gas price' : 'Base fee'), findsOneWidget);
        expect(find.text(legacy ? 'Base fee' : 'Gas price'), findsNothing);
        await tester.tap(
          find.byKey(const Key('advanced-transaction-details-toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.text('23100'), findsNothing);
      },
    );
  }
}
