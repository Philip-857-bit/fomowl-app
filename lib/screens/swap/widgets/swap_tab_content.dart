import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
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
        const SizedBox(height: 4),
        SwapDirectionButton(onPressed: onSwapTokens),
        const SizedBox(height: 4),
        SwapToCard(
          token: toToken,
          amountText: toAmountText,
          usdValue: toUsdValue,
          balance: toBalance,
          isCalculating: isCalculating,
          onSelectToken: onSelectToToken,
          chainId: blockchain.activeChain.chainId,
        ),
        const SizedBox(height: 24),
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
        const SizedBox(height: 24),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        const SizedBox(height: 4),
        SwapDirectionButton(onPressed: onSwapTokens),
        const SizedBox(height: 4),
        SwapToCard(
          token: toToken,
          amountText: toAmountText,
          usdValue: toUsdValue,
          balance: toBalance,
          isCalculating: false,
          onSelectToken: onSelectToToken,
          chainId: blockchain.activeChain.chainId,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Execution Price',
              style: GoogleFonts.outfit(
                fontSize: 12,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            Text(
              'MARKET',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryAccent,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LimitExecutionCard(
          controller: limitPriceController,
          onChanged: onLimitPriceChanged,
          fromTokenSymbol: fromToken?.symbol ?? '',
          toToken: toToken,
          targetPriceUsdLabel: executionPriceUsdLabel,
          chainId: blockchain.activeChain.chainId,
        ),
        const SizedBox(height: 20),
        Text(
          'Order Expiry',
          style: GoogleFonts.outfit(
            fontSize: 12,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            LimitExpiryChip(
              label: '15M',
              selected: is15mSelected,
              onTap: onSelect15m,
            ),
            LimitExpiryChip(
              label: '1H',
              selected: is1hSelected,
              onTap: onSelect1h,
            ),
            LimitExpiryChip(
              label: '4H',
              selected: is4hSelected,
              onTap: onSelect4h,
            ),
            LimitExpiryChip(
              label: '24H',
              selected: is24hSelected,
              onTap: onSelect24h,
            ),
            const SizedBox(width: 10),
            LimitExpiryChip(
              label: '7D',
              selected: is7dSelected,
              onTap: onSelect7d,
            ),
            const SizedBox(width: 10),
            LimitExpiryChip(
              label: 'Never',
              selected: isNeverSelected,
              onTap: onSelectNever,
            ),
            GestureDetector(
              onTap: onPickCustomExpiry,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Expiry: $expiryLabel',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 20),
        SwapPrimaryButton(
          enabled: limitEnabled,
          isBusy: limitBusy,
          onPressed: onSubmitLimit,
          label: limitButtonLabel,
        ),
        const SizedBox(height: 12),
        Text(
          limitStatusMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}
