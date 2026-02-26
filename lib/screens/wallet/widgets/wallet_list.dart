import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../models/wallet_account.dart';

class WalletList extends StatelessWidget {
  final List<WalletAccount> wallets;
  final String? activeAddress;
  final void Function(WalletAccount) onSelect;
  final void Function(WalletAccount) onRename;
  final String Function(String) shortenAddress;

  const WalletList({
    super.key,
    required this.wallets,
    required this.activeAddress,
    required this.onSelect,
    required this.onRename,
    required this.shortenAddress,
  });

  @override
  Widget build(BuildContext context) {
    if (wallets.length <= 1) return const SizedBox.shrink();
    final normalizedActive = activeAddress?.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OTHER WALLETS',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...wallets.map((account) {
          final isActive = account.address.toLowerCase() == normalizedActive;
          return GestureDetector(
            onTap: () => onSelect(account),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive ? AppColors.accentRed.withValues(alpha: 0.2) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          shortenAddress(account.address),
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onRename(account),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.edit, color: Colors.white54, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
