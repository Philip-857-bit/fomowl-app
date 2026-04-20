import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/chain.dart';
import '../../../models/token.dart';
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
          const SizedBox(width: 6),
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
              fontWeight: FontWeight.w400,
              color: isActive
                  ? const Color(0xFFEA2A33)
                  : const Color(0xFFC8C6C5),
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
          padding: const EdgeInsets.all(17),
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
                        color: const Color(0xFFC8C6C5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chain.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFE2E2E2),
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

class LimitExecutionCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// The symbol of the token whose price the user is setting.
  /// In sell mode this is the fromToken; in buy mode this is the toToken.
  final String targetTokenSymbol;

  /// The quote token shown as a chip — denominating the limit price.
  /// In sell mode this is toToken (e.g. USDT); in buy mode this is fromToken.
  final Token? quoteToken;
  final String targetPriceUsdLabel;
  final int? chainId;

  const LimitExecutionCard({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.targetTokenSymbol,
    required this.quoteToken,
    required this.targetPriceUsdLabel,
    this.chainId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFFE2E2E2),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.0',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFFE2E2E2),
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
                  ),
                ),
              ],
            ),
          ),
          SwapTokenChip(token: quoteToken, onTap: () {}, chainId: chainId),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10.5),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1AEA2A33) : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0x33EA2A33) : const Color(0x1A5D3F3D),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: selected ? const Color(0xFFEA2A33) : const Color(0xFFC8C6C5),
          ),
        ),
      ),
    );
  }
}
