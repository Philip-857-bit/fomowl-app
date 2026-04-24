import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/token.dart';
import '../../../utils/value_formatter.dart';
import '../../../widgets/amount_input_mode_toggle.dart';
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
  final AmountInputMode inputMode;
  final VoidCallback? onToggleInputMode;
  final String? equivalentText;

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
    this.inputMode = AmountInputMode.token,
    this.onToggleInputMode,
    this.equivalentText,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const percentages = [25, 50, 100];
    final fiatDisplay = equivalentText ??
        ValueFormatter.formatCurrencyWithGrouping(
          ValueFormatter.decimalFromNum(usdValue),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.swapFromLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA1A1AA),
                  height: 1.67,
                ),
              ),
              const Spacer(),
              if (onToggleInputMode != null) ...[
                AmountInputModeToggle(
                  mode: inputMode,
                  tokenSymbol: token?.symbol ?? '',
                  onToggle: onToggleInputMode!,
                ),
                const SizedBox(width: 8),
              ],
              ...percentages.map(
                (percent) => Padding(
                  padding: const EdgeInsets.only(left: 8),
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
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFFFFFF),
                    height: 2.13,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0x4DFFFFFF),
                      height: 2.13,
                    ),
                    prefixText: inputMode == AmountInputMode.fiat
                        ? ValueFormatter.currencyPrefix
                        : null,
                    prefixStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFFFFFF),
                      height: 2.13,
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fiatDisplay,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF71717A),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B1A1A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${balance.toStringAsFixed(4)} ${token?.symbol ?? ""}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF71717A),
                    ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF640B0B) : const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(23),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '$percent%',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.33,
          ),
        ),
      ),
    );
  }
}
