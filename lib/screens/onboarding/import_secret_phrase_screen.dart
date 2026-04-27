import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/wallet_service.dart';
import '../../services/storage_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/screen_capture_guard.dart';
import 'package:provider/provider.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/toast_utils.dart';
import '../../l10n/app_localizations.dart';

/// Import Secret Phrase Screen
/// Allows users to import wallet using 12 or 24-word secret phrase
class ImportSecretPhraseScreen extends StatefulWidget {
  const ImportSecretPhraseScreen({super.key});

  @override
  State<ImportSecretPhraseScreen> createState() =>
      _ImportSecretPhraseScreenState();
}

class _ImportSecretPhraseScreenState extends State<ImportSecretPhraseScreen> {
  final TextEditingController _walletNameController = TextEditingController();
  final TextEditingController _secretPhraseController = TextEditingController();
  final WalletService _walletService = WalletService();
  final ScreenCaptureGuard _screenCaptureGuard = ScreenCaptureGuard();
  bool _isLoading = false;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_screenCaptureGuard.enableProtection());
    _secretPhraseController.addListener(_onPhraseChanged);
  }

  void _onPhraseChanged() {
    final words = _secretPhraseController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (words != _wordCount) {
      setState(() => _wordCount = words);
    }
  }

  @override
  void dispose() {
    _walletNameController.text = '';
    _secretPhraseController.text = '';
    _walletNameController.dispose();
    _secretPhraseController.removeListener(_onPhraseChanged);
    _secretPhraseController.dispose();
    unawaited(_screenCaptureGuard.disableProtection());
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _secretPhraseController.text = _walletService.normalizeMnemonic(
          clipboardData.text!,
        );
      });
    }
  }

  Future<void> _importWallet() async {
    final l = AppLocalizations.of(context);
    final phrase = _walletService.normalizeMnemonic(
      _secretPhraseController.text,
    );
    final walletName = _walletNameController.text.trim();

    if (phrase.isEmpty) {
      _showError(l.enterSecretPhrasePrompt);
      return;
    }

    if (walletName.isEmpty) {
      _showError(l.enterWalletNamePrompt);
      return;
    }

    // Validate mnemonic
    if (!await _walletService.validateMnemonic(phrase)) {
      _showError(l.invalidSecretPhrasePrompt);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Import wallet from mnemonic
      await _walletService.createWalletFromMnemonic(
        phrase,
        walletName: walletName,
      );

      // Refresh blockchain cache independently so refresh failures do not fail import.
      if (mounted) {
        try {
          Provider.of<BlockchainService>(context, listen: false).refresh();
        } catch (refreshError) {
          debugPrint('Blockchain refresh failed after import: $refreshError');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show success message
        ToastUtils.showSuccess(l.walletImportedSuccessfully);

        final storage = StorageService();
        if (await storage.hasPasscode()) {
          if (mounted) Navigator.pop(context, true);
        } else {
          if (mounted) Navigator.pushNamed(context, '/create-passcode');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(
          AppErrorUtils.userMessage(
            e,
            fallback: l.importWalletFailed('Please try again.'),
          ),
        );
      }
    }
  }

  void _showError(String message) {
    ToastUtils.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),

                const SizedBox(height: 20),

                // Wallet name label
                Text(
                  l.walletNameLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                // Wallet name input
                TextField(
                  controller: _walletNameController,
                  style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF2C2B2B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    hintText: l.enterWalletNameHint,
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Secret phrase label
                Text(
                  l.secretPhrase,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                // Secret phrase input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2B2B),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Stack(
                    children: [
                      TextField(
                        controller: _secretPhraseController,
                        maxLines: 6,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(20),
                          hintText: l.enterSecretPhraseHint,
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      // Paste button
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: TextButton(
                          onPressed: _pasteFromClipboard,
                          child: Text(
                            l.paste,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFEB3F3F),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Word count indicator
                _WordCountIndicator(wordCount: _wordCount),

                const SizedBox(height: 10),

                // Helper text
                Center(
                  child: Text(
                    l.secretPhraseHelperText,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // Import wallet button
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _importWallet,
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
                        gradient: _isLoading
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFFC03F2E), Color(0xFF640C0B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isLoading ? Colors.grey : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l.importWallet,
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

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordCountIndicator extends StatelessWidget {
  const _WordCountIndicator({required this.wordCount});

  final int wordCount;

  @override
  Widget build(BuildContext context) {
    if (wordCount == 0) return const SizedBox.shrink();

    final bool isValid = wordCount == 12 || wordCount == 24;
    final int target = wordCount <= 12 ? 12 : 24;
    final Color color = isValid
        ? const Color(0xFF4CAF50)
        : wordCount > 24
        ? const Color(0xFFEB3F3F)
        : Colors.white.withValues(alpha: 0.5);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$wordCount / $target words',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (isValid) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_circle_outline, size: 14, color: color),
        ],
      ],
    );
  }
}
