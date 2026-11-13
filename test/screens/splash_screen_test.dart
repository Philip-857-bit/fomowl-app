import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/screens/splash/splash_screen.dart';

void main() {
  testWidgets(
    'wordmark grows to align both edges with the tagline on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SplashScreenBody()));
      final title = find.text('Owllet');
      final tagline = find.text('Trade instantly. Spend Effortlessly');
      final titleRect = tester.getRect(title);
      final taglineRect = tester.getRect(tagline);
      expect(titleRect.left, closeTo(taglineRect.left, 0.5));
      expect(titleRect.right, closeTo(taglineRect.right, 0.5));
      expect(tester.widget<Text>(title).style!.fontSize, greaterThan(44));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'SplashScreenBody renders logo, wordmark, tagline, and bottom credit',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreenBody()));

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
      final logo = tester.widget<Image>(find.byType(Image));
      expect((logo.image as AssetImage).assetName, 'assets/images/logo.png');
    },
  );
}
