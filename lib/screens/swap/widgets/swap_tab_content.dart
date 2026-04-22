import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/token.dart';
import '../../../services/swap_service.dart';
import '../../../services/blockchain_service.dart';
import 'swap_from_card.dart';
import 'swap_to_card.dart';
import 'swap_direction_button.dart';
import 'swap_price_details_card.dart';
import 'swap_primary_button.dart';
import 'swap_gasless_toggle.dart';
import 'swap_limit_widgets.dart';
import 'swap_figma_icons.dart';

class SwapTabContent extends StatelessWidget {
  final BlockchainService blockchain;
  final TextEditingController fromController;
  final Token? fromToken;
  final double fromUsdValue;
  final int selectedPercentage;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onSelectFromToken;
  final ValueChanged<int> onPercentSelected;
  final VoidCallback onSwapTokens;
  final Token? toToken;
  final String toAmountText;
  final double toUsdValue;
  final double toBalance;
  final bool isCalculating;
  final VoidCallback onSelectToToken;
  final SwapQuote? currentQuote;
  final double platformFeeUsd;
  final double feeUsd;
  final double feeNative;
  final String priceText;
  final String receiveText;
  final String priceSeparator;
  final double nativePriceUsd;
  final bool gaslessFeeCovered;
  final bool swapEnabled;
  final bool swapBusy;
  final VoidCallback onSwapPressed;
  final String? buttonLabel;
  final bool showGaslessToggle;
  final bool isGasless;
  final ValueChanged<bool> onGaslessChanged;

  const SwapTabContent({
    super.key,
    required this.blockchain,
    required this.fromController,
    required this.fromToken,
    required this.fromUsdValue,
    required this.selectedPercentage,
    required this.onAmountChanged,
    required this.onSelectFromToken,
    required this.onPercentSelected,
    required this.onSwapTokens,
    required this.toToken,
    required this.toAmountText,
    required this.toUsdValue,
    required this.toBalance,
    required this.isCalculating,
    required this.onSelectToToken,
    required this.currentQuote,
    required this.platformFeeUsd,
    required this.feeUsd,
    required this.feeNative,
    required this.priceText,
    required this.receiveText,
    required this.priceSeparator,
    required this.nativePriceUsd,
    required this.gaslessFeeCovered,
    required this.swapEnabled,
    required this.swapBusy,
    required this.onSwapPressed,
    required this.buttonLabel,
    required this.showGaslessToggle,
    required this.isGasless,
    required this.onGaslessChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Only show price details when the user has input amounts
    final hasInput =
        fromController.text.isNotEmpty &&
        (double.tryParse(fromController.text.replaceAll(',', '')) ?? 0) > 0 &&
        toAmountText.isNotEmpty &&
        toAmountText != '0';

    return Column(
      children: [
        SwapFromCard(
          controller: fromController,
          token: fromToken,
          usdValue: fromUsdValue,
          balance: fromToken?.balance ?? 0,
          selectedPercentage: selectedPercentage,
          onAmountChanged: onAmountChanged,
          onSelectToken: onSelectFromToken,
          onPercentSelected: onPercentSelected,
          chainId: blockchain.activeChain.chainId,
        ),
        const SizedBox(height: 2),
        SwapDirectionButton(onPressed: onSwapTokens),
        const SizedBox(height: 2),
        SwapToCard(
          token: toToken,
          amountText: toAmountText,
          usdValue: toUsdValue,
          balance: toBalance,
          isCalculating: isCalculating,
          onSelectToken: onSelectToToken,
          chainId: blockchain.activeChain.chainId,
        ),
        if (hasInput) ...[
          const SizedBox(height: 16),
          SwapPriceDetailsCard(
            priceText: priceText,
            platformFeePercent: currentQuote?.platformFeePercent ?? 1.0,
            platformFeeUsd: platformFeeUsd,
            feeAmountUsd: feeUsd,
            feeAmountNative: feeNative,
            nativeFeeSymbol: blockchain.activeChain.symbol,
            receiveText: receiveText,
            priceSeparator: priceSeparator,
            swapAmountUsd: fromUsdValue,
            gaslessFeeCovered: gaslessFeeCovered,
            nativePriceUsd: nativePriceUsd,
          ),
        ],
        const SizedBox(height: 16),
        SwapPrimaryButton(
          enabled: swapEnabled,
          isBusy: swapBusy,
          onPressed: onSwapPressed,
          label: buttonLabel,
        ),
        if (showGaslessToggle) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwapGaslessToggle(
              value: isGasless,
              onChanged: onGaslessChanged,
            ),
          ),
        ],
      ],
    );
  }
}

