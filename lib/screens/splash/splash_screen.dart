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
const String _kSplashLogoAsset = 'assets/images/logo.png';

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
              child: const _SplashBrand(),
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

/// Keep the wordmark and tagline aligned using their actual font metrics.
class _SplashBrand extends StatelessWidget {
  const _SplashBrand();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PaintingBinding.instance.systemFonts,
    builder: (context, child) => _buildBrand(context),
  );

  Widget _buildBrand(BuildContext context) {
    const title = 'Owllet';
    const tagline = 'Trade instantly. Spend Effortlessly';
    final titleStyle = GoogleFonts.poppins(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1,
    );
    final taglineStyle = GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: _kSplashAccent,
    );
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final titleMeasure = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final taglineMeasure = TextPainter(
      text: TextSpan(text: tagline, style: taglineStyle),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final textWidth = taglineMeasure.width;
    final titleSize = titleStyle.fontSize! * textWidth / titleMeasure.width;
    titleMeasure.dispose();
    taglineMeasure.dispose();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _kSplashLogoAsset,
              width: 56,
              height: 62,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stack) => const SizedBox(
                width: 56,
                height: 62,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white24,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: textWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    style: titleStyle.copyWith(fontSize: titleSize),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tagline,
                    maxLines: 1,
                    softWrap: false,
                    style: taglineStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
