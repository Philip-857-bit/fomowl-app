import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/screens/wallet/widgets/send/send_receiver_step.dart';
import 'package:fomowl_wallet/services/recipient_book_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const walletScope = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const receiver = '0x1111111111111111111111111111111111111111';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildSubject({
    required TextEditingController controller,
    VoidCallback? onBack,
    ValueChanged<WalletRecipient>? onSelected,
  }) {
    return MaterialApp(
      home: SendReceiverStep(
        networkKey: 'evm:56',
        walletScope: walletScope,
        controller: controller,
        isValidAddress: (value) =>
            RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value),
        onSelected: onSelected ?? (_) {},
        onBack: onBack ?? () {},
        onQrTap: () async => null,
      ),
    );
  }

  testWidgets('shows a working back button', (tester) async {
    final controller = TextEditingController();
    var backPressed = false;

    await tester.pumpWidget(
      buildSubject(controller: controller, onBack: () => backPressed = true),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('send-receiver-back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('send-receiver-back')));

    expect(backPressed, isTrue);
  });

  testWidgets('saves a named receiver and still allows continuing', (
    tester,
  ) async {
    final controller = TextEditingController();
    WalletRecipient? selected;

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        onSelected: (recipient) => selected = recipient,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, receiver);
    await tester.pump();

    final saveButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('send-receiver-save')),
    );
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('send-receiver-continue')),
    );
    expect(saveButton.onPressed, isNotNull);
    expect(continueButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('send-receiver-save')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Address name'),
      'Treasury',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Treasury'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('send-receiver-continue')));
    expect(selected?.address, receiver);
  });

  testWidgets('places Paste at the right edge of the address actions', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(buildSubject(controller: controller));
    await tester.pumpAndSettle();

    final paste = find.byKey(const ValueKey('send-receiver-paste'));
    final qrScan = find.byKey(const ValueKey('send-receiver-qr-scan'));
    final field = find.byType(TextField).first;
    expect(qrScan, findsOneWidget);
    expect(
      tester.getCenter(paste).dx,
      greaterThan(tester.getCenter(qrScan).dx),
    );
    expect(tester.getCenter(paste).dx, greaterThan(tester.getCenter(field).dx));
  });
}