class LimitTabContent extends StatelessWidget {
  final BlockchainService blockchain;
  final TextEditingController fromController;
  final Token? fromToken;
  final double fromUsdValue;
  final int selectedPercentage;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onSelectFromToken;
  final ValueChanged<int> onPercentSelected;
  final VoidCallback onSwapTokens;
  final Token? toToken;
  final String toAmountText;
  final double toUsdValue;
  final double toBalance;
  final VoidCallback onSelectToToken;
  final bool limitBusy;
  final bool limitEnabled;
  final String limitButtonLabel;
  final String limitStatusMessage;
  final TextEditingController limitPriceController;
  final ValueChanged<String> onLimitPriceChanged;
  final String priceSeparator;
  final String executionPriceText;
  final String executionPriceUsdLabel;
  final String receiveText;
  final double nativePriceUsd;

  /// Symbol of the token whose price the user is setting (target token).
  final String targetTokenSymbol;

  /// The quote token for the limit price chip display.
  final Token? quoteToken;

  /// Percentage deviation from market price (e.g. "+1.2%").
  final String? priceDeviationLabel;

  /// Callback when user taps a price adjustment chip (e.g. -25, +25).
  final ValueChanged<int>? onPriceAdjust;

  /// Whether the +/- toggle is in "positive" mode (true = +25/+50/+100).
  final bool isPositiveAdjust;

  /// Toggles the +/- mode for price adjustment chips.
  final VoidCallback? onToggleAdjustDirection;

  /// Optional USD input controller for the execution price card.
  final TextEditingController? limitUsdController;

  /// Fires when the user edits the USD field in the execution card.
  final ValueChanged<String>? onLimitUsdChanged;

  final VoidCallback onSubmitLimit;
  final String expiryLabel;
  final VoidCallback onSelect15m;
  final VoidCallback onSelect1h;
  final VoidCallback onSelect4h;
  final VoidCallback onSelect24h;
  final VoidCallback onSelect7d;
  final VoidCallback onSelectNever;
  final VoidCallback onPickCustomExpiry;
  final bool is15mSelected;
  final bool is1hSelected;
  final bool is4hSelected;
  final bool is24hSelected;
  final bool is7dSelected;
  final bool isNeverSelected;

