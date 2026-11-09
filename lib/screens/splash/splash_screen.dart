import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Background color shared between the native splash screen and this widget.
/// Must match:
///   - Android: @color/splash_background (#000000)
///   - iOS: UILaunchScreen background (#000000)
const Color kSplashBackground = Color(0xFF000000);

/// Accent red used in the Figma splash design.
const Color _kSplashAccent = Color(0xFFEA2A33);

/// Owl icon asset for the splash screen mark.
const String _kSplashLogoAsset = 'assets/images/splash.png';

class SplashScreenBody extends StatelessWidget {
  const SplashScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSplashBackground,
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: const Alignment(0, -0.07),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    _kSplashLogoAsset,
                    width: 56,
                    height: 62,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, err, stack) => const SizedBox(
                      width: 56,
                      height: 62,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Owllet',
                        style: GoogleFonts.poppins(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Trade instantly. Spend Effortlessly',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _kSplashAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 28),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                    children: const [
                      TextSpan(
                        text: 'by ',
                        style: TextStyle(
                          color: _kSplashAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: 'FOMOwl Inc',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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
}
