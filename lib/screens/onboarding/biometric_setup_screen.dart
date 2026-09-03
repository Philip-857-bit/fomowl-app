import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _faceIdEnabled = false;
  bool _fingerprintAvailable = false;
  bool _faceIdAvailable = false;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final svc = BiometricService();
    final canCheck = await svc.canCheckBiometrics();
    final isSupported = await svc.isDeviceSupported();
    if (!canCheck || !isSupported) return;
    final hasFp = await svc.hasFingerprint();
    final hasFace = await svc.hasFaceId();
    if (mounted) {
      setState(() {
        _fingerprintAvailable = hasFp;
        _faceIdAvailable = hasFace;
      });
    }
  }

  Future<void> _continue() async {
    if (_fingerprintEnabled) {
      await _storage.setFingerprintEnabled(true);
      if (mounted) Navigator.pushNamed(context, '/fingerprint-verification');
    } else if (_faceIdEnabled) {
      await _storage.setFaceIdEnabled(true);
      if (mounted) Navigator.pushNamed(context, '/face-id-verification');
    } else {
      if (mounted) Navigator.pushNamed(context, '/congratulations');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFFEA2A33),
                  size: 20,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Image.asset(
                        'assets/images/shield_owl.png',
                        height: 260,
                        fit: BoxFit.contain,
                        errorBuilder: (e, s, t) => Image.asset(
                          'assets/images/owl_lock.png',
                          height: 260,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Shield Your Wallet',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.normal,
                          color: const Color(0xFFE2E2E2),
                          letterSpacing: -1.08,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Adding biometric security will ensure you are the only one that can access your wallet',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFFB7B5B4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildCard(
                        iconAsset: 'assets/images/face_id_icon.png',
                        fallbackIcon: Icons.face,
                        title: 'Face ID',
                        subtitle: 'Use face ID Authentication',
                        value: _faceIdEnabled,
                        available: _faceIdAvailable,
                        onChanged: (v) => setState(() => _faceIdEnabled = v),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        iconAsset: 'assets/images/fingerprint_icon.png',
                        fallbackIcon: Icons.fingerprint,
                        title: 'Fingerprint ID',
                        subtitle: 'Use fingerprint Authentication',
                        value: _fingerprintEnabled,
                        available: _fingerprintAvailable,
                        onChanged: (v) =>
                            setState(() => _fingerprintEnabled = v),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: _continue,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA2A33),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEA2A33)
                                    .withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Text(
                            'NEXT',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: 1.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String iconAsset,
    required IconData fallbackIcon,
    required String title,
    required String subtitle,
    required bool value,
    required bool available,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: available ? 1.0 : 0.45,
      child: Container(
        height: 67,
        padding: const EdgeInsets.symmetric(horizontal: 25),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF5D3F3D).withValues(alpha: 0.12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              iconAsset,
              width: 35,
              height: 35,
              fit: BoxFit.contain,
              errorBuilder: (e, s, t) =>
                  Icon(fallbackIcon, color: const Color(0xFFEA2A33), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: const Color(0xFFE2E2E2),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.54),
                      letterSpacing: -0.08,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: available ? onChanged : null,
              activeTrackColor: const Color(0xFFEA2A33),
              activeThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFF575555),
              inactiveThumbColor: Colors.white,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}
