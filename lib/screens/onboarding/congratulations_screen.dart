import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/screen_capture_guard.dart';
import '../../widgets/mobile_scaffold.dart';

/// Congratulations Screen
/// Success screen after completing wallet setup
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
    } catch (_) {
      // Best effort only.
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Dancing owls illustration
            Image.asset(
              'assets/images/dancing_owls.png',
              width: 300,
              height: 300,
              errorBuilder: (context, error, stackTrace) {
                // Placeholder if image not found
                return SizedBox(
                  width: 300,
                  height: 300,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration, size: 80, color: Colors.grey),
                      SizedBox(width: 20),
                      Icon(
                        Icons.celebration,
                        size: 80,
                        color: Color(0xFFEB3F3F),
                      ),
                      SizedBox(width: 20),
                      Icon(Icons.celebration, size: 80, color: Colors.brown),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 60),

            // Title
            Text(
              'Congratulation',
              style: GoogleFonts.outfit(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Subtitle
            Text(
              'You are now an official Owlian',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(flex: 3),

            // Enter wallet button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _isNavigating ? null : _enterWallet,
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

            const SizedBox(height: 40),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
