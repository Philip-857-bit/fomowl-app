import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'language_selection_screen.dart';

/// Welcome Screen - Onboarding page after splash
/// Shows language selector, welcome message, and wallet options
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Constrain width for web/desktop to mobile size
    final maxWidth = screenWidth > 600 ? 430.0 : screenWidth;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          width: maxWidth,
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            child: LayoutBuilder(
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
                          // Language selector at top
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                            child: _buildLanguageSelector(context),
                          ),

                          SizedBox(height: isShortScreen ? 20 : 30),

                          // 3D Owl wallet illustration
                          Image.asset(
                            'assets/images/owl_wallet.png',
                            width: isShortScreen ? 200 : 250,
                            height: isShortScreen ? 200 : 250,
                            errorBuilder: (context, error, stackTrace) {
                              // Placeholder if image not found
                              final size = isShortScreen ? 200.0 : 250.0;
                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet,
                                  size: 100,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          ),

                          SizedBox(height: isShortScreen ? 20 : 30),

                          // Welcome heading
                          Text(
                            AppLocalizations.of(context).welcomeTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 10),

                          // Description text
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 42),
                            child: Text(
                              AppLocalizations.of(context).welcomeSubtitle,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFD2D0D0),
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const Spacer(),

                          // Create wallet button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 38),
                            child: _buildCreateWalletButton(context),
                          ),

                          const SizedBox(height: 23),

                          // Add existing wallet button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 38),
                            child: _buildAddExistingWalletButton(context),
                          ),

                          SizedBox(height: isShortScreen ? 20 : 30),

                          // Terms of use text
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 46),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'By continuing, you agree to the ',
                                  ),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/terms-and-conditions',
                                        );
                                      },
                                      child: Text(
                                        'terms of use',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' of fomowl'),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () async {
            final languageCode = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionScreen(),
              ),
            );

            // If language was changed, update the app locale
            if (languageCode != null && mounted) {
              if (!context.mounted) return;
              // Update the app locale using the static method
              FOMOwlWalletApp.setLocale(context, languageCode);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, color: Colors.white, size: 29),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    AppLocalizations.languageNames[AppLocalizations.of(
                          context,
                        ).locale.languageCode] ??
                        'Choose your language',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateWalletButton(BuildContext context) {
    return Container(
      height: 53,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC03F2E), Color(0xFF640C0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC03F2E).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pushNamed(context, '/create-wallet');
          },
          child: Center(
            child: Text(
              'Create wallet',
              style: GoogleFonts.outfit(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddExistingWalletButton(BuildContext context) {
    return Container(
      height: 53,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC03F2E), width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pushNamed(context, '/import-wallet');
          },
          child: Center(
            child: Text(
              'Add existing wallet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
