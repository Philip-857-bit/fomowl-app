import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/biometric_service.dart';
import '../../utils/toast_utils.dart';

/// Face Capture Screen
/// Uses system biometric prompt for face authentication
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  Map<String, bool>? _biometricSettings;
  final BiometricService _biometricService = BiometricService();
  bool _isVerifying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _biometricSettings ??=
        ModalRoute.of(context)?.settings.arguments as Map<String, bool>?;
  }

  @override
  void initState() {
    super.initState();
    // Automatically trigger biometric prompt when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBiometricVerification();
    });
  }

  Future<void> _startBiometricVerification() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      // Use system biometric prompt
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Verify your face to secure your wallet',
      );

      if (mounted) {
        if (authenticated) {
          // Success - check if fingerprint is also needed
          final fingerprintEnabled =
              _biometricSettings?['fingerprintEnabled'] ?? false;

          if (fingerprintEnabled) {
            // Navigate to fingerprint verification
            Navigator.pushReplacementNamed(
              context,
              '/fingerprint-verification',
            );
          } else {
            // Go directly to congratulations
            Navigator.pushReplacementNamed(context, '/congratulations');
          }
        } else {
          // Failed - show error and allow retry
          ToastUtils.showError('Face verification failed. Please try again.');
          setState(() {
            _isVerifying = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(
          'Biometric authentication not available on this device',
        );
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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

            // Face icon
            Icon(Icons.face, size: 200, color: const Color(0xFFEB3F3F)),

            const SizedBox(height: 60),

            // Instruction text
            Text(
              _isVerifying ? 'Verifying...' : 'Face Verification',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Text(
              _isVerifying
                  ? 'Please authenticate using your device biometric'
                  : 'Tap the button below to verify your face',
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
                  onPressed: _isVerifying ? null : _startBiometricVerification,
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
                              'Verify Face',
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
