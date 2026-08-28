import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_definition.dart';
import 'package:fomowl_wallet/features/mini_apps/widgets/mini_app_identity_title.dart';

void main() {
  testWidgets(
    'trusted mini-app chrome shows the registry name without its URL',
    (tester) async {
      const definition = MiniAppDefinition(
        id: 'owllet_pay',
        title: 'OwlletPay',
        description: 'Shop with crypto.',
        launchUrl: 'https://shop.owlletpay.example/catalog',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MiniAppIdentityTitle(definition: definition)),
        ),
      );

      expect(find.text('OwlletPay'), findsOneWidget);
      expect(find.textContaining('shop.owlletpay.example'), findsNothing);
      expect(find.textContaining('https://'), findsNothing);
    },
  );
}
