import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/token_detail/price_overview.dart';

void main() {
  testWidgets('PriceOverview renders long price without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: PriceOverview(
              priceText: '\$0.000000007',
              changeText: '+6.30%',
              isPositiveChange: true,
              holdingsText: '\$81.54',
            ),
          ),
        ),
      ),
    );

    expect(find.text('\$0.000000007'), findsOneWidget);
    expect(find.text('+6.30%'), findsOneWidget);
    expect(find.text('Holdings: \$81.54'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
