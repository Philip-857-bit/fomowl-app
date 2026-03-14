import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/biometric_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';

/// Face ID Verification Screen - Initial prompt
class FaceIdVerificationScreen extends StatefulWidget {
  const FaceIdVerificationScreen({super.key});

  @override
  State<FaceIdVerificationScreen> createState() =>
      _FaceIdVerificationScreenState();
}

class _FaceIdVerificationScreenState extends State<FaceIdVerificationScreen> {
  Map<String, bool>? _biometricSettings;
  final BiometricService _biometricService = BiometricService();
  bool _isVerifying = false;
  bool _isFaceAvailable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _biometricSettings ??=
        ModalRoute.of(context)?.settings.arguments as Map<String, bool>?;
  }

  @override
  void initState() {
    super.initState();
    _detectBiometricType();
    // Automatically trigger system biometric prompt when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVerification();
    });
  }

  Future<void> _detectBiometricType() async {
    try {
      final availableBiometrics = await _biometricService
          .getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _isFaceAvailable = availableBiometrics.contains(BiometricType.face);
        });
      }
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
    }
  }

  Future<void> _startVerification() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _isVerifying = true;
    });

    try {
      final fingerprintEnabled =
          _biometricSettings?['fingerprintEnabled'] ?? false;

      // Use system biometric prompt directly
      final authenticated = await _biometricService.authenticate(
        localizedReason: l.identityVerifyReason,
      );

      if (mounted) {
        setState(() {
          _isVerifying = false;
        });

        if (authenticated) {
          // Success - check if fingerprint verification is also needed
          if (fingerprintEnabled) {
            Navigator.pushReplacementNamed(
              context,
              '/fingerprint-verification',
            );
          } else {
            Navigator.pushReplacementNamed(context, '/congratulations');
          }
        } else {
          // Failed - show error
          ToastUtils.showError(l.biometricVerificationFailed);
        }
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });

        ToastUtils.showError(l.biometricVerificationFailedWithPasscode);
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

            // Title — adapts to available biometric type
            Text(
              _isFaceAvailable
                  ? l.faceVerificationTitle
                  : l.biometricVerificationTitle,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 60),

            // Biometric icon — shows face or fingerprint based on device
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentRed, width: 3),
              ),
              child: Icon(
                _isFaceAvailable ? Icons.face : Icons.fingerprint,
                size: 120,
                color: AppColors.accentRed,
              ),
            ),

            const SizedBox(height: 60),

            // Instruction text
            Text(
              _isVerifying ? l.biometricPromptInstruction : l.tapBelowToVerify,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(flex: 3),

            // Start verification button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _startVerification,
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
                              l.startVerification,
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
