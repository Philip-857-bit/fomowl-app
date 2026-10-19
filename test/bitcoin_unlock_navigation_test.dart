import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/utils/wallet_unlock_navigation.dart';

void main() {
  for (final result in <Object?>[true, false, null, 'true']) {
    testWidgets('named unlock route accepts only explicit true ($result)', (
      tester,
    ) async {
      bool? authenticated;
      Object? failure;
      RouteSettings? unlockSettings;
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/unlock': (context) {
              unlockSettings = ModalRoute.of(context)!.settings;
              return Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.pop(context, result),
                  child: const Text('Finish unlock'),
                ),
              );
            },
          },
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  try {
                    authenticated = await requestWalletUnlock(context);
                  } catch (error) {
                    failure = error;
                  }
                },
                child: const Text('Confirm'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(failure, isNull);
      expect(find.text('Finish unlock'), findsOneWidget);
      expect(authenticated, isNull);
      expect(unlockSettings!.arguments, {'returnToPrevious': true});
      await tester.tap(find.text('Finish unlock'));
      await tester.pumpAndSettle();
      expect(failure, isNull);
      expect(authenticated, result == true);
      expect(find.text('Confirm'), findsOneWidget);
    });
  }
}
