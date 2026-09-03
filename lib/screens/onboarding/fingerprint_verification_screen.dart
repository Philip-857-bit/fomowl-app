import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/mobile_scaffold.dart';

/// Fingerprint Verification Screen – intro (Figma 41:341)
class FingerprintVerificationScreen extends StatelessWidget {
  const FingerprintVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BiometricCircle(
                    child: Image.asset(
                      'assets/images/fingerprint_red.png',
                      width: 74,
                      height: 82,
                      fit: BoxFit.contain,
                      errorBuilder: (e, s, t) => const Icon(
                        Icons.fingerprint,
                        color: Color(0xFFEA2A33),
                        size: 80,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Fingerprint ID',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Accelerate secure access and authorize transaction instantly with your fingerprint.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFD2D0D0),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/fingerprint-check'),
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA2A33),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA2A33)
                                .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Verify',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.security,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/congratulations'),
                    child: Text(
                      'SKIP FOR NOW',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFB7B5B4),
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricCircle extends StatelessWidget {
  final Widget child;
  const _BiometricCircle({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEA2A33).withValues(alpha: 0.1),
              ),
            ),
          ),
          Container(
            width: 211,
            height: 211,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEA2A33).withValues(alpha: 0.2),
              ),
            ),
          ),
          Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF5D3F3D).withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA2A33).withValues(alpha: 0.4),
                  blurRadius: 7.5,
                ),
              ],
            ),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}
