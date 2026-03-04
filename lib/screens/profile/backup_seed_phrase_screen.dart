import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../services/wallet_service.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/mobile_scaffold.dart';

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
              size: 26,
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
              'Your seed phrase is the master key to your wallet. Anyone with it can move all your funds.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Never share it with anyone\n• Never enter it on websites\n• Write it down and store it offline',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.warning,
                height: 1.55,
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
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'I Understand',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final mnemonic = await _walletService.getMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      ToastUtils.showError('No seed phrase stored for this wallet');
      return;
    }

    setState(() {
      _seedPhraseRevealed = true;
      _seedPhrase = mnemonic;
    });

    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _seedPhraseRevealed = false;
          _seedPhrase = null;
        });
      }
    });
  }

  void _hideSeedPhrase() {
    setState(() {
      _seedPhraseRevealed = false;
      _seedPhrase = null;
    });
  }

  void _copyToClipboard() {
    final phrase = _seedPhrase;
    if (phrase == null) return;
    Clipboard.setData(ClipboardData(text: phrase));
    ToastUtils.showSuccess('Seed phrase copied to clipboard');
  }

  Widget _buildSeedPhraseGrid(String mnemonic) {
    final words = mnemonic.split(' ');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.45,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: Colors.white.withValues(alpha: 0.02),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Text(
                '${index + 1}.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  words[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Text(
                      'Backup Seed Phrase',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your 12-word recovery phrase is the only way to recover your wallet if you lose your phone or forget your password.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _seedPhraseRevealed
                            ? AppColors.warning.withValues(alpha: 0.08)
                            : AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _seedPhraseRevealed
                              ? AppColors.warning.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (!_seedPhraseRevealed) ...[
                            const Icon(
                              Icons.visibility_off_rounded,
                              color: AppColors.textSecondary,
                              size: 42,
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _revealSeedPhrase,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Tap to Reveal',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ] else if (_seedPhrase != null) ...[
                            _buildSeedPhraseGrid(_seedPhrase!),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      size: 15,
                                      color: AppColors.warning.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Auto-hides in 60s',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppColors.warning.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: _hideSeedPhrase,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentRed.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Hide',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
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
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_seedPhraseRevealed && _seedPhrase != null)
                      Center(
                        child: TextButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: AppColors.accentRed,
                            size: 18,
                          ),
                          label: Text(
                            'Copy to clipboard',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accentRed,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
