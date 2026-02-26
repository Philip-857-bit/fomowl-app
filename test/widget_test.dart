// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// flutter/material.dart not needed — test only uses flutter_test
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/main.dart';

void main() {
  testWidgets('App launches with splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FOMOwlWalletApp());

    // Verify that splash screen shows the app name.
    expect(find.text('Owllet'), findsOneWidget);
  });
}
