import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../models/wallet_account.dart';
import 'wallet_origin_badge.dart';

class WalletList extends StatelessWidget {
  final List<WalletAccount> wallets;
  final String? activeAddress;
  final void Function(WalletAccount) onSelect;
  final void Function(WalletAccount) onRename;
  final void Function(WalletAccount) onDelete;
  final String Function(String) shortenAddress;

  const WalletList({
    super.key,
    required this.wallets,
    required this.activeAddress,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
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
                  color: isActive
                      ? AppColors.accentRed.withValues(alpha: 0.2)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                account.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (walletOriginBadge(account) != null) ...[
                              const SizedBox(width: 6),
                              walletOriginBadge(account)!,
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          walletTypeLabel(account),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: account.origin == WalletOrigin.imported
                                ? const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.85)
                                : Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shortenAddress(account.address),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => onRename(account),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white54,
                            size: 18,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onDelete(account),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Semantics(
                            label: 'Delete account',
                            child: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
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
