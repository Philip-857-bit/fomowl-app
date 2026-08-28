import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/onboarding/confirm_phrase_screen.dart';
import 'package:fomowl_wallet/services/screen_capture_guard.dart';

class _FakeScreenCaptureGuard extends ScreenCaptureGuard {
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enableProtection() async {
    enableCalls++;
  }

  @override
  Future<void> disableProtection() async {
    disableCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createScreen({
    ScreenCaptureGuard? guard,
    List<String>? mnemonicWords,
    NavigatorObserver? navigatorObserver,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/verify-phrase') {
          return MaterialPageRoute(
            builder: (_) => Scaffold(
              body: Column(
                children: [
                  const Text('Verify Phrase Mock'),
                  Text(
                    'Args: ${(settings.arguments as List<String>?)?.join(",")}',
                  ),
                ],
              ),
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => ConfirmPhraseScreen(screenCaptureGuard: guard),
          settings: RouteSettings(
            name: '/confirm-phrase',
            arguments: mnemonicWords,
          ),
        );
      },
    );
  }

  testWidgets('renders all Figma elements and initial state', (tester) async {
    tester.view.physicalSize = const Size(440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final guard = _FakeScreenCaptureGuard();
    await tester.pumpWidget(createScreen(guard: guard));
    await tester.pumpAndSettle();

    // Verify ScreenCaptureGuard was enabled
    expect(guard.enableCalls, 1);

    // Verify Top Back Button
    expect(find.byKey(const Key('confirm_phrase_back_button')), findsOneWidget);

    // Verify Title & Subtitle
    expect(find.text('Confirm your secret phrase'), findsOneWidget);
    expect(
      find.text(
        'Please acknowledge the following security measures to ensure the safety of your digital vault.',
      ),
      findsOneWidget,
    );

    // Verify 3 Checklist Items
    expect(find.byKey(const Key('confirm_phrase_check_1')), findsOneWidget);
    expect(find.byKey(const Key('confirm_phrase_check_2')), findsOneWidget);
    expect(find.byKey(const Key('confirm_phrase_check_3')), findsOneWidget);

    // Verify Continue Button exists and tapping it when uncompleted does nothing
    final continueButton = find.byKey(const Key('confirm_phrase_continue_button'));
    expect(continueButton, findsOneWidget);
    await tester.tap(continueButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Verify Phrase Mock'), findsNothing);
  });

  testWidgets('toggles checklist items and activates Continue CTA only when all checked',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createScreen(
        mnemonicWords: ['word1', 'word2', 'word3'],
      ),
    );
    await tester.pumpAndSettle();

    final check1 = find.byKey(const Key('confirm_phrase_check_1'));
    final check2 = find.byKey(const Key('confirm_phrase_check_2'));
    final check3 = find.byKey(const Key('confirm_phrase_check_3'));
    final continueButton = find.byKey(const Key('confirm_phrase_continue_button'));

    // Check 1
    await tester.tap(check1);
    await tester.pumpAndSettle();
    await tester.tap(continueButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Verify Phrase Mock'), findsNothing);

    // Check 2
    await tester.tap(check2);
    await tester.pumpAndSettle();
    await tester.tap(continueButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Verify Phrase Mock'), findsNothing);

    // Check 3 -> all checked
    await tester.tap(check3);
    await tester.pumpAndSettle();

    // Now tap Continue -> should navigate to /verify-phrase with arguments forwarded
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(find.text('Verify Phrase Mock'), findsOneWidget);
    expect(find.text('Args: word1,word2,word3'), findsOneWidget);
  });

  testWidgets('unchecking any item disables Continue button', (tester) async {
    tester.view.physicalSize = const Size(440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createScreen(
        mnemonicWords: ['word1', 'word2', 'word3'],
      ),
    );
    await tester.pumpAndSettle();

    final check1 = find.byKey(const Key('confirm_phrase_check_1'));
    final check2 = find.byKey(const Key('confirm_phrase_check_2'));
    final check3 = find.byKey(const Key('confirm_phrase_check_3'));
    final continueButton = find.byKey(const Key('confirm_phrase_continue_button'));

    await tester.tap(check1);
    await tester.tap(check2);
    await tester.tap(check3);
    await tester.pumpAndSettle();

    // Uncheck check 2
    await tester.tap(check2);
    await tester.pumpAndSettle();

    await tester.tap(continueButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Verify Phrase Mock'), findsNothing);
  });

  testWidgets('tapping back button pops the navigator', (tester) async {
    tester.view.physicalSize = const Size(440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final guard = _FakeScreenCaptureGuard();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfirmPhraseScreen(screenCaptureGuard: guard),
                  ),
                );
              },
              child: const Text('Go to Confirm'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to ConfirmPhraseScreen
    await tester.tap(find.text('Go to Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your secret phrase'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byKey(const Key('confirm_phrase_back_button')));
    await tester.pumpAndSettle();

    // Back on initial screen, and guard was disabled
    expect(find.text('Go to Confirm'), findsOneWidget);
    expect(guard.disableCalls, 1);
  });
}
