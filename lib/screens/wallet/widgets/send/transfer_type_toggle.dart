import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class TransferTypeToggle extends StatelessWidget {
  final bool isInterTransfer;
  final VoidCallback onExternalTap;
  final VoidCallback onInterTransferTap;

  const TransferTypeToggle({
    super.key,
    required this.isInterTransfer,
    required this.onExternalTap,
    required this.onInterTransferTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onExternalTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                'External Wallet',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onInterTransferTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isInterTransfer
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flash_on,
                    size: 14,
                    color: isInterTransfer
                        ? AppColors.accentRed
                        : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Inter-Transfer',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isInterTransfer ? Colors.white : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
