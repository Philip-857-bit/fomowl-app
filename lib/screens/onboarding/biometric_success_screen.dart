import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/mobile_scaffold.dart';

/// Biometric Success Screen – shown after successful biometric setup (Figma 41:476)
class BiometricSuccessScreen extends StatelessWidget {
  const BiometricSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
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
                              color: const Color(
                                0xFFEA2A33,
                              ).withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        Container(
                          width: 211,
                          height: 211,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFFEA2A33,
                              ).withValues(alpha: 0.2),
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
                              color: const Color(
                                0xFF5D3F3D,
                              ).withValues(alpha: 0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFEA2A33,
                                ).withValues(alpha: 0.4),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          'assets/images/biometric_checkmark.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                          errorBuilder: (e, s, t) => const Icon(
                            Icons.check,
                            color: Color(0xFFEA2A33),
                            size: 80,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Biometrics Enabled',
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
                      'Your device is now biometrically secured. Fast, frictionless access is active.',
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
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: GestureDetector(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/congratulations'),
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA2A33),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA2A33).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
