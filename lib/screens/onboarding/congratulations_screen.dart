import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';

/// Congratulations Screen
/// Success screen after completing wallet setup
class CongratulationsScreen extends StatelessWidget {
  const CongratulationsScreen({super.key});

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
                  onPressed: () {
                    // Navigate to home screen and clear all previous routes
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
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
