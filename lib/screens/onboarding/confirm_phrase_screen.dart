import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/screen_capture_guard.dart';
import '../../widgets/mobile_scaffold.dart';

/// Confirm Phrase Screen
/// Security acknowledgment screen before verifying the seed phrase
class ConfirmPhraseScreen extends StatefulWidget {
  const ConfirmPhraseScreen({super.key});

  @override
  State<ConfirmPhraseScreen> createState() => _ConfirmPhraseScreenState();
}

class _ConfirmPhraseScreenState extends State<ConfirmPhraseScreen>
    with WidgetsBindingObserver {
  bool _check1 = false;
  bool _check2 = false;
  bool _check3 = false;

  List<String>? _mnemonicWords;
  final ScreenCaptureGuard _screenCaptureGuard = ScreenCaptureGuard();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      backgroundColor: AppColors.background.withValues(alpha: 0.95),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Owl padlock illustration
                Image.asset(
                  'assets/images/owl_lock.png',
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    // Placeholder if image not found
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 100,
                        color: Colors.white54,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  l.confirmSecretPhraseTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Checkbox 1
                _buildCheckbox(
                  value: _check1,
                  text: l.confirmSecretPhraseCheckOne,
                  onChanged: (value) {
                    setState(() {
                      _check1 = value ?? false;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Checkbox 2
                _buildCheckbox(
                  value: _check2,
                  text: l.confirmSecretPhraseCheckTwo,
                  onChanged: (value) {
                    setState(() {
                      _check2 = value ?? false;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Checkbox 3
                _buildCheckbox(
                  value: _check3,
                  text: l.confirmSecretPhraseCheckThree,
                  onChanged: (value) {
                    setState(() {
                      _check3 = value ?? false;
                    });
                  },
                ),

                const SizedBox(height: 60),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: _allChecked ? _continue : null,
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
                        gradient: _allChecked
                            ? const LinearGradient(
                                colors: [Color(0xFFC03F2E), Color(0xFF640C0B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _allChecked
                            ? null
                            : Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          l.continue_,
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

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String text,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A4A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        checkColor: Colors.white,
        activeColor: const Color(0xFF6B6B6B),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