  const LimitTabContent({
    super.key,
    required this.blockchain,
    required this.fromController,
    required this.fromToken,
    required this.fromUsdValue,
    required this.selectedPercentage,
    required this.onAmountChanged,
    required this.onSelectFromToken,
    required this.onPercentSelected,
    required this.onSwapTokens,
    required this.toToken,
    required this.toAmountText,
    required this.toUsdValue,
    required this.toBalance,
    required this.onSelectToToken,
    required this.limitBusy,
    required this.limitEnabled,
    required this.limitButtonLabel,
    required this.limitStatusMessage,
    required this.limitPriceController,
    required this.onLimitPriceChanged,
    required this.priceSeparator,
    required this.executionPriceText,
    required this.executionPriceUsdLabel,
    required this.receiveText,
    required this.nativePriceUsd,
    required this.targetTokenSymbol,
    required this.quoteToken,
    this.priceDeviationLabel,
    this.onPriceAdjust,
    this.isPositiveAdjust = false,
    this.onToggleAdjustDirection,
    this.limitUsdController,
    this.onLimitUsdChanged,
    required this.onSubmitLimit,
    required this.expiryLabel,
    required this.onSelect15m,
    required this.onSelect1h,
    required this.onSelect4h,
    required this.onSelect24h,
    required this.onSelect7d,
    required this.onSelectNever,
    required this.onPickCustomExpiry,
    required this.is15mSelected,
    required this.is1hSelected,
    required this.is4hSelected,
    required this.is24hSelected,
    required this.is7dSelected,
    required this.isNeverSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sign = isPositiveAdjust ? '+' : '-';
    final isCustomExpirySelected =
        !is15mSelected &&
        !is1hSelected &&
        !is4hSelected &&
        !is24hSelected &&
        !is7dSelected &&
        !isNeverSelected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── From / To Cards ──
        SwapFromCard(
          controller: fromController,
          token: fromToken,
          usdValue: fromUsdValue,
          balance: fromToken?.balance ?? 0,
          selectedPercentage: selectedPercentage,
          onAmountChanged: onAmountChanged,
          onSelectToken: onSelectFromToken,
          onPercentSelected: onPercentSelected,
          chainId: blockchain.activeChain.chainId,
        ),
        const SizedBox(height: 2),
        SwapDirectionButton(onPressed: onSwapTokens),
        const SizedBox(height: 2),
        SwapToCard(
          token: toToken,
          amountText: toAmountText,
          usdValue: toUsdValue,
          balance: toBalance,
          isCalculating: false,
          onSelectToken: onSelectToToken,
          chainId: blockchain.activeChain.chainId,
        ),
        const SizedBox(height: 24),

        // ── Execution Price header row with +/- chips and MARKET toggle ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                'EXECUTION PRICE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: const Color(0xFFC8C6C5),
                ),
              ),
              const Spacer(),
              if (onPriceAdjust != null) ...[
                LimitPriceAdjustChip(
                  label: '${sign}25%',
                  selected: false,
                  onTap: () => onPriceAdjust!(isPositiveAdjust ? 25 : -25),
                ),
                const SizedBox(width: 4),
                LimitPriceAdjustChip(
                  label: '${sign}50%',
                  selected: false,
                  onTap: () => onPriceAdjust!(isPositiveAdjust ? 50 : -50),
                ),
                const SizedBox(width: 4),
                LimitPriceAdjustChip(
                  label: '${sign}100%',
                  selected: false,
                  onTap: () => onPriceAdjust!(isPositiveAdjust ? 100 : -100),
                ),
                const SizedBox(width: 6),
              ],
              Row(
                children: [
                  Text(
                    'MARKET',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEA2A33),
                      letterSpacing: 1,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onToggleAdjustDirection,
                    child: const FigmaDropdownIcon(
                      width: 8,
                      color: Color(0xFFEA2A33),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LimitExecutionCard(
          controller: limitPriceController,
          onChanged: onLimitPriceChanged,
          targetTokenSymbol: targetTokenSymbol,
          quoteToken: quoteToken,
          targetPriceUsdLabel: executionPriceUsdLabel,
          chainId: blockchain.activeChain.chainId,
          priceDeviationLabel: priceDeviationLabel,
          usdController: limitUsdController,
          onUsdChanged: onLimitUsdChanged,
        ),
        const SizedBox(height: 24),

        // ── Order Expiry ──
        Text(
          'ORDER EXPIRY',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.2,
            color: const Color(0xFFC8C6C5),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              LimitExpiryChip(
                label: '15M',
                selected: is15mSelected,
                onTap: onSelect15m,
              ),
              const SizedBox(width: 8),
              LimitExpiryChip(
                label: '1H',
                selected: is1hSelected,
                onTap: onSelect1h,
              ),
              const SizedBox(width: 8),
              LimitExpiryChip(
                label: '24H',
                selected: is24hSelected,
                onTap: onSelect24h,
              ),
              const SizedBox(width: 8),
              LimitExpiryChip(
                label: '7D',
                selected: is7dSelected,
                onTap: onSelect7d,
              ),
              const SizedBox(width: 8),
              LimitExpiryChip(
                label: 'Never',
                selected: isNeverSelected,
                onTap: onSelectNever,
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onPickCustomExpiry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isCustomExpirySelected
                        ? const Color(0x19EA2A33)
                        : const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isCustomExpirySelected
                          ? const Color(0x33EA2A33)
                          : const Color(0x195D3F3D),
                    ),
                  ),
                  child: const FigmaDropdownIcon(
                    width: 10,
                    color: Color(0xFFC8C6C5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SwapPriceDetailsCard(
          priceText: executionPriceText,
          platformFeePercent: 0.0,
          platformFeeUsd: 0.0,
          feeAmountUsd: 0.0,
          feeAmountNative: 0.0,
          nativeFeeSymbol: blockchain.activeChain.symbol,
          receiveText: receiveText,
          priceSeparator: priceSeparator,
          swapAmountUsd: fromUsdValue,
          gaslessFeeCovered: false,
          nativePriceUsd: nativePriceUsd,
        ),
        const SizedBox(height: 16),

        // ── Action Button ──
        SwapPrimaryButton(
          enabled: limitEnabled,
          isBusy: limitBusy,
          onPressed: onSubmitLimit,
          label: limitButtonLabel,
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: 0.6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              limitStatusMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFFC8C6C5),
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
