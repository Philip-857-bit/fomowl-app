import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../services/screen_capture_guard.dart';
import '../../widgets/mobile_scaffold.dart';

/// Confirm Phrase Screen
/// Security acknowledgment screen before verifying the seed phrase
/// Designed according to Figma specification (Confirm Secret Phrase Redesign)
class ConfirmPhraseScreen extends StatefulWidget {
  const ConfirmPhraseScreen({
    super.key,
    this.screenCaptureGuard,
  });

  final ScreenCaptureGuard? screenCaptureGuard;

  @override
  State<ConfirmPhraseScreen> createState() => _ConfirmPhraseScreenState();
}

class _ConfirmPhraseScreenState extends State<ConfirmPhraseScreen>
    with WidgetsBindingObserver {
  bool _check1 = false;
  bool _check2 = false;
  bool _check3 = false;

  List<String>? _mnemonicWords;
  late final ScreenCaptureGuard _screenCaptureGuard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenCaptureGuard = widget.screenCaptureGuard ?? ScreenCaptureGuard();
    unawaited(_screenCaptureGuard.enableProtection());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the mnemonic words passed from previous screen. Copy them so this
    // screen owns an independent snapshot — the previous screen wipes its own
    // (shared-by-reference) list in dispose(), which would otherwise blank out
    // the phrase we forward to the verify screen.
    _mnemonicWords ??=
        (ModalRoute.of(context)?.settings.arguments as List<String>?)?.toList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wipeMnemonic();
    unawaited(_screenCaptureGuard.disableProtection());
    super.dispose();
  }

  bool get _allChecked => _check1 && _check2 && _check3;

  void _wipeMnemonic() {
    final words = _mnemonicWords;
    if (words == null) return;
    for (var i = 0; i < words.length; i++) {
      words[i] = '';
    }
    _mnemonicWords = null;
  }

  void _continue() {
    if (_allChecked) {
      // Pass a copy: this screen wipes its own list in dispose(), so handing
      // off the same reference would blank the phrase for the verify screen.
      Navigator.pushNamed(
        context,
        '/verify-phrase',
        arguments: _mnemonicWords?.toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return MobileScaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // Top Bar: Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    key: const Key('confirm_phrase_back_button'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: SvgPicture.asset(
                      'assets/images/confirm_phrase_back.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFEA2A33),
                        BlendMode.srcIn,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(height: 28),

                // Hero Visual: Key Security Badge
                _buildSecurityEmblem(),

                const SizedBox(height: 36),

                // Headline & Subtitle
                Text(
                  l.confirmSecretPhraseTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE2E2E2),
                    letterSpacing: -0.8,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 14),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    l.confirmSecretPhraseSubtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFB7B5B4),
                      height: 1.45,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Checklist Section: Tonal Layering
                _buildCheckCard(
                  key: const Key('confirm_phrase_check_1'),
                  isChecked: _check1,
                  text: l.confirmSecretPhraseCheckOne,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _check1 = !_check1;
                    });
                  },
                ),

                const SizedBox(height: 16),

                _buildCheckCard(
                  key: const Key('confirm_phrase_check_2'),
                  isChecked: _check2,
                  text: l.confirmSecretPhraseCheckTwo,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _check2 = !_check2;
                    });
                  },
                ),

                const SizedBox(height: 16),

                _buildCheckCard(
                  key: const Key('confirm_phrase_check_3'),
                  isChecked: _check3,
                  text: l.confirmSecretPhraseCheckThree,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _check3 = !_check3;
                    });
                  },
                ),

                const SizedBox(height: 48),

                // Primary CTA: Kinetic Obsidian Button
                _buildContinueButton(l.continue_),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 3D Security Emblem container with ambient glow and linear gradient
  Widget _buildSecurityEmblem() {
    return Container(
      width: 128,
      height: 128,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x265D3F3D), // rgba(93, 63, 61, 0.15)
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26EA2A33), // rgba(234, 42, 51, 0.15)
            blurRadius: 50,
            spreadRadius: 0,
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x1AFF5451), // rgba(255, 84, 81, 0.1)
            Color(0x00FF5451), // rgba(255, 84, 81, 0.0)
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle top-right decorative glint
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x26EA2A33),
                    Color(0x00EA2A33),
                  ],
                ),
              ),
            ),
          ),

          // 3D Key Icon
          Image.asset(
            'assets/images/confirm_phrase_key_security.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.vpn_key_rounded,
                size: 60,
                color: Color(0xFFEA2A33),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Tonal Layered Checklist Card
  Widget _buildCheckCard({
    required Key key,
    required bool isChecked,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0x1FEA2A33),
        highlightColor: const Color(0x0FEA2A33),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isChecked
                  ? const Color(0x33EA2A33)
                  : const Color(0x0D5D3F3D), // rgba(93, 63, 61, 0.05)
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked
                      ? const Color(0x1AEA2A33) // rgba(255, 84, 81, 0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: isChecked
                        ? const Color(0xFFEA2A33)
                        : const Color(0x335D3F3D),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isChecked
                    ? SvgPicture.asset(
                        'assets/images/confirm_phrase_check.svg',
                        width: 11,
                        height: 8,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFEA2A33),
                          BlendMode.srcIn,
                        ),
                      )
                    : null,
              ),

              const SizedBox(width: 16),

              // Acknowledgment Text
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFE2E2E2),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kinetic Obsidian Button
  Widget _buildContinueButton(String label) {
    return SizedBox(
      width: double.infinity,
      height: 53,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _allChecked
              ? const Color(0xFFEA2A33)
              : const Color(0xFF1B1112),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _allChecked
              ? const [
                  BoxShadow(
                    color: Color(0x4DEA2A33), // rgba(234, 42, 51, 0.3)
                    blurRadius: 32,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('confirm_phrase_continue_button'),
            borderRadius: BorderRadius.circular(12),
            onTap: _allChecked ? _continue : null,
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _allChecked
                      ? const Color(0xFFFFFFFF)
                      : const Color(0x4DFFFFFF),
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
