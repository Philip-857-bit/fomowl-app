import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';

/// Centralized helper that enforces biometric/passcode verification
/// before revealing sensitive wallet information (seed phrase, private key, etc.).
class SensitiveAccessGuard {
  SensitiveAccessGuard._();

  static final BiometricService _biometricService = BiometricService();
  static final StorageService _storage = StorageService();

  /// Returns true if the user successfully authenticates (or no auth is required).
  static Future<bool> verify(
    BuildContext context, {
    String reason = 'Authenticate to continue',
  }) async {
    // Prefer biometrics when the user has opted in.
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    if (biometricEnabled) {
      final success = await _biometricService.authenticate(
        localizedReason: reason,
      );
      if (success) return true;
    }

    // Fall back to passcode if configured. When no passcode is set, allow access.
    final passcode = await _storage.getPasscode();
    if (passcode == null || passcode.isEmpty) {
      return true;
    }

    if (!context.mounted) return false;
    return _promptForPasscode(context);
  }

  static Future<bool> _promptForPasscode(BuildContext context) async {
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
                  'Enter Passcode',
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
                content: TextField(
                  controller: controller,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Passcode',
                    hintStyle: GoogleFonts.outfit(color: Colors.white38),
                    errorText: hasError ? 'Incorrect passcode' : null,
                  ),
                  style: GoogleFonts.outfit(color: Colors.white),
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
                      'Confirm',
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
