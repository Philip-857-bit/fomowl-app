import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/screens/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreenBody renders logo, wordmark, tagline, and bottom credit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreenBody(),
      ),
    );

    // Verify wordmark and tagline
    expect(find.text('Owllet'), findsOneWidget);
    expect(find.text('Trade instantly. Spend Effortlessly'), findsOneWidget);

    // Verify bottom credit inside RichText
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('FOMOwl Inc'),
      ),
      findsOneWidget,
    );

    // Verify image widget for the owl mark
    expect(find.byType(Image), findsOneWidget);
  });
}
