import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/chain.dart';
import '../../../models/token.dart';
import '../../../utils/value_formatter.dart';
import '../../../widgets/amount_input_mode_toggle.dart';
import '../../../widgets/chain_logo_image.dart';
import 'swap_figma_icons.dart';
import 'swap_token_chip.dart';

enum SwapTab { swap, limit, bridge }

class SwapTabSelector extends StatelessWidget {
  final SwapTab activeTab;
  final ValueChanged<SwapTab> onChanged;
  final bool showLimitTab;
  final bool showBridgeTab;

  const SwapTabSelector({
    super.key,
    required this.activeTab,
    required this.onChanged,
    this.showLimitTab = true,
    this.showBridgeTab = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF151C24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SwapTabChip(
                label: 'SWAP',
                isActive: activeTab == SwapTab.swap,
                onTap: () => onChanged(SwapTab.swap),
              ),
            ),
            if (showLimitTab) ...[
              const SizedBox(width: 6),
              Expanded(
                child: _SwapTabChip(
                  label: 'LIMIT',
                  isActive: activeTab == SwapTab.limit,
                  onTap: () => onChanged(SwapTab.limit),
                ),
              ),
            ],
            if (showBridgeTab) ...[
              const SizedBox(width: 6),
              Expanded(
                child: _SwapTabChip(
                  label: 'BRIDGE',
                  isActive: activeTab == SwapTab.bridge,
                  onTap: () => onChanged(SwapTab.bridge),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwapTabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _SwapTabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isActive ? Colors.white : const Color(0xFFA1A1A1);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEA2A33) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 15,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: effectiveColor,
            letterSpacing: 0.6,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8894A0),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF151C24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A333D)),
              ),
              child: Row(
                children: [
                  _ChainLogo(chainId: chain.chainId, url: chain.logoUrl),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chain.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const FigmaDropdownIcon(width: 12, color: Color(0xFF8894A0)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChainLogo extends StatelessWidget {
  final int chainId;
  final String? url;

  const _ChainLogo({required this.chainId, this.url});

  @override
  Widget build(BuildContext context) {
    const fallback = SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2A),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.language, color: Color(0xFFC8C6C5), size: 16),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ChainLogoImage(
        chainId: chainId,
        logoUrl: url,
        width: 32,
        height: 32,
        fallback: fallback,
      ),
    );
  }
}

/// The execution price card for limit orders.
/// Either the token-price field OR the fiat field is the editable primary,
/// depending on [priceInputMode]; the other row becomes a read-only
/// equivalent. The primary controller — which the parent reads to submit —
/// always holds the token price regardless of which field is visible.
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

  /// Optional controller for the fiat input field.
  /// When provided AND [priceInputMode] is fiat, this field becomes the
  /// editable primary.
  final TextEditingController? usdController;

  /// Fires when the user types in the fiat field.
  final ValueChanged<String>? onUsdChanged;

  /// Which input is currently editable / primary.
  final AmountInputMode priceInputMode;

  /// Fires when the user taps the token/fiat toggle.
  final VoidCallback? onToggleInputMode;

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
    this.priceInputMode = AmountInputMode.token,
    this.onToggleInputMode,
  });

  @override
  Widget build(BuildContext context) {
    final fiatPrefix = ValueFormatter.currencyPrefix;
    final isFiatPrimary =
        priceInputMode == AmountInputMode.fiat &&
        usdController != null &&
        onUsdChanged != null;
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'When $targetTokenSymbol is worth',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFFC8C6C5),
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (onToggleInputMode != null && usdController != null)
                      AmountInputModeToggle(
                        mode: priceInputMode,
                        tokenSymbol: quoteToken?.symbol ?? '',
                        onToggle: onToggleInputMode!,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isFiatPrimary) ...[
                  TextField(
                    controller: usdController,
                    onChanged: onUsdChanged,
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
                      hintText: '0.00',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFFE2E2E2),
                        height: 1.87,
                      ),
                      prefixText: fiatPrefix,
                      prefixStyle: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFFE2E2E2),
                        height: 1.87,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  SizedBox(
                    height: 20,
                    child: Text(
                      controller.text.isEmpty
                          ? '0 ${quoteToken?.symbol ?? ''}'
                          : '${controller.text} ${quoteToken?.symbol ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF71717A),
                        height: 1.67,
                      ),
                    ),
                  ),
                ] else ...[
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
                  Text(
                    targetPriceUsdLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFE2E2E2),
                      height: 2.33,
                    ),
                  ),
                ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0x19EA2A33) : const Color(0xFF151C24),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFFEA2A33) : const Color(0xFF2A333D),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFFEA2A33) : const Color(0xFF848E9C),
          ),
        ),
      ),
    );
  }
}
