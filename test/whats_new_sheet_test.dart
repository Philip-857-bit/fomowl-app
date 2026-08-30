import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/screens/home/widgets/whats_new_sheet.dart';
import 'package:fomowl_wallet/services/app_release_checker.dart';
import 'package:fomowl_wallet/widgets/forced_update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsNewSheet & ForcedUpdateDialog Tests', () {
    testWidgets('WhatsNewSheet renders new version modal matching Figma 319:2721', (
      tester,
    ) async {
      final result = WhatsNewResult(
        isUpdateAvailable: true,
        minVersion: '1.0.0',
        installedVersion: '1.6.0',
        serverVersion: '2.0.0',
        releaseNotes: [
          '**New homepage:** AI market signals and curated news in one feed',
          '**Owllet Wallet Card:** Fewer steps to apply, and smoother spending',
          '**Robinhood Chain now supported:** Send, receive, and swap trending and new tokens',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => WhatsNewSheet.show(context, result),
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Check Header & Badge
      expect(find.text('NEW VERSION'), findsOneWidget);
      expect(find.text('Get the brand new app'), findsOneWidget);
      expect(find.text('v2.0.0'), findsOneWidget);

      // Check Release Notes
      expect(find.textContaining('AI market signals'), findsOneWidget);
      expect(find.textContaining('Fewer steps to apply'), findsOneWidget);
      expect(find.textContaining('Robinhood Chain'), findsOneWidget);

      // Check Action Button (Figma 319:2898 single Upgrade now action)
      expect(find.text('Upgrade now'), findsOneWidget);
    });

    testWidgets('ForcedUpdateDialog renders UPDATE REQUIRED badge and notes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForcedUpdateDialog(
              version: '2.0.0',
              releaseNotes: [
                '**Security Patch:** Mandatory security patch to protect wallet assets.',
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UPDATE REQUIRED'), findsOneWidget);
      expect(find.text('Security & Stability Update'), findsOneWidget);
      expect(find.text('v2.0.0'), findsOneWidget);
      expect(find.textContaining('Mandatory security patch'), findsOneWidget);
      expect(find.text('Upgrade now'), findsOneWidget);
    });
  });
}
