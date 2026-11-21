import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/transaction/transaction_processing_screen.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/runtime_config_service.dart';
import 'package:fomowl_wallet/theme/app_chain_theme.dart';
import 'package:fomowl_wallet/theme/theme_controller.dart';
import 'helpers/test_fonts.dart';

void main() {
  setUp(installTestFonts);
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('accepted, uncertain and confirmed results remain separate', () {
    final progress = TransactionProgressController(
      flow: TransactionProgressFlow.transfer,
    );
    progress.setSubmitted(
      reference: 'txid',
      detailsUrl: 'https://example.com/tx/txid',
    );
    expect(progress.state.stage, TransactionProgressStage.submitted);
    expect(progress.state.isConfirmed, isFalse);
    expect(progress.state.isTerminal, isFalse);
    expect(progress.state.hasProcessingState, isFalse);
    progress.setSubmissionUnknown(
      reference: 'txid',
      detailsUrl: 'https://example.com/tx/txid',
    );
    expect(progress.state.stage, TransactionProgressStage.submissionUnknown);
    expect(progress.state.isConfirmed, isFalse);
    progress.setConfirmed(
      reference: 'txid',
      detailsUrl: 'https://example.com/tx/txid',
    );
    expect(progress.state.isConfirmed, isTrue);
    expect(progress.state.isTerminal, isTrue);
    expect(progress.state.reference, 'txid');
    progress.dispose();
  });

  for (final uncertain in [false, true]) {
    testWidgets(
      'submission result is visible and Done returns to wallet (uncertain=$uncertain)',
      (tester) async {
        final progress = TransactionProgressController();
        if (uncertain) {
          progress.setSubmissionUnknown(
            reference: 'txid',
            detailsUrl: 'https://example.com/tx/txid',
          );
        } else {
          progress.setSubmitted(
            reference: 'txid',
            detailsUrl: 'https://example.com/tx/txid',
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: {
              '/processing': (_) => const TransactionProcessingScreen(),
              '/shell': (_) => const Scaffold(body: Text('Wallet home')),
            },
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/processing',
                    arguments: TransactionProcessingArguments(
                      controller: progress,
                      terminalRouteName: '/shell',
                      clearStackOnTerminalRoute: true,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          find.text(uncertain ? 'Submission uncertain' : 'Submitted'),
          findsOneWidget,
        );
        expect(find.text('Confirmed'), findsNothing);
        expect(
          find.byKey(const Key('transaction-submission-result')),
          findsOneWidget,
        );
        expect(find.text('Processing your transaction…'), findsNothing);
        expect(find.text('View on Explorer'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        if (!uncertain) {
          progress.setConfirmed(
            reference: 'txid',
            detailsUrl: 'https://example.com/tx/txid',
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('Confirmed'), findsOneWidget);
          expect(
            find.text('Your transaction has been included in a block.'),
            findsOneWidget,
          );
          expect(find.text('Submitted'), findsNothing);
        } else {
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          expect(find.text('Wallet home'), findsOneWidget);
          expect(progress.state.isConfirmed, isFalse);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        progress.dispose();
      },
    );
  }

  test('existing transfer and swap progress semantics stay unchanged', () {
    for (final flow in [
      TransactionProgressFlow.transfer,
      TransactionProgressFlow.swap,
    ]) {
      final progress = TransactionProgressController(flow: flow);
      progress.setSwapPending(reference: 'reference');
      expect(progress.state.stage, TransactionProgressStage.swapPending);
      expect(progress.state.hasProcessingState, isTrue);
      progress.setSuccess(reference: 'reference');
      expect(progress.state.stage, TransactionProgressStage.success);
      expect(progress.state.isTerminal, isTrue);
      progress.dispose();
    }
  });

  for (final festive in [false, true]) {
    for (final viewportSize in const [Size(390, 844), Size(360, 740)]) {
      testWidgets(
        'transaction success screen renders ${festive ? 'festive' : 'standard'} Figma layout without overflow at ${viewportSize.width.toInt()}x${viewportSize.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = viewportSize;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final progress = TransactionProgressController();
          progress.setSuccess(
            reference: '0x7713...c737',
            detailsUrl: 'https://example.com/tx/0x7713',
          );
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routes: {
                '/processing': (_) =>
                    TransactionProcessingScreen(festiveOverride: festive),
              },
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/processing',
                      arguments: TransactionProcessingArguments(
                        controller: progress,
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              ValueKey(
                'transaction-success-${festive ? 'festive' : 'standard'}',
              ),
            ),
            findsOneWidget,
          );
          expect(find.text('Transaction completed'), findsOneWidget);
          expect(
            find.text('Your transaction has been confirmed successfully.'),
            findsOneWidget,
          );
          expect(find.text('0x7713...c737'), findsOneWidget);
          expect(find.text('View on Explorer'), findsOneWidget);
          expect(find.text('Close'), findsOneWidget);
          expect(
            find.text("SEASON'S GREETINGS"),
            festive ? findsOneWidget : findsNothing,
          );
          expect(find.text('OwlletPay'), findsNothing);
          expect(
            find.byKey(const Key('transaction-success-back-button')),
            findsNothing,
          );
          expect(find.byIcon(Icons.close), findsOneWidget);
          final badge = tester.widget<Container>(
            find.byKey(const Key('transaction-success-checkmark-badge')),
          );
          final badgeDecoration = badge.decoration! as BoxDecoration;
          expect(badgeDecoration.boxShadow, anyOf(isNull, isEmpty));

          await tester.pumpWidget(const SizedBox.shrink());
          progress.dispose();
        },
      );
    }
  }

  testWidgets('RuntimeConfigService parses festive transaction success flag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final mockService = RuntimeConfigService.forTesting(
      client: MockClient(
        (_) async => http.Response(
          '{"revision":1,"policy":{"features":{"festiveTransactionSuccessEnabled":true}}}',
          200,
        ),
      ),
    );
    await mockService.refresh();
    expect(mockService.snapshot.festiveTransactionSuccessEnabled, isTrue);
    expect(
      RuntimeConfigService.instance.snapshot.festiveTransactionSuccessEnabled,
      isFalse,
    );
  });

  testWidgets(
    'View on Explorer button adapts to active chain theme and classic toggle',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(1);
      final themeController = ThemeController();
      final progress = TransactionProgressController()
        ..setSuccess(
          reference: '0x7713...c737',
          detailsUrl: 'https://etherscan.io/tx/0x7713',
        );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
            ChangeNotifierProvider<ThemeController>.value(
              value: themeController,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: {
              '/processing': (_) =>
                  const TransactionProcessingScreen(festiveOverride: false),
            },
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/processing',
                    arguments: TransactionProcessingArguments(
                      controller: progress,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      Container primaryContainer() => tester.widget<Container>(
        find.byKey(const Key('transaction-success-primary-button')),
      );
      Text primaryText() => tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('transaction-success-primary-button')),
          matching: find.text('View on Explorer'),
        ),
      );

      expect(
        (primaryContainer().decoration! as BoxDecoration).gradient,
        AppChainTheme.ethereum.buttonGradient,
      );
      expect(primaryText().style?.color, Colors.white);

      // Switching to BSC uses its gold button gradient and high-contrast dark text.
      blockchain.setActiveChainByChainId(56);
      await tester.pumpAndSettle();
      expect(
        (primaryContainer().decoration! as BoxDecoration).gradient,
        AppChainTheme.bsc.buttonGradient,
      );
      expect(primaryText().style?.color, Colors.black);

      // Switching to Classic mode uses FOMOwl signature gradient.
      await themeController.setThemeMode(AppThemeMode.classic);
      await tester.pumpAndSettle();
      expect(
        (primaryContainer().decoration! as BoxDecoration).gradient,
        AppChainTheme.fomowlSignature.buttonGradient,
      );
      expect(primaryText().style?.color, Colors.white);

      // In-flight submitted view with explorer URL also follows active chain theme.
      await themeController.setThemeMode(AppThemeMode.adaptive);
      blockchain.setActiveChainByChainId(8453);
      progress.setSubmitted(
        reference: '0x7713...c737',
        detailsUrl: 'https://basescan.org/tx/0x7713',
      );
      await tester.pumpAndSettle();
      final processingButton = tester.widget<Container>(
        find.byKey(const Key('transaction-processing-primary-button')),
      );
      expect(
        (processingButton.decoration! as BoxDecoration).gradient,
        AppChainTheme.base.buttonGradient,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      progress.dispose();
      blockchain.dispose();
      themeController.dispose();
    },
  );
}
