import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Background colour shared between the native splash screen and this widget.
/// Must match:
///   - Android: @color/splash_background  (#131313)
///   - iOS:     UILaunchScreen background  (#131313)
const Color kSplashBackground = Color(0xFF131313);

/// Accent red used in the Figma splash design.
const Color _kSplashAccent = Color(0xFFEA2A33);

/// Owl icon asset — should be exported with a transparent background.
const String _kOwlAsset = 'assets/images/splash_logo.png';

/// Pure-UI splash screen that mirrors the Figma design (node 41:26):
///
///   ┌──────────────────────────────────┐
///   │                                  │
///   │    [owl]  Owllet                 │  ← centred, slightly above mid
///   │     Trade instantly. Spend…      │  ← red tagline
///   │                                  │
///   │  by FOMOwl Inc                   │  ← bottom
///   └──────────────────────────────────┘
///
/// Callers own the [AnimationController]; pass the derived animations in.
class SplashScreenBody extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Animation<double> scaleAnimation;

  const SplashScreenBody({
    super.key,
    required this.fadeAnimation,
    required this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSplashBackground,
      body: FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: Column(
            children: [
              // ── Upper spacer — pushes logo to ~44 % from top (Figma: 402 / 956)
              const Spacer(flex: 44),

              // ── Logo row: owl icon + "Owllet" wordmark ──
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    _kOwlAsset,
                    width: 56,
                    height: 62,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Owllet',
                    style: GoogleFonts.poppins(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Red tagline ──
              Text(
                'Trade instantly. Spend Effortlessly',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kSplashAccent,
                ),
              ),

              // ── Lower spacer — fills remaining space above bottom text
              const Spacer(flex: 56),

              // ── Bottom credit ──
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28.0),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(fontSize: 22),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
