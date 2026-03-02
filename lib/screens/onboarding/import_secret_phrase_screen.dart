import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/wallet_service.dart';
import '../../services/storage_service.dart';
import '../../services/blockchain_service.dart';
import 'package:provider/provider.dart';
import '../../utils/toast_utils.dart';

/// Import Secret Phrase Screen
/// Allows users to import wallet using 12 or 24-word secret phrase
class ImportSecretPhraseScreen extends StatefulWidget {
  const ImportSecretPhraseScreen({super.key});

  @override
  State<ImportSecretPhraseScreen> createState() => _ImportSecretPhraseScreenState();
}

class _ImportSecretPhraseScreenState extends State<ImportSecretPhraseScreen> {
  final TextEditingController _walletNameController = TextEditingController();
  final TextEditingController _secretPhraseController = TextEditingController();
  final WalletService _walletService = WalletService();
  bool _isLoading = false;

  @override
  void dispose() {
    _walletNameController.dispose();
    _secretPhraseController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _secretPhraseController.text = clipboardData.text!;
      });
    }
  }

  Future<void> _importWallet() async {
    final phrase = _secretPhraseController.text.trim();
    final walletName = _walletNameController.text.trim();

    if (phrase.isEmpty) {
      _showError('Please enter your secret phrase');
      return;
    }

    if (walletName.isEmpty) {
      _showError('Please enter a wallet name');
      return;
    }

    // Validate mnemonic
    if (!_walletService.validateMnemonic(phrase)) {
      _showError('Invalid secret phrase. Please check and try again.');
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
        ToastUtils.showSuccess('Wallet imported successfully!');

        // If user already has a passcode (they are adding from inside the app), just pop
        final storage = StorageService();
        final passcode = await storage.getPasscode();
        if (passcode != null && passcode.isNotEmpty) {
          if (mounted) Navigator.pop(context, true);
        } else {
          // Navigate to passcode setup
          if (mounted) Navigator.pushNamed(context, '/create-passcode');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Failed to import wallet: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    ToastUtils.showError(message);
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
                
                // Wallet name label
                Text(
                  'Wallet name',
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
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white,
                  ),
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
                    hintText: 'Enter wallet name',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Secret phrase label
                Text(
                  'Secret phrase',
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
                          hintText: 'Enter your 12 or 24-word secret phrase',
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
                            'Paste',
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
                
                const SizedBox(height: 16),
                
                // Helper text
                Center(
                  child: Text(
                    'Your secret phrase is 12 or 24 words separated by\nsingle spaces',
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
                                'Import wallet',
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
