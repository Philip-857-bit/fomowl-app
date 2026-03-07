import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/onboarding/create_wallet_screen.dart';
import 'package:fomowl_wallet/screens/onboarding/verify_phrase_screen.dart';
import 'package:fomowl_wallet/screens/profile/backup_seed_phrase_screen.dart';
import 'package:fomowl_wallet/services/screen_capture_guard.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (_) async => true);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
  });

  group('seed phrase hardening', () {
    testWidgets('seed phrase flow no longer exposes clipboard actions', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CreateWalletScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Copy to clipboard'), findsNothing);

      await tester.pumpWidget(_wrap(const VerifyPhraseScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Paste from clipboard'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          BackupSeedPhraseScreen(
            walletService: _FakeWalletService(_mnemonic),
            authVerifier: _allowAuth,
            screenCaptureGuard: _FakeScreenCaptureGuard(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy to clipboard'), findsNothing);
    });

    testWidgets('reveal requires fresh auth before showing phrase', (
      tester,
    ) async {
      var authCalls = 0;
      await tester.pumpWidget(
        _wrap(
          BackupSeedPhraseScreen(
            walletService: _FakeWalletService(_mnemonic),
            authVerifier: (context, {reason}) async {
              authCalls++;
              return false;
            },
            screenCaptureGuard: _FakeScreenCaptureGuard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap to reveal'));
      await tester.pump();

      expect(authCalls, 1);
      expect(find.text('alpha'), findsNothing);
    });

    testWidgets('manual hide and auto-hide both clear the revealed phrase', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupSeedPhraseScreen(
            walletService: _FakeWalletService(_mnemonic),
            authVerifier: _allowAuth,
            screenCaptureGuard: _FakeScreenCaptureGuard(),
            revealDuration: const Duration(seconds: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _revealPhrase(tester);
      expect(find.text('I backed it up'), findsOneWidget);

      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(find.text('I backed it up'), findsNothing);

      await _revealPhrase(tester);
      expect(find.text('I backed it up'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('I backed it up'), findsNothing);
    });

    testWidgets('navigating away clears state and restores capture settings', (
      tester,
    ) async {
      final guard = _FakeScreenCaptureGuard();
      await tester.pumpWidget(
        _wrap(
          BackupSeedPhraseScreen(
            walletService: _FakeWalletService(_mnemonic),
            authVerifier: _allowAuth,
            screenCaptureGuard: guard,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(guard.enableCalls, 1);

      await _revealPhrase(tester);
      expect(find.text('alpha'), findsOneWidget);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();

      expect(guard.disableCalls, 1);
      expect(find.text('alpha'), findsNothing);
    });

    testWidgets(
      'backup flow transitions into verification without re-exposing full phrase',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupSeedPhraseScreen(
              walletService: _FakeWalletService(_mnemonic),
              authVerifier: _allowAuth,
              screenCaptureGuard: _FakeScreenCaptureGuard(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _revealPhrase(tester);
        expect(find.text('alpha'), findsOneWidget);

        await tester.tap(find.text('I backed it up'));
        await tester.pumpAndSettle();

        expect(find.text('Confirm your backup'), findsOneWidget);
        expect(find.text('Hide'), findsNothing);
      },
    );

    testWidgets('verification card accepts the correct backup answers', (
      tester,
    ) async {
      var verified = false;
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SingleChildScrollView(
              child: Material(
                child: SeedPhraseBackupVerificationCard(
                  words: _mnemonic.split(' '),
                  onVerified: () => verified = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('seed-word-1-beta')),
      );
      await tester.tap(find.byKey(const ValueKey('seed-word-1-beta')));
      await tester.ensureVisible(find.byKey(const ValueKey('seed-word-6-eta')));
      await tester.tap(find.byKey(const ValueKey('seed-word-6-eta')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('seed-word-10-lambda')),
      );
      await tester.tap(find.byKey(const ValueKey('seed-word-10-lambda')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('verify-backup-button')),
      );
      await tester.tap(find.byKey(const ValueKey('verify-backup-button')));
      await tester.pumpAndSettle();

      expect(verified, isTrue);
    });
  });
}

const _mnemonic =
    'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu';

Future<bool> _allowAuth(BuildContext context, {String? reason}) async => true;

Future<void> _revealPhrase(WidgetTester tester) async {
  await tester.tap(find.text('Tap to reveal'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(find.text('I Understand'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

class _FakeWalletService extends WalletService {
  _FakeWalletService(this.mnemonic);

  final String? mnemonic;

  @override
  Future<String?> getMnemonic() async => mnemonic;
}

class _FakeScreenCaptureGuard extends ScreenCaptureGuard {
  _FakeScreenCaptureGuard() : super();

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
