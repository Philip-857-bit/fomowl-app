import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../models/wallet_account.dart';
import '../wallet_origin_badge.dart';

class ManageWalletTile extends StatelessWidget {
  final WalletAccount account;
  final bool isActive;
  final String balanceLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const ManageWalletTile({
    super.key,
    required this.account,
    required this.isActive,
    required this.balanceLabel,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppColors.accentRed.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: account.origin == WalletOrigin.imported
                  ? [
                      const Color(0xFFF59E0B).withValues(alpha: 0.22),
                      const Color(0xFFF59E0B).withValues(alpha: 0.07),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ],
            ),
          ),
          child: Icon(
            account.origin == WalletOrigin.imported
                ? Icons.key_rounded
                : Icons.account_balance_wallet_rounded,
            color: account.origin == WalletOrigin.imported
                ? const Color(0xFFF59E0B)
                : const Color(0xFFAFC2E8),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (walletOriginBadge(account) != null) ...[
              const SizedBox(width: 6),
              walletOriginBadge(account)!,
            ],
            if (isActive) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.accentRed,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              walletTypeLabel(account),
              style: GoogleFonts.outfit(
                color: account.origin == WalletOrigin.imported
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.85)
                    : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              balanceLabel,
              style: GoogleFonts.outfit(
                color: const Color(0xFF9AA7C0),
                fontSize: 13,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: onEdit,
          tooltip: 'Edit wallet',
          icon: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color(0xFF7081A3),
            size: 16,
          ),
        ),
      ),
    );
  }
}
