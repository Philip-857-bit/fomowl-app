import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _obscureSecretPhrase = true;
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
    if (_isLoading) return;
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
      // Import wallet from mnemonic and discover additional used accounts.
      await _walletService.importWalletsFromMnemonic(
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

        final storage = StorageService();
        final hasPasscode = await storage.hasPasscode();
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/wallet-imported',
            arguments: {'hasPasscode': hasPasscode},
          );
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 30, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFFEA2A33),
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // WALLET NAME
                      Text(
                        'WALLET NAME',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB7B5B4),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E0E0E),
                          border: Border.all(color: const Color(0xFF6B7280)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _walletNameController,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 19,
                            ),
                            hintText: 'e.g. Primary Savings',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFFB7B5B4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // SECRET PHRASE
                      Text(
                        'SECRET PHRASE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB7B5B4),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E0E0E),
                              border: Border.all(
                                color: const Color(0x265D3F3D),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _secretPhraseController,
                              obscureText: _obscureSecretPhrase,
                              maxLines: _obscureSecretPhrase ? 1 : null,
                              minLines: _obscureSecretPhrase ? 1 : 6,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  17,
                                  17,
                                  17,
                                  52,
                                ),
                                hintText:
                                    'Enter your 24 or 12 word recovery phrase...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xB8B7B5B4),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureSecretPhrase
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureSecretPhrase =
                                          !_obscureSecretPhrase;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: GestureDetector(
                              onTap: _pasteFromClipboard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x0DFFB3AD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'PASTE',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEA2A33),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_wordCount > 0) ...[
                        _WordCountIndicator(wordCount: _wordCount),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Color(0xFFC8C6C5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your secret phrase is a 24 or 12 word separated by single spaces',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFFC8C6C5),
                                height: 1.788,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Security card
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1B),
                          border: Border.all(color: const Color(0x265D3F3D)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Importing an existing wallet?',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE2E2E2),
                                height: 1.43,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ensure you are in a private environment. Never share your secret phrase with anyone, including our support team.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFFB7B5B4),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky footer
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00131313), Color(0xFF131313)],
                  stops: [0, 0.5],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33EA2A33),
                      blurRadius: 12,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: AbsorbPointer(
                  absorbing: _isLoading,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA2A33),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _importWallet,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            l.importWallet,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
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
        ? const Color(0xFFEA2A33)
        : Colors.white.withValues(alpha: 0.5);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$wordCount / $target words',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (isValid) ...[
          const SizedBox(width: 6),
          Icon(Icons.check_circle_outline, size: 13, color: color),
        ],
      ],
    );
  }
}
