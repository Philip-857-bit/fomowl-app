import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import 'package:provider/provider.dart';
import '../../utils/toast_utils.dart';

/// Verify Phrase Screen
/// User must enter their seed phrase to confirm they've saved it
class VerifyPhraseScreen extends StatefulWidget {
  const VerifyPhraseScreen({super.key});

  @override
  State<VerifyPhraseScreen> createState() => _VerifyPhraseScreenState();
}

class _VerifyPhraseScreenState extends State<VerifyPhraseScreen> {
  final List<TextEditingController> _controllers = List.generate(
    12,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(12, (index) => FocusNode());

  List<String>? _originalPhrase;
  bool _isLoading = false;
  final WalletService _walletService = WalletService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the original phrase passed from previous screen
    _originalPhrase ??=
        ModalRoute.of(context)?.settings.arguments as List<String>?;
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      final words = clipboardData.text!.trim().split(' ');
      if (words.length == 12) {
        setState(() {
          for (int i = 0; i < 12 && i < words.length; i++) {
            _controllers[i].text = words[i].trim();
          }
        });
      }
    }
  }

  void _verifyAndContinue() {
    final l = AppLocalizations.of(context);
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
    if (_originalPhrase != null) {
      final originalLower = _originalPhrase!
          .map((w) => w.toLowerCase())
          .toList();
      bool isCorrect = true;

      for (int i = 0; i < 12; i++) {
        if (enteredWords[i] != originalLower[i]) {
          isCorrect = false;
          break;
        }
      }

      if (!isCorrect) {
        ToastUtils.showError(l.seedPhraseMismatch);
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
        walletName: 'Main Wallet',
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
        ToastUtils.showError(l.walletCreationError(e.toString()));
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
                    'Secret recovery phrase',
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
                    'Never share your seed phrase with anybody\neven your family members.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 30),

                // Input fields grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF2C2B2B).withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              textInputAction: index < 11
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              onSubmitted: (_) {
                                if (index < 11) {
                                  _focusNodes[index + 1].requestFocus();
                                } else {
                                  _verifyAndContinue();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Paste from clipboard button
                Center(
                  child: TextButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(
                      Icons.content_paste,
                      color: Color(0xFFEB3F3F),
                      size: 20,
                    ),
                    label: Text(
                      'Paste from clipboard',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFEB3F3F),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Instruction text
                Center(
                  child: Text(
                    'Confirm the seedphrase is correct',
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
                    onPressed: _isLoading ? null : _verifyAndContinue,
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
                                'Continue',
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
