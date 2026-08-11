import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  /// When non-null, shows this label at the top of the card (e.g. "SWAP FROM").
  /// Pass null to hide the header row (used in limit tab).
  final String? headerLabel;

  /// Whether to show the internal percentage chips in the header row.
  /// Set to false in limit tab (chips are shown externally below the card).
  final bool showInternalChips;

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
    this.headerLabel = 'SWAP FROM',
    this.showInternalChips = true,
  });

  @override
  Widget build(BuildContext context) {
    final fiatDisplay =
        equivalentText ??
        ValueFormatter.formatCurrencyWithGrouping(
          ValueFormatter.decimalFromNum(usdValue),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 340 ? 16.0 : 24.0;
        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF151C24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x0DFFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (headerLabel != null || onToggleInputMode != null) ...[
                Row(
                  children: [
                    if (headerLabel != null) _HeaderLabel(headerLabel!),
                    if (headerLabel != null && onToggleInputMode != null)
                      const Spacer(),
                    if (onToggleInputMode != null)
                      AmountInputModeToggle(
                        mode: inputMode,
                        tokenSymbol: token?.symbol ?? '',
                        onToggle: onToggleInputMode!,
                      ),
                  ],
                ),
              ],
              if (showInternalChips) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      _PercentChip(
                        percent: 25,
                        isSelected: selectedPercentage == 25,
                        onTap: () => onPercentSelected(25),
                      ),
                      _PercentChip(
                        percent: 50,
                        isSelected: selectedPercentage == 50,
                        onTap: () => onPercentSelected(50),
                      ),
                      _PercentChip(
                        percent: 75,
                        isSelected: selectedPercentage == 75,
                        onTap: () => onPercentSelected(75),
                      ),
                      _MaxChip(
                        isSelected: selectedPercentage == 100,
                        onTap: () => onPercentSelected(100),
                      ),
                    ],
                  ),
                ),
              ],
              if (headerLabel != null ||
                  onToggleInputMode != null ||
                  showInternalChips)
                const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onAmountChanged,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE2E2E2),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0x4DE2E2E2),
                        ),
                        prefixText: inputMode == AmountInputMode.fiat
                            ? ValueFormatter.currencyPrefix
                            : null,
                        prefixStyle: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE2E2E2),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SwapTokenChip(
                    token: token,
                    onTap: onSelectToken,
                    chainId: chainId,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fiatDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF848E9C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 11,
                          color: Color(0xFF848E9C),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${balance.toStringAsFixed(4)} ${token?.symbol ?? ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF848E9C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFA1A1A1),
        letterSpacing: 1.0,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x1AEA2A33) : const Color(0xFF131313),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected
                ? const Color(0x4DEA2A33)
                : const Color(0x0DFFFFFF),
          ),
        ),
        child: Text(
          '$percent%',
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? const Color(0xFFEA2A33)
                : const Color(0xFFA1A1A1),
          ),
        ),
      ),
    );
  }
}

class _MaxChip extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _MaxChip({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x1AEA2A33) : const Color(0xFF131313),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0x4DEA2A33)),
        ),
        child: Text(
          'MAX',
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFEA2A33),
          ),
        ),
      ),
    );
  }
}
