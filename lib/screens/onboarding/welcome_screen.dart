import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/language_utils.dart';

/// Welcome Screen - Onboarding page after splash
/// Shows welcome message and wallet options
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Constrain width for web/desktop to mobile size
    final maxWidth = screenWidth > 600 ? 430.0 : screenWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: maxWidth,
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Adjust spacing based on available height
                    final isShortScreen = constraints.maxHeight < 700;

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              SizedBox(height: isShortScreen ? 60 : 100),

                              // Red FOMOwl logo
                              Image.asset(
                                'assets/images/logo.png',
                                width: isShortScreen ? 140 : 170,
                                height: isShortScreen ? 140 : 170,
                              ),

                              SizedBox(height: isShortScreen ? 30 : 50),

                              // Welcome heading
                              Text(
                                l.welcomeTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 14),

                              // Description text
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 50,
                                ),
                                child: Text(
                                  l.welcomeSubtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFD2D0D0),
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const Spacer(),

                              // Create wallet button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 52,
                                ),
                                child: _buildCreateWalletButton(context),
                              ),

                              const SizedBox(height: 20),

                              // Add existing wallet button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 52,
                                ),
                                child: _buildAddExistingWalletButton(context),
                              ),

                              SizedBox(height: isShortScreen ? 24 : 36),

                              // Terms of use text
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 46,
                                ),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.normal,
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                    children: [
                                      const TextSpan(
                                        text:
                                            'By continuing, you agree to the ',
                                      ),
                                      WidgetSpan(
                                        alignment:
                                            PlaceholderAlignment.baseline,
                                        baseline: TextBaseline.alphabetic,
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/terms-and-conditions',
                                            );
                                          },
                                          child: Text(
                                            'terms of use',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.normal,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: ' of fomowl'),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: isShortScreen ? 24 : 32),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Language selector overlay (top-right)
                Positioned(
                  top: 12,
                  right: 16,
                  child: _buildLanguageOverlay(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOverlay(BuildContext context) {
    final currentLanguage =
        LanguageUtils.languageNamesByCode[Localizations.localeOf(
          context,
        ).languageCode] ??
        AppLocalizations.of(context).chooseLanguage;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/language-selection'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              currentLanguage,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateWalletButton(BuildContext context) {
    return SizedBox(
      height: 53,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEA2A33),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          Navigator.pushNamed(context, '/create-wallet');
        },
        child: Text(
          AppLocalizations.of(context).createWallet,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAddExistingWalletButton(BuildContext context) {
    return SizedBox(
      height: 53,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF211212),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x59EA2A33), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          Navigator.pushNamed(context, '/import-wallet');
        },
        child: Text(
          AppLocalizations.of(context).importExistingWallet,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
