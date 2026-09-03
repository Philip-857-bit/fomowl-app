import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/screen_capture_guard.dart';
import '../../widgets/mobile_scaffold.dart';

/// Congratulations Screen – Figma 41:761
class CongratulationsScreen extends StatefulWidget {
  const CongratulationsScreen({super.key});

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen> {
  final ScreenCaptureGuard _screenCaptureGuard = ScreenCaptureGuard();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_screenCaptureGuard.disableProtection());
  }

  Future<void> _enterWallet() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    try {
      await _screenCaptureGuard.disableProtection();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/blockchain-selection');
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 384,
                  height: 384,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5451).withValues(alpha: 0.1),
                        blurRadius: 60,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 24),
                Image.asset(
                  'assets/images/dancing_owls.png',
                  width: 343,
                  height: 248,
                  fit: BoxFit.cover,
                  errorBuilder: (e, s, t) => const Icon(
                    Icons.celebration,
                    color: Color(0xFFEA2A33),
                    size: 120,
                  ),
                ),
                const SizedBox(height: 50),
                Text(
                  'Congratulations',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE2E2E2),
                    letterSpacing: -1.8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You are now an official Owlian',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFFC8C6C5).withValues(alpha: 0.8),
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: GestureDetector(
                    onTap: _isNavigating ? null : _enterWallet,
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA2A33),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA2A33)
                                .withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isNavigating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Enter wallet',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE2E2E2),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
