import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Background color shared between the native splash screen and this widget.
/// Must match:
///   - Android: @color/splash_background (#000000)
///   - iOS: UILaunchScreen background (#000000)
const Color kSplashBackground = Color(0xFF000000);

/// Accent red used in the Figma splash design.
const Color _kSplashAccent = Color(0xFFEA2A33);

/// Exported Figma splash mark: owl, wordmark, and tagline as one centered unit.
const String _kSplashMarkAsset = 'assets/images/splash.png';

class SplashScreenBody extends StatelessWidget {
  final Animation<double> scaleAnimation;

  const SplashScreenBody({super.key, required this.scaleAnimation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSplashBackground,
      body: ScaleTransition(
        alignment: Alignment.center,
        scale: scaleAnimation,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: const Alignment(0, -0.07),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final markWidth = (constraints.maxWidth - 48)
                        .clamp(0.0, 254.0)
                        .toDouble();

                    return Image.asset(
                      _kSplashMarkAsset,
                      width: markWidth,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, err, stack) => SizedBox(
                        width: markWidth,
                        height: markWidth,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white24,
                            size: 64,
                          ),
                        ),
                      ),
                    );
                  },
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
      ),
    );
  }
}
