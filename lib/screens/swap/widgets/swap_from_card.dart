import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../models/token.dart';
import '../../../utils/value_formatter.dart';
import 'swap_token_chip.dart';

class SwapFromCard extends StatelessWidget {
  final TextEditingController controller;
  final Token? token;
  final double usdValue;
  final double balance;
  final int selectedPercentage;
  final void Function(String) onAmountChanged;
  final VoidCallback onSelectToken;
  final void Function(int) onPercentSelected;
  final int? chainId;

  const SwapFromCard({
    super.key,
    required this.controller,
    required this.token,
    required this.usdValue,
    required this.balance,
    required this.selectedPercentage,
    required this.onAmountChanged,
    required this.onSelectToken,
    required this.onPercentSelected,
    this.chainId,
  });

  @override
  Widget build(BuildContext context) {
    const percentages = [25, 50, 100];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Swapping From:',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              ...percentages.map(
                (percent) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _PercentChip(
                    percent: percent,
                    isSelected: selectedPercentage == percent,
                    onTap: () => onPercentSelected(percent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onAmountChanged,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              SwapTokenChip(
                token: token,
                onTap: onSelectToken,
                chainId: chainId,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ValueFormatter.formatUsdValue(
                  ValueFormatter.decimalFromNum(usdValue),
                ),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              Row(
                children: [
                  Text(
                    '${balance.toStringAsFixed(4)} ${token?.symbol ?? ""}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  final int percent;
  final bool isSelected;
  final VoidCallback onTap;

  const _PercentChip({
    required this.percent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentRed
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '$percent%',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
