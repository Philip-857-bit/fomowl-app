import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/screen_capture_guard.dart';
import 'package:provider/provider.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/toast_utils.dart';

/// Verify Phrase Screen
/// User must enter their seed phrase to confirm they've saved it
class VerifyPhraseScreen extends StatefulWidget {
  const VerifyPhraseScreen({super.key});

  @override
  State<VerifyPhraseScreen> createState() => _VerifyPhraseScreenState();
}

class _VerifyPhraseScreenState extends State<VerifyPhraseScreen> {
  static const int _challengeWordCount = 3;

  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final Random _random = Random();

  List<String>? _originalPhrase;
  List<int> _verificationIndexes = const [];
  bool _isLoading = false;
  final WalletService _walletService = WalletService();
  final ScreenCaptureGuard _screenCaptureGuard = ScreenCaptureGuard();

  @override
  void initState() {
    super.initState();
    unawaited(_screenCaptureGuard.enableProtection());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the original phrase passed from previous screen
    if (_originalPhrase == null) {
      _originalPhrase =
          ModalRoute.of(context)?.settings.arguments as List<String>?;
      _initializeVerificationChallenge();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.text = '';
    }
    final words = _originalPhrase;
    if (words != null) {
      for (var i = 0; i < words.length; i++) {
        words[i] = '';
      }
      _originalPhrase = null;
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    unawaited(_screenCaptureGuard.disableProtection());
    super.dispose();
  }

  void _initializeVerificationChallenge() {
    final words = _originalPhrase;
    if (words == null || words.isEmpty || _controllers.isNotEmpty) {
      return;
    }

    final requestedCount = min(_challengeWordCount, words.length);
    final indexes = List<int>.generate(words.length, (index) => index)
      ..shuffle(_random);
    _verificationIndexes = (indexes.take(requestedCount).toList()..sort());
    _controllers.addAll(
      List.generate(requestedCount, (_) => TextEditingController()),
    );
    _focusNodes.addAll(List.generate(requestedCount, (_) => FocusNode()));
  }

  void _verifyAndContinue() {
    final l = AppLocalizations.of(context);
    if (_originalPhrase == null || _verificationIndexes.isEmpty) {
      ToastUtils.showError(l.seedPhraseVerificationFailed);
      return;
    }

    // Get entered words
    final enteredWords = _controllers
        .map((c) => c.text.trim().toLowerCase())
        .toList();

    // Check if all fields are filled
    if (enteredWords.any((word) => word.isEmpty)) {
      ToastUtils.showError(l.verifyAllWords);
      return;
    }

    // Verify against original phrase
    final originalLower = _originalPhrase!.map((w) => w.toLowerCase()).toList();
    for (var i = 0; i < _verificationIndexes.length; i++) {
      if (enteredWords[i] != originalLower[_verificationIndexes[i]]) {
        ToastUtils.showError(l.seedPhraseVerificationFailed);
        return;
      }
    }

    // Save the wallet now that phrase is verified
    _saveWalletAndContinue();
  }

  Future<void> _saveWalletAndContinue() async {
    final l = AppLocalizations.of(context);
    if (_originalPhrase == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final mnemonic = _originalPhrase!.join(' ');

      await _walletService.createWalletFromMnemonic(
        mnemonic,
        walletName: l.mainWallet,
      );

      // Refresh blockchain service to clear any cached data from previous wallet
      if (mounted) {
        Provider.of<BlockchainService>(context, listen: false).refresh();
      }

      if (mounted) {
        Navigator.pushNamed(context, '/create-passcode');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(
          AppErrorUtils.userMessage(
            e,
            fallback: l.walletCreationError('Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final challengeReady =
        _originalPhrase != null && _verificationIndexes.isNotEmpty;
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

                // Title
                Center(
                  child: Text(
                    l.seedPhraseVerificationTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                // Warning text
                Center(
                  child: Text(
                    l.seedPhraseVerificationSubtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 30),

                if (!challengeReady)
                  Center(
                    child: Text(
                      l.seedPhraseVerificationFailed,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Column(
                    children: List.generate(_verificationIndexes.length, (
                      index,
                    ) {
                      final wordNumber = _verificationIndexes[index] + 1;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _verificationIndexes.length - 1
                              ? 0
                              : 16,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(
                              0xFF2C2B2B,
                            ).withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.selectSeedPhraseWord(wordNumber),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                textInputAction:
                                    index < _verificationIndexes.length - 1
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                onSubmitted: (_) {
                                  if (index < _verificationIndexes.length - 1) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else {
                                    _verifyAndContinue();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                const SizedBox(height: 30),

                const SizedBox(height: 40),

                // Instruction text
                Center(
                  child: Text(
                    l.seedPhraseVerificationSubtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 20),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: _isLoading || !challengeReady
                        ? null
                        : _verifyAndContinue,
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
                        color: _isLoading
                            ? Colors.grey.withValues(alpha: 0.3)
                            : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l.verifyBackup,
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
