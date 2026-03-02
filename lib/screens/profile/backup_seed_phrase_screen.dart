import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/wallet_service.dart';
import '../../utils/toast_utils.dart';
import '../../utils/sensitive_access_guard.dart';

/// Backup Seed Phrase Screen
/// Dedicated screen for revealing and backing up the wallet's seed phrase
class BackupSeedPhraseScreen extends StatefulWidget {
  const BackupSeedPhraseScreen({super.key});

  @override
  State<BackupSeedPhraseScreen> createState() => _BackupSeedPhraseScreenState();
}

class _BackupSeedPhraseScreenState extends State<BackupSeedPhraseScreen> {
  final WalletService _walletService = WalletService();
  bool _seedPhraseRevealed = false;
  String? _seedPhrase;

  Future<void> _revealSeedPhrase() async {
    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: 'Authenticate to view your seed phrase',
    );
    if (!mounted) return;
    if (!authenticated) {
      ToastUtils.showError('Authentication required to view seed phrase');
      return;
    }

    // Show warning dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              'Security Warning',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your seed phrase is the MASTER KEY to your wallet. Anyone with it can steal all your funds.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Never share it with anyone\n• Never enter it on websites\n• Write it down on paper and store safely',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.warning,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'I Understand, Show Me',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (confirmed == true) {
      final mnemonic = await _walletService.getMnemonic();
      if (mnemonic == null || mnemonic.isEmpty) {
        ToastUtils.showError('No seed phrase stored for this wallet');
        return;
      }
      if (mounted) {
        setState(() {
          _seedPhraseRevealed = true;
          _seedPhrase = mnemonic;
        });
        // Auto-hide after 60 seconds
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted) setState(() => _seedPhraseRevealed = false);
        });
      }
    }
  }

  void _hideSeedPhrase() {
    setState(() {
      _seedPhraseRevealed = false;
      _seedPhrase = null;
    });
  }

  void _copyToClipboard() {
    if (_seedPhrase != null) {
      Clipboard.setData(ClipboardData(text: _seedPhrase!));
      ToastUtils.showSuccess('Seed phrase copied to clipboard');
    }
  }

  Widget _buildSeedPhraseGrid(String mnemonic) {
    final words = mnemonic.split(' ');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  words[index],
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
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
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  'Backup Seed Phrase',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  'Your 12-word recovery phrase is the only way to recover your wallet if you lose your phone or forget your password.',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // Seed Phrase Area
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _seedPhraseRevealed
                          ? AppColors.warning.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                      width: _seedPhraseRevealed ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (!_seedPhraseRevealed) ...[
                        const Icon(
                          Icons.visibility_off,
                          color: Colors.white54,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _revealSeedPhrase,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Tap to Reveal',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else if (_seedPhrase != null) ...[
                        _buildSeedPhraseGrid(_seedPhrase!),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 16,
                                  color: AppColors.warning.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Auto-hides in 60s',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppColors.warning.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _hideSeedPhrase,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentRed.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Hide',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accentRed,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'No seed phrase available.\nThis wallet was imported via private key.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                if (_seedPhraseRevealed && _seedPhrase != null)
                  Center(
                    child: TextButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(
                        Icons.copy,
                        color: Color(0xFFEB3F3F),
                        size: 20,
                      ),
                      label: Text(
                        'Copy to clipboard',
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
        ),
      ),
    );
  }
}
