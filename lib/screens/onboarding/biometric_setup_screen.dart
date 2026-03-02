import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';

/// Biometric Setup Screen
/// Optional screen to enable Face ID or Fingerprint authentication
class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _fingerprintEnabled = false;
  final StorageService _storage = StorageService();
  bool _biometricsAvailable = true; // Start as true, will update after check

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final biometricService = BiometricService();
    final canCheck = await biometricService.canCheckBiometrics();
    final isSupported = await biometricService.isDeviceSupported();
    final hasFingerprint = await biometricService.hasFingerprint();

    if (mounted) {
      setState(() {
        _biometricsAvailable = canCheck && isSupported && hasFingerprint;
      });
    }
  }

  Future<void> _continue() async {
    // If biometrics not available, skip to congratulations
    if (!_biometricsAvailable) {
      if (mounted) {
        Navigator.pushNamed(context, '/congratulations');
      }
      return;
    }

    // Save biometric preferences
    if (_fingerprintEnabled) {
      await _storage.setFingerprintEnabled(true);

      // Go directly to fingerprint verification
      if (mounted) {
        Navigator.pushNamed(context, '/fingerprint-verification');
      }
    } else {
      // Skip biometrics, go to congratulations
      if (mounted) {
        Navigator.pushNamed(context, '/congratulations');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Owl padlock illustration
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/owl_lock.png',
                    width: 150,
                    height: 150,
                    errorBuilder: (context, error, stackTrace) {
                      // Placeholder if image not found
                      return const Icon(
                        Icons.lock,
                        size: 100,
                        color: Colors.white54,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                'Shield Your Wallet',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Adding biometric security will ensure you are\nthe only one that can access your wallet',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Biometrics not available message
              if (!_biometricsAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Biometric authentication is not available on this device',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!_biometricsAvailable) const SizedBox(height: 20),

              // Fingerprint option
              _buildBiometricOption(
                icon: Icons.fingerprint,
                title: 'Fingerprint ID',
                subtitle: 'Use fingerprint Authentication',
                value: _fingerprintEnabled,
                enabled: _biometricsAvailable,
                onChanged: (value) {
                  if (_biometricsAvailable) {
                    setState(() {
                      _fingerprintEnabled = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 40),

              // Next button
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _continue,
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
                      child: Text(
                        'Next',
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2B2B).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: SwitchListTile(
          value: value,
          onChanged: enabled ? onChanged : null,
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEB3F3F).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFEB3F3F), size: 24),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          activeTrackColor: const Color(0xFFEB3F3F),
          activeThumbColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}
