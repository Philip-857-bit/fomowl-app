import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_two_factor_service.dart';

/// Centralized helper that enforces biometric/passcode verification
/// before revealing sensitive wallet information (seed phrase, private key, etc.).
class SensitiveAccessGuard {
  SensitiveAccessGuard._();

  static final WalletTwoFactorService _walletTwoFactorService =
      WalletTwoFactorService();
  static final BiometricService _biometricService = BiometricService();
  static final StorageService _storage = StorageService();

  // Passcode rules must match the unlock screen (digit-only PIN pad,
  // 6-12 digits); otherwise a passcode set here could be impossible to
  // re-enter and would lock the user out of the wallet.
  static const int _minPasscodeLength = 6;
  static const int _maxPasscodeLength = 12;
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// Returns true if the user successfully authenticates.
  ///
  /// Security: this guard must never grant access to sensitive material (seed
  /// phrase, private key) without an authentication factor. If neither
  /// biometrics nor a passcode is configured, the user is required to create a
  /// passcode here before access is granted — it is never auto-allowed.
  static Future<bool> verify(
    BuildContext context, {
    String? reason,
    bool requireTwoFactor = true,
  }) async {
    final l = AppLocalizations.of(context);
    var primaryAuthenticated = false;

    // Prefer biometrics when the user has opted in.
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    if (biometricEnabled) {
      final success = await _biometricService.authenticate(
        localizedReason: reason ?? l.unlockWalletReason,
      );
      if (success) {
        primaryAuthenticated = true;
      }
    }

    // Fall back to passcode. When no passcode exists, require the user to set
    // one now rather than failing open and granting access with no factor.
    var hasPasscode = await _storage.hasPasscode();
    if (!primaryAuthenticated) {
      if (!hasPasscode) {
        if (!context.mounted) return false;
        final created = await _promptToCreatePasscode(context);
        if (!created) {
          return false;
        }
        hasPasscode = true;
        primaryAuthenticated = true;
      } else {
        if (!context.mounted) return false;
        primaryAuthenticated = await _promptForPasscode(context);
      }
    }

    if (!primaryAuthenticated) {
      return false;
    }

    if (!requireTwoFactor) {
      return true;
    }

    // The persisted app-wide 2FA authority is authoritative. Refreshing here
    // keeps the decision independent of whichever wallet is currently active
    // and repairs stale local state after startup or a wallet switch.
    final cachedTwoFactorEnabled = await _storage.isTwoFactorEnabled();
    final twoFactorStatus = await _walletTwoFactorService
        .fetchTwoFactorStatus();
    final twoFactorEnabled = twoFactorStatus['success'] == true
        ? twoFactorStatus['enabled'] == true
        : cachedTwoFactorEnabled;
    if (twoFactorStatus['success'] == true &&
        twoFactorEnabled != cachedTwoFactorEnabled) {
      await _storage.setTwoFactorEnabled(twoFactorEnabled);
    }
    if (!twoFactorEnabled) {
      return true;
    }

    if (!hasPasscode || !context.mounted) {
      return false;
    }

    return _promptForTwoFactorCode(
      context,
      title: 'Owllet Authenticator',
      subtitle: 'Enter the 6-digit authenticator code to continue.',
    );
  }

  static Future<bool> _promptForPasscode(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            bool hasError = false;
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                backgroundColor: AppColors.cardDark,
                title: Text(
                  title ?? l.enterPasscodeTitle,
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subtitle != null && subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            subtitle,
                            style: GoogleFonts.outfit(color: Colors.white70),
                          ),
                        ),
                      ),
                    TextField(
                      controller: controller,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: l.passcodeHint,
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        errorText: hasError ? l.incorrectPasscode : null,
                      ),
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      l.cancel,
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      // Honor the same brute-force lockout the unlock screen
                      // uses, so sensitive reveals can't bypass it.
                      if (await _storage.isLockedOut()) {
                        if (!context.mounted) return;
                        setState(() => hasError = true);
                        return;
                      }
                      final isValid = await _storage.verifyPasscode(
                        controller.text.trim(),
                      );
                      if (!context.mounted) return;
                      if (isValid) {
                        await _storage.resetFailedAttempts();
                        if (!context.mounted) return;
                        Navigator.pop(context, true);
                      } else {
                        await _storage.incrementFailedAttempts();
                        final attempts = await _storage.getFailedAttempts();
                        if (attempts >= StorageService.maxFailedAttempts) {
                          await _storage.setLockout();
                        }
                        if (!context.mounted) return;
                        setState(() => hasError = true);
                      }
                    },
                    child: Text(
                      l.confirm,
                      style: GoogleFonts.outfit(color: AppColors.accentRed),
                    ),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  /// Prompts the user to create a passcode when none exists, so the guard can
  /// require an authentication factor instead of failing open. Returns true
  /// only when a valid passcode is entered, confirmed, and saved.
  static Future<bool> _promptToCreatePasscode(BuildContext context) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            String? errorText;
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                backgroundColor: AppColors.cardDark,
                title: Text(
                  'Set a passcode',
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a passcode to protect access to sensitive wallet '
                      'details. You will need it to reveal this information.',
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_maxPasscodeLength),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Enter a passcode (6-12 digits)',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                      ),
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_maxPasscodeLength),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Confirm passcode',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        errorText: errorText,
                      ),
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final passcode = controller.text.trim();
                      final confirm = confirmController.text.trim();
                      // Mirror the unlock screen's contract: the unlock PIN pad
                      // is digit-only and caps at _maxPasscodeLength, so a
                      // passcode that violates either rule could never be
                      // re-entered to unlock the app.
                      if (!_digitsOnly.hasMatch(passcode) ||
                          passcode.length < _minPasscodeLength ||
                          passcode.length > _maxPasscodeLength) {
                        setState(
                          () => errorText =
                              'Passcode must be $_minPasscodeLength-$_maxPasscodeLength digits.',
                        );
                        return;
                      }
                      if (passcode != confirm) {
                        setState(() => errorText = 'Passcodes do not match.');
                        return;
                      }
                      await _storage.savePasscode(passcode);
                      await _storage.resetFailedAttempts();
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    },
                    child: Text(
                      'Save',
                      style: GoogleFonts.outfit(color: AppColors.accentRed),
                    ),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  static Future<bool> _promptForTwoFactorCode(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) async {
    final controller = TextEditingController();
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            var errorText = '';
            var submitting = false;
            return StatefulBuilder(
              builder: (dialogContext, setState) => AlertDialog(
                backgroundColor: AppColors.cardDark,
                title: Text(
                  title,
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '123456',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        errorText: errorText.isEmpty ? null : errorText,
                      ),
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final code = controller.text.trim();
                            if (code.length != 6) {
                              setState(() {
                                errorText = 'Enter the 6-digit code from your authenticator app.';
                              });
                              return;
                            }

                            setState(() {
                              submitting = true;
                              errorText = '';
                            });
                            final result = await _walletTwoFactorService
                                .confirmTwoFactorCode(code: code);
                            if (!dialogContext.mounted) {
                              return;
                            }
                            if (result['success'] == true) {
                              Navigator.pop(dialogContext, true);
                              return;
                            }
                            setState(() {
                              submitting = false;
                              errorText =
                                  result['error']?.toString() ??
                                  'Invalid authenticator code.';
                            });
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentRed,
                            ),
                          )
                        : Text(
                            'Verify',
                            style: GoogleFonts.outfit(
                              color: AppColors.accentRed,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
  }
}
