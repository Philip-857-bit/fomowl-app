import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/chain.dart';
import '../../../models/token.dart';
import '../../../utils/value_formatter.dart';
import 'swap_figma_icons.dart';
import 'swap_token_chip.dart';

enum SwapTab { swap, limit }

class SwapTabSelector extends StatelessWidget {
  final SwapTab activeTab;
  final ValueChanged<SwapTab> onChanged;

  const SwapTabSelector({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x265D3F3D)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwapTabChip(
              label: 'Swap',
              isActive: activeTab == SwapTab.swap,
              onTap: () => onChanged(SwapTab.swap),
            ),
          ),
          Expanded(
            child: _SwapTabChip(
              label: 'Limit',
              isActive: activeTab == SwapTab.limit,
              onTap: () => onChanged(SwapTab.limit),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwapTabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SwapTabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isActive
                  ? (label == 'Limit' ? FontWeight.w700 : FontWeight.w600)
                  : FontWeight.w600,
              color: isActive
                  ? const Color(0xFFEA2A33)
                  : const Color(0xFFC8C6C5),
              height: 1.43,
            ),
          ),
        ),
      ),
    );
  }
}

class NetworkCard extends StatelessWidget {
  final EvmChain chain;
  final VoidCallback? onTap;

  const NetworkCard({super.key, required this.chain, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x991F1F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x265D3F3D)),
          ),
          child: Row(
            children: [
              _ChainLogo(url: chain.logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NETWORK',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC8C6C5),
                        height: 1.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chain.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE2E2E2),
                        height: 1.43,
                      ),
                    ),
                  ],
                ),
              ),
              const FigmaDropdownIcon(width: 12, color: Color(0xFFC8C6C5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChainLogo extends StatelessWidget {
  final String? url;

  const _ChainLogo({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.language, color: Color(0xFFC8C6C5), size: 16),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url!,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.language, color: Color(0xFFC8C6C5), size: 16),
        ),
      ),
    );
  }
}

/// The execution price card for limit orders.
/// Both the token-price field and the USD field are editable.
/// When the user edits the USD field, [onUsdChanged] fires and the
/// parent recalculates the token price from the USD value.
class LimitExecutionCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// The symbol of the token whose price the user is setting.
  final String targetTokenSymbol;

  /// The quote token shown as a chip — denominating the limit price.
  final Token? quoteToken;
  final String targetPriceUsdLabel;
  final int? chainId;

  /// Percentage deviation from market price (e.g. "+1.2%").
  final String? priceDeviationLabel;

  /// Optional controller for the USD input field.
  /// When provided the USD row becomes editable.
  final TextEditingController? usdController;

  /// Fires when the user types in the USD field.
  final ValueChanged<String>? onUsdChanged;

  const LimitExecutionCard({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.targetTokenSymbol,
    required this.quoteToken,
    required this.targetPriceUsdLabel,
    this.chainId,
    this.priceDeviationLabel,
    this.usdController,
    this.onUsdChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fiatPrefix = ValueFormatter.currencyPrefix;
    return Container(
      constraints: const BoxConstraints(minHeight: 115),
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x265D3F3D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When $targetTokenSymbol is worth',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFFC8C6C5),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFFE2E2E2),
                    height: 1.87,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  maxLines: 1,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.0',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFFE2E2E2),
                      height: 1.87,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                // Editable USD row
                if (usdController != null && onUsdChanged != null)
                  SizedBox(
                    height: 20,
                    child: TextField(
                      controller: usdController,
                      onChanged: onUsdChanged,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFE2E2E2),
                        height: 1.33,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      maxLines: 1,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0.00',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF71717A),
                          height: 1.33,
                        ),
                        prefixText: fiatPrefix,
                        prefixStyle: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFE2E2E2),
                          height: 1.33,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  )
                else
                  Text(
                    targetPriceUsdLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFE2E2E2),
                      height: 2.33,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SwapTokenChip(
                token: quoteToken,
                onTap: () {},
                chainId: chainId,
                backgroundColor: const Color(0xFF0A0A0A),
              ),
              if (priceDeviationLabel != null &&
                  priceDeviationLabel!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  priceDeviationLabel!,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF73D3F0),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Small price adjustment chip shown above the execution card.
/// Labels switch between +/- based on the toggle state (e.g. -25% vs +25%).
class LimitPriceAdjustChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const LimitPriceAdjustChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7.82, vertical: 2.61),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1AEA2A33) : Colors.transparent,
          borderRadius: BorderRadius.circular(14.98),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 1.3,
              offset: Offset(0, 0.65),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 7.82,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFFEA2A33) : const Color(0xFF909090),
            height: 1.33,
          ),
        ),
      ),
    );
  }
}

class LimitExpiryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const LimitExpiryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(
          top: 9.5,
          left: 16,
          right: 16,
          bottom: 10.5,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0x19EA2A33) : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0x33EA2A33) : const Color(0x195D3F3D),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFFEA2A33) : const Color(0xFFC8C6C5),
            height: 1.33,
          ),
        ),
      ),
    );
  }
}
