import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/screens/onboarding/create_wallet_screen.dart';
import 'package:fomowl_wallet/screens/onboarding/verify_phrase_screen.dart';
import 'package:fomowl_wallet/screens/profile/backup_seed_phrase_screen.dart';
import 'package:fomowl_wallet/services/screen_capture_guard.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

import 'dart:math';

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
    testWidgets(
      'seed phrase flow no longer exposes clipboard actions',
      skip: true,
      (tester) async {
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
      },
    );

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
            errorNotifier: (_) {},
          ),
        ),
      );
      await _pumpUi(tester);

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
      await _pumpUi(tester);

      await _revealPhrase(tester);
      expect(find.text('I backed it up'), findsOneWidget);

      await tester.tap(find.text('Hide'));
      await _pumpUi(tester);
      expect(find.text('I backed it up'), findsNothing);

      await _revealPhrase(tester);
      expect(find.text('I backed it up'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await _pumpUi(tester);
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

      await _pumpUi(tester);
      expect(guard.enableCalls, 1);

      await _revealPhrase(tester);
      expect(find.text('alpha'), findsOneWidget);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();

      expect(guard.disableCalls, 1);
      expect(find.text('alpha'), findsNothing);
    });

    testWidgets('lifecycle pause clears revealed sensitive state', (
      tester,
    ) async {
      final lifecycle = ValueNotifier<AppLifecycleState>(
        AppLifecycleState.resumed,
      );
      await tester.pumpWidget(
        _wrap(
          BackupSeedPhraseScreen(
            walletService: _FakeWalletService(_mnemonic),
            authVerifier: _allowAuth,
            screenCaptureGuard: _FakeScreenCaptureGuard(),
            lifecycleListenable: lifecycle,
          ),
        ),
      );
      await _pumpUi(tester);

      await _revealPhrase(tester);
      expect(find.text('I backed it up'), findsOneWidget);

      lifecycle.value = AppLifecycleState.paused;
      await _pumpUi(tester);

      expect(find.text('I backed it up'), findsNothing);
      expect(find.text('Tap to reveal'), findsOneWidget);
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
        await _pumpUi(tester);

        await _revealPhrase(tester);
        expect(find.text('alpha'), findsOneWidget);

        await tester.tap(find.text('I backed it up'));
        await _pumpUi(tester);

        expect(find.text('Confirm your backup'), findsOneWidget);
        expect(find.text('Hide'), findsNothing);
      },
    );

    testWidgets('verification card accepts the correct backup answers', (
      tester,
    ) async {
      var verified = false;
      final challenge = SeedPhraseVerificationChallenge.generate(
        _mnemonic.split(' '),
        random: Random(1),
      );
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SingleChildScrollView(
              child: Material(
                child: SeedPhraseBackupVerificationCard(
                  words: _mnemonic.split(' '),
                  challenge: challenge,
                  onVerified: () => verified = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final words = _mnemonic.split(' ');
      for (final index in challenge.requestedIndices) {
        final correctWord = words[index];
        await tester.ensureVisible(
          find.byKey(ValueKey('seed-word-$index-$correctWord')),
        );
        await tester.tap(find.byKey(ValueKey('seed-word-$index-$correctWord')));
      }
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('verify-backup-button')),
      );
      await tester.tap(find.byKey(const ValueKey('verify-backup-button')));
      await tester.pumpAndSettle();

      expect(verified, isTrue);
    });

    testWidgets('verification card rejects incorrect answers', (tester) async {
      var verified = false;
      final words = _mnemonic.split(' ');
      final challenge = SeedPhraseVerificationChallenge.generate(
        words,
        random: Random(3),
      );
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SingleChildScrollView(
              child: Material(
                child: SeedPhraseBackupVerificationCard(
                  words: words,
                  challenge: challenge,
                  onVerified: () => verified = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final index in challenge.requestedIndices) {
        final wrongWord = challenge.options[index]!.firstWhere(
          (option) => option != words[index],
        );
        await tester.ensureVisible(
          find.byKey(ValueKey('seed-word-$index-$wrongWord')),
        );
        await tester.tap(find.byKey(ValueKey('seed-word-$index-$wrongWord')));
      }
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('verify-backup-button')),
      );
      await tester.tap(find.byKey(const ValueKey('verify-backup-button')));
      await tester.pumpAndSettle();

      expect(verified, isFalse);
      expect(
        find.text('That backup check did not match. Try again.'),
        findsOneWidget,
      );
    });

    test('verification challenge randomizes requested indices by session', () {
      final words = _mnemonic.split(' ');
      final challengeA = SeedPhraseVerificationChallenge.generate(
        words,
        random: Random(1),
      );
      final challengeB = SeedPhraseVerificationChallenge.generate(
        words,
        random: Random(2),
      );

      expect(
        challengeA.requestedIndices,
        isNot(equals(challengeB.requestedIndices)),
      );
      expect(challengeA.requestedIndices.length, 3);
      expect(challengeB.requestedIndices.length, 3);

      for (final challenge in [challengeA, challengeB]) {
        for (final index in challenge.requestedIndices) {
          final options = challenge.options[index]!;
          expect(options, contains(words[index]));
          expect(options.toSet().length, options.length);
        }
      }
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
  final confirmation = find.text('I Understand');
  if (confirmation.evaluate().isNotEmpty) {
    await tester.tap(confirmation);
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
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
  Future<WalletAccount?> getActiveWalletAccount() async => null;

  @override
  Future<String?> getMnemonic([String? address]) async => mnemonic;
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
