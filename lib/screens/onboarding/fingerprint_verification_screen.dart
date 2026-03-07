import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/biometric_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';

/// Fingerprint Verification Screen
/// Prompts user to scan their fingerprint
class FingerprintVerificationScreen extends StatefulWidget {
  const FingerprintVerificationScreen({super.key});

  @override
  State<FingerprintVerificationScreen> createState() =>
      _FingerprintVerificationScreenState();
}

class _FingerprintVerificationScreenState
    extends State<FingerprintVerificationScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    // Automatically trigger system biometric prompt when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verify();
    });
  }

  Future<void> _verify() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _isVerifying = true;
    });

    try {
      // Attempt biometric authentication
      final authenticated = await _biometricService.authenticate(
        localizedReason: l.fingerprintVerifyReason,
      );

      if (mounted) {
        if (authenticated) {
          // Success - navigate to congratulations
          Navigator.pushReplacementNamed(context, '/congratulations');
        } else {
          // Failed - show error
          ToastUtils.showError(l.fingerprintVerificationFailed);
          setState(() {
            _isVerifying = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(l.biometricUnavailable);
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Back button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),

            const Spacer(flex: 2),

            // Fingerprint icon
            Icon(Icons.fingerprint, size: 200, color: const Color(0xFFEB3F3F)),

            const SizedBox(height: 60),

            // Instruction text
            Text(
              _isVerifying ? l.verifying : l.fingerprintVerificationTitle,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Text(
              _isVerifying
                  ? l.biometricPromptInstruction
                  : l.fingerprintPromptInstruction,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(flex: 3),

            // Verify button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC03F2E), Color(0xFF640C0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isVerifying
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              l.verify,
                              style: GoogleFonts.outfit(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
