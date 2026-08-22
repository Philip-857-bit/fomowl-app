import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_chain_theme.dart';
import '../../../utils/toast_utils.dart';

class SettingsWalletHeaderCard extends StatelessWidget {
  final String walletName;
  final String walletAddress;
  final VoidCallback onTap;

  const SettingsWalletHeaderCard({
    super.key,
    required this.walletName,
    required this.walletAddress,
    required this.onTap,
  });

  String _shorten(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chainTheme;
    final borderRadius = BorderRadius.circular(20);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            gradient: theme.balanceCardGradient,
            borderRadius: borderRadius,
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.accentColor.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: theme.accentColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: theme.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: theme.accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          walletName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              _shorten(walletAddress),
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              button: true,
                              label: 'Copy wallet address',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  try {
                                    await Clipboard.setData(
                                      ClipboardData(text: walletAddress),
                                    );
                                    ToastUtils.showSuccess(
                                      'Wallet address copied',
                                    );
                                  } catch (_) {
                                    ToastUtils.showError(
                                      'Failed to copy wallet address',
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.copy_rounded,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white70,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
