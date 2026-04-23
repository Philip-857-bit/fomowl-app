import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../models/token.dart';
import '../../../services/swap_service.dart';
import '../../../services/blockchain_service.dart';
import '../../../utils/amount_utils.dart';
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
  final String? quoteStatusMessage;
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
    required this.quoteStatusMessage,
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
        Stack(
          alignment: Alignment.center,
          children: [
            Column(
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
                const SizedBox(height: 12),
                SwapToCard(
                  token: toToken,
                  amountText: toAmountText,
                  usdValue: toUsdValue,
                  balance: toBalance,
                  isCalculating: isCalculating,
                  onSelectToken: onSelectToToken,
                  chainId: blockchain.activeChain.chainId,
                  statusMessage: isCalculating ? null : quoteStatusMessage,
                ),
              ],
            ),
            SwapDirectionButton(onPressed: onSwapTokens),
          ],
        ),
        if (hasInput) ...[
          const SizedBox(height: 16),
          SwapPriceDetailsCard(
            priceText: priceText,
            platformFeePercent: currentQuote?.platformFeePercent ?? 0.0,
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

class _LimitSideChip extends StatelessWidget {
  const _LimitSideChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x19EA2A33) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0x66EA2A33)
                : const Color(0x265D3F3D),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? const Color(0xFFEA2A33)
                  : const Color(0xFFC8C6C5),
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitActiveOrdersSection extends StatelessWidget {
  const _LimitActiveOrdersSection({
    required this.blockchain,
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    required this.onCancel,
    required this.cancellingOrderIds,
  });

  final BlockchainService blockchain;
  final List<LimitOrderSummary> orders;
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<LimitOrderSummary> onCancel;
  final Set<String> cancellingOrderIds;

  Token? _resolveToken(String address) {
    final normalized = address.toLowerCase();
    for (final token in blockchain.tokens) {
      final contractAddress = token.contractAddress?.toLowerCase();
      if (contractAddress == normalized) {
        return token;
      }
    }
    return null;
  }

  String _shortAddress(String address) {
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _symbolFor(Token? token, String address) {
    return token?.symbol ?? _shortAddress(address);
  }

  String _formatAmount(String rawAmount, Token? token) {
    final value = BigInt.tryParse(rawAmount) ?? BigInt.zero;
    return AmountUtils.formatBaseUnits(
      value,
      token?.decimals ?? 18,
      maxFractionDigits: 6,
    );
  }

  String _formatExpiry(int expirySeconds) {
    if (expirySeconds <= 0) {
      return '--';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000);
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String _formatPrice(
    LimitOrderSummary order,
    Token? sellToken,
    Token? buyToken,
  ) {
    final price = order.targetPrice.trim();
    if (price.isEmpty || price == '0') {
      return '--';
    }
    final isBuy = order.kind.toLowerCase() == 'buy';
    final targetSymbol = isBuy
        ? _symbolFor(buyToken, order.buyToken)
        : _symbolFor(sellToken, order.sellToken);
    final quoteSymbol = isBuy
        ? _symbolFor(sellToken, order.sellToken)
        : _symbolFor(buyToken, order.buyToken);
    return '1 $targetSymbol -> $price $quoteSymbol';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x265D3F3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'ACTIVE ORDERS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: const Color(0xFFC8C6C5),
                ),
              ),
              const Spacer(),
              if (orders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x19EA2A33),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${orders.length}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEA2A33),
                    ),
                  ),
                ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFFC8C6C5),
                splashRadius: 18,
                tooltip: 'Refresh active orders',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Open Owllet limit orders on ${blockchain.activeChain.name}.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF909090),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading && orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFFEA2A33),
                  ),
                ),
              ),
            )
          else if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1F5D3F3D)),
              ),
              child: Text(
                'No active limit orders on this network yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFC8C6C5),
                  height: 1.5,
                ),
              ),
            )
          else
            ...orders.map((order) {
              final isBuy = order.kind.toLowerCase() == 'buy';
              final sellToken = _resolveToken(order.sellToken);
              final buyToken = _resolveToken(order.buyToken);
              final sellSymbol = _symbolFor(sellToken, order.sellToken);
              final buySymbol = _symbolFor(buyToken, order.buyToken);
              final primaryLabel = isBuy ? 'Receive' : 'Sell';
              final primaryValue = isBuy
                  ? '${_formatAmount(order.buyAmount, buyToken)} $buySymbol'
                  : '${_formatAmount(order.sellAmount, sellToken)} $sellSymbol';
              final secondaryLabel = isBuy ? 'Max spend' : 'Min receive';
              final secondaryValue = isBuy
                  ? '${_formatAmount(order.sellAmount, sellToken)} $sellSymbol'
                  : '${_formatAmount(order.buyAmount, buyToken)} $buySymbol';
              final isCancelling = cancellingOrderIds.contains(order.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x1F5D3F3D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isBuy
                                  ? const Color(0x1932D74B)
                                  : const Color(0x19EA2A33),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isBuy ? 'BUY' : 'SELL',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isBuy
                                    ? const Color(0xFF32D74B)
                                    : const Color(0xFFEA2A33),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isBuy ? 'Buy $buySymbol' : 'Sell $sellSymbol',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE2E2E2),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 34,
                            child: OutlinedButton(
                              onPressed: isCancelling
                                  ? null
                                  : () => onCancel(order),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0x33EA2A33),
                                ),
                                backgroundColor: const Color(0x0FEA2A33),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                              ),
                              child: isCancelling
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFEA2A33),
                                      ),
                                    )
                                  : Text(
                                      'Cancel',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFEA2A33),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatPrice(order, sellToken, buyToken),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE2E2E2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _LimitOrderMetric(
                              label: primaryLabel,
                              value: primaryValue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LimitOrderMetric(
                              label: secondaryLabel,
                              value: secondaryValue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Expires ${_formatExpiry(order.expiry)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF909090),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LimitOrderMetric extends StatelessWidget {
  const _LimitOrderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF909090),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFE2E2E2),
            height: 1.4,
          ),
        ),
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
  final bool isBuyMode;
  final VoidCallback onSelectBuyMode;
  final VoidCallback onSelectSellMode;
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
  final double platformFeePercent;
  final double platformFeeUsd;
  final double feeUsd;
  final double feeNative;

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
  final List<LimitOrderSummary> activeOrders;
  final bool isLoadingActiveOrders;
  final VoidCallback onRefreshActiveOrders;
  final ValueChanged<LimitOrderSummary> onCancelActiveOrder;
  final Set<String> cancellingOrderIds;
  final GlobalKey? amountShowcaseKey;
  final GlobalKey? executionPriceShowcaseKey;
  final GlobalKey? expiryShowcaseKey;
  final GlobalKey? summaryShowcaseKey;
  final GlobalKey? submitShowcaseKey;
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
    required this.isBuyMode,
    required this.onSelectBuyMode,
    required this.onSelectSellMode,
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
    required this.platformFeePercent,
    required this.platformFeeUsd,
    required this.feeUsd,
    required this.feeNative,
    required this.targetTokenSymbol,
    required this.quoteToken,
    this.priceDeviationLabel,
    this.onPriceAdjust,
    this.isPositiveAdjust = false,
    this.onToggleAdjustDirection,
    this.limitUsdController,
    this.onLimitUsdChanged,
    required this.onSubmitLimit,
    required this.activeOrders,
    required this.isLoadingActiveOrders,
    required this.onRefreshActiveOrders,
    required this.onCancelActiveOrder,
    required this.cancellingOrderIds,
    this.amountShowcaseKey,
    this.executionPriceShowcaseKey,
    this.expiryShowcaseKey,
    this.summaryShowcaseKey,
    this.submitShowcaseKey,
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
    final orderSideDescription = isBuyMode
        ? 'Buy ${toToken?.symbol ?? 'the receive token'} and cap how much ${fromToken?.symbol ?? 'the spend token'} you spend.'
        : 'Sell ${fromToken?.symbol ?? 'the input token'} and set the minimum ${toToken?.symbol ?? 'the receive token'} you want back.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ORDER SIDE',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.2,
            color: const Color(0xFFC8C6C5),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LimitSideChip(
                label: 'Sell',
                isSelected: !isBuyMode,
                onTap: onSelectSellMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LimitSideChip(
                label: 'Buy',
                isSelected: isBuyMode,
                onTap: onSelectBuyMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            orderSideDescription,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF909090),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ── From / To Cards ──
        _withShowcase(
          showcaseKey: amountShowcaseKey,
          title: 'Limit order size',
          description: isBuyMode
              ? 'Enter the most you want to spend. Owllet previews the amount you would buy at your target price.'
              : 'Enter the amount to sell. The output preview is calculated from your limit price, not from a live market quote.',
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
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
                  const SizedBox(height: 12),
                  SwapToCard(
                    token: toToken,
                    amountText: toAmountText,
                    usdValue: toUsdValue,
                    balance: toBalance,
                    isCalculating: false,
                    onSelectToken: onSelectToToken,
                    chainId: blockchain.activeChain.chainId,
                    statusMessage: null,
                  ),
                ],
              ),
              SwapDirectionButton(onPressed: onSwapTokens),
            ],
          ),
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
        _withShowcase(
          showcaseKey: executionPriceShowcaseKey,
          title: 'Execution price',
          description:
              'Set the target price. Your order can fill only at this price or better.',
          child: LimitExecutionCard(
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
        _withShowcase(
          showcaseKey: expiryShowcaseKey,
          title: 'Order expiry',
          description:
              'Choose how long the order stays open. "Never" keeps it active for up to one year.',
          child: SingleChildScrollView(
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
        ),
        const SizedBox(height: 16),

        _withShowcase(
          showcaseKey: summaryShowcaseKey,
          title: 'Order summary',
          description:
              'Creating or cancelling a limit order costs 0 gas. Your first sell-token approval may still need a network fee.',
          child: SwapPriceDetailsCard(
            priceText: executionPriceText,
            platformFeePercent: platformFeePercent,
            platformFeeUsd: platformFeeUsd,
            feeAmountUsd: feeUsd,
            feeAmountNative: feeNative,
            nativeFeeSymbol: blockchain.activeChain.symbol,
            receiveText: receiveText,
            priceSeparator: priceSeparator,
            swapAmountUsd: fromUsdValue,
            gaslessFeeCovered: false,
            nativePriceUsd: nativePriceUsd,
          ),
        ),
        const SizedBox(height: 16),

        // ── Action Button ──
        _withShowcase(
          showcaseKey: submitShowcaseKey,
          title: 'Submit limit order',
          description:
              'You sign the order with the selected wallet. It stays open until the target price is met or the order expires.',
          child: SwapPrimaryButton(
            enabled: limitEnabled,
            isBusy: limitBusy,
            onPressed: onSubmitLimit,
            label: limitButtonLabel,
          ),
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
        const SizedBox(height: 24),
        _LimitActiveOrdersSection(
          blockchain: blockchain,
          orders: activeOrders,
          isLoading: isLoadingActiveOrders,
          onRefresh: onRefreshActiveOrders,
          onCancel: onCancelActiveOrder,
          cancellingOrderIds: cancellingOrderIds,
        ),
      ],
    );
  }

  Widget _withShowcase({
    required GlobalKey? showcaseKey,
    required String title,
    required String description,
    required Widget child,
  }) {
    if (showcaseKey == null) {
      return child;
    }
    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      child: child,
    );
  }
}
