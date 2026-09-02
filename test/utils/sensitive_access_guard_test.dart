import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/utils/sensitive_access_guard.dart';
import 'package:fomowl_wallet/services/biometric_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_two_factor_service.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';

class _FakeBiometricService extends BiometricService {
  bool isBiometricEnabledMock = false;
  bool authenticateResult = false;

  @override
  Future<bool> isBiometricEnabled() async => isBiometricEnabledMock;

  @override
  Future<bool> authenticate({String localizedReason = ''}) async =>
      authenticateResult;
}

class _FakeStorageService extends StorageService {
  bool hasPasscodeMock = true;
  bool isLockedOutMock = false;
  bool verifyPasscodeResult = true;
  bool isTwoFactorEnabledMock = false;
  int failedAttempts = 0;
  String? savedPasscode;
  bool promptPasscodeResult =
      false; // We can't easily mock this as it uses text field in dialog

  @override
  Future<bool> hasPasscode() async => hasPasscodeMock;

  @override
  Future<bool> isLockedOut() async => isLockedOutMock;

  @override
  Future<bool> verifyPasscode(String passcode) async => verifyPasscodeResult;

  @override
  Future<void> incrementFailedAttempts() async {
    failedAttempts++;
  }

  @override
  Future<int> getFailedAttempts() async => failedAttempts;

  @override
  Future<void> resetFailedAttempts() async {
    failedAttempts = 0;
  }

  @override
  Future<void> setLockout() async {
    isLockedOutMock = true;
  }

  @override
  Future<bool> isTwoFactorEnabled() async => isTwoFactorEnabledMock;

  @override
  Future<void> setTwoFactorEnabled(bool enabled) async {
    isTwoFactorEnabledMock = enabled;
  }

  @override
  Future<void> savePasscode(String passcode) async {
    savedPasscode = passcode;
  }
}

class _FakeWalletTwoFactorService extends WalletTwoFactorService {
  Map<String, dynamic> fetchStatusResult = {'success': true, 'enabled': false};
  Map<String, dynamic> confirmCodeResult = {'success': true};

  @override
  Future<Map<String, dynamic>> fetchTwoFactorStatus() async =>
      fetchStatusResult;

  @override
  Future<Map<String, dynamic>> confirmTwoFactorCode({
    required String code,
  }) async => confirmCodeResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBiometricService biometricService;
  late _FakeStorageService storageService;
  late _FakeWalletTwoFactorService twoFactorService;

  setUp(() {
    biometricService = _FakeBiometricService();
    storageService = _FakeStorageService();
    twoFactorService = _FakeWalletTwoFactorService();

    SensitiveAccessGuard.biometricServiceMock = biometricService;
    SensitiveAccessGuard.storageMock = storageService;
    SensitiveAccessGuard.walletTwoFactorServiceMock = twoFactorService;
  });

  tearDown(() {
    SensitiveAccessGuard.biometricServiceMock = null;
    SensitiveAccessGuard.storageMock = null;
    SensitiveAccessGuard.walletTwoFactorServiceMock = null;
  });

  Widget buildTestApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  group('verify without 2FA', () {
    testWidgets('uses biometric and returns true on success', (tester) async {
      biometricService.isBiometricEnabledMock = true;
      biometricService.authenticateResult = true;

      bool result = false;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveAccessGuard.verify(
                    context,
                    requireTwoFactor: false,
                  );
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('falls back to passcode when biometric fails', (tester) async {
      biometricService.isBiometricEnabledMock = true;
      biometricService.authenticateResult = false;
      storageService.hasPasscodeMock = true;
      storageService.verifyPasscodeResult = true;

      bool? result;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveAccessGuard.verify(
                    context,
                    requireTwoFactor: false,
                  );
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // Should show passcode dialog
      expect(find.byType(AlertDialog), findsOneWidget);

      // Enter correct passcode
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('prompts to create passcode when none exists', (tester) async {
      biometricService.isBiometricEnabledMock = false;
      storageService.hasPasscodeMock = false;

      bool? result;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveAccessGuard.verify(
                    context,
                    requireTwoFactor: false,
                  );
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // Should show set passcode dialog
      expect(find.text('Set a passcode'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));

      // Enter passcode
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter a passcode (6-12 digits)'),
        '123456',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm passcode'),
        '123456',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(storageService.savedPasscode, '123456');
    });

    testWidgets(
      'returns false when passcode verification fails and is cancelled',
      (tester) async {
        biometricService.isBiometricEnabledMock = false;
        storageService.hasPasscodeMock = true;
        storageService.verifyPasscodeResult = false;

        bool? result;

        await tester.pumpWidget(
          buildTestApp(
            Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await SensitiveAccessGuard.verify(
                      context,
                      requireTwoFactor: false,
                    );
                  },
                  child: const Text('Verify'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        // Show passcode dialog
        expect(find.byType(AlertDialog), findsOneWidget);

        // Enter wrong passcode
        await tester.enterText(find.byType(TextField), '111111');
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        // Still showing dialog because wrong passcode
        expect(find.byType(AlertDialog), findsOneWidget);

        // Cancel dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
      },
    );
  });

  group('verify with 2FA', () {
    testWidgets('returns true when 2FA is disabled', (tester) async {
      biometricService.isBiometricEnabledMock = true;
      biometricService.authenticateResult = true;
      storageService.isTwoFactorEnabledMock = false;
      twoFactorService.fetchStatusResult = {'success': true, 'enabled': false};

      bool result = false;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveAccessGuard.verify(
                    context,
                    requireTwoFactor: true,
                  );
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('shows 2FA prompt and returns true on valid code', (
      tester,
    ) async {
      biometricService.isBiometricEnabledMock = true;
      biometricService.authenticateResult = true;
      storageService.isTwoFactorEnabledMock = true;
      twoFactorService.fetchStatusResult = {'success': true, 'enabled': true};
      twoFactorService.confirmCodeResult = {'success': true};

      bool? result;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveAccessGuard.verify(
                    context,
                    requireTwoFactor: true,
                  );
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // Should show 2FA dialog
      expect(find.text('Owllet Authenticator'), findsOneWidget);

      // Enter valid code
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.widgetWithText(TextButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('returns false when 2FA code is cancelled', (tester) async {
      biometricService.isBiometricEnabledMock = true;
      biometricService.authenticateResult = true;
      storageService.isTwoFactorEnabledMock = true;
      twoFactorService.fetchStatusResult = {'success': true, 'enabled': true};

      bool? result;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveAccessGuard.verify(
                    context,
                    requireTwoFactor: true,
                  );
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // Should show 2FA dialog
      expect(find.text('Owllet Authenticator'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('updates local 2FA state from remote status', (tester) async {
      biometricService.isBiometricEnabledMock = true;
      biometricService.authenticateResult = true;

      // Local state thinks 2FA is OFF, but remote says ON
      storageService.isTwoFactorEnabledMock = false;
      twoFactorService.fetchStatusResult = {'success': true, 'enabled': true};
      twoFactorService.confirmCodeResult = {'success': true};

      bool? result;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveAccessGuard.verify(
                    context,
                    requireTwoFactor: true,
                  );
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // Local state should be updated
      expect(storageService.isTwoFactorEnabledMock, isTrue);

      // Should show 2FA dialog since remote was ON
      expect(find.text('Owllet Authenticator'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.widgetWithText(TextButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
