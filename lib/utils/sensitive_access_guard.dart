import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';

/// Centralized helper that enforces biometric/passcode verification
/// before revealing sensitive wallet information (seed phrase, private key, etc.).
class SensitiveAccessGuard {
  SensitiveAccessGuard._();

  static final BiometricService _biometricService = BiometricService();
  static final StorageService _storage = StorageService();

  /// Returns true if the user successfully authenticates (or no auth is required).
  static Future<bool> verify(BuildContext context, {String? reason}) async {
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

    // Fall back to passcode if configured. When no passcode is set, allow access.
    final hasPasscode = await _storage.hasPasscode();
    if (!primaryAuthenticated) {
      if (!hasPasscode) {
        primaryAuthenticated = true;
      } else {
        if (!context.mounted) return false;
        primaryAuthenticated = await _promptForPasscode(context);
      }
    }

    if (!primaryAuthenticated) {
      return false;
    }

    final twoFactorEnabled = await _storage.isTwoFactorEnabled();
    if (!twoFactorEnabled) {
      return true;
    }

    if (!hasPasscode || !context.mounted) {
      return false;
    }

    return _promptForPasscode(
      context,
      title: 'Wallet Shield 2FA',
      subtitle: 'Confirm this protected wallet action.',
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
                      final isValid = await _storage.verifyPasscode(
                        controller.text.trim(),
                      );
                      if (!context.mounted) return;
                      if (isValid) {
                        Navigator.pop(context, true);
                      } else {
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
}
