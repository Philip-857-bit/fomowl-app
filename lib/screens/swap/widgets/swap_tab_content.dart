import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../models/chain.dart';
import '../../../models/token.dart';
import '../../../services/swap_service.dart';
import '../../../services/blockchain_service.dart';
import '../../../utils/amount_utils.dart';
import '../../../widgets/amount_input_mode_toggle.dart';
import 'swap_from_card.dart';
import 'swap_to_card.dart';
import 'swap_direction_button.dart';
import 'swap_price_details_card.dart';
import 'swap_primary_button.dart';
import 'swap_gasless_toggle.dart';
import 'swap_limit_widgets.dart';
import 'swap_slippage_section.dart';

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
  final AmountInputMode fromInputMode;
  final VoidCallback? onToggleFromInputMode;
  final String? fromEquivalentText;
  final int slippageBps;
  final ValueChanged<int> onSlippageChanged;

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
    this.fromInputMode = AmountInputMode.token,
    this.onToggleFromInputMode,
    this.fromEquivalentText,
    this.slippageBps = 50,
    required this.onSlippageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokenIconChainId = blockchain.activeFamily == ChainFamily.evm
        ? blockchain.activeChain.chainId
        : null;
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
                  chainId: tokenIconChainId,
                  inputMode: fromInputMode,
                  onToggleInputMode: onToggleFromInputMode,
                  equivalentText: fromEquivalentText,
                ),
                const SizedBox(height: 12),
                SwapToCard(
                  token: toToken,
                  amountText: toAmountText,
                  usdValue: toUsdValue,
                  balance: toBalance,
                  isCalculating: isCalculating,
                  onSelectToken: onSelectToToken,
                  chainId: tokenIconChainId,
                  statusMessage: isCalculating ? null : quoteStatusMessage,
                ),
              ],
            ),
            SwapDirectionButton(onPressed: onSwapTokens),
          ],
        ),
        const SizedBox(height: 20),
        SwapSlippageSection(
          slippageBps: slippageBps,
          onChanged: onSlippageChanged,
        ),
        if (hasInput) ...[
          const SizedBox(height: 20),
          SwapPriceDetailsCard(
            priceText: priceText,
            platformFeePercent: currentQuote?.platformFeePercent ?? 0.0,
            platformFeeUsd: platformFeeUsd,
            feeAmountUsd: feeUsd,
            feeAmountNative: feeNative,
            nativeFeeSymbol: blockchain.activeNetworkSymbol,
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

  /// Currently selected execution-price adjustment chip (e.g. -25, 50).
  final int selectedPriceAdjustment;

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
  final AmountInputMode fromInputMode;
  final VoidCallback? onToggleFromInputMode;
  final String? fromEquivalentText;
  final AmountInputMode limitPriceInputMode;
  final VoidCallback? onToggleLimitPriceInputMode;

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
    this.selectedPriceAdjustment = 0,
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
    this.fromInputMode = AmountInputMode.token,
    this.onToggleFromInputMode,
    this.fromEquivalentText,
    this.limitPriceInputMode = AmountInputMode.token,
    this.onToggleLimitPriceInputMode,
  });

  @override
  Widget build(BuildContext context) {
    final tokenIconChainId = blockchain.activeFamily == ChainFamily.evm
        ? blockchain.activeChain.chainId
        : null;
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
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF2B3139)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onSelectBuyMode,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isBuyMode
                          ? const Color(0x33800309)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: isBuyMode
                              ? const Color(0xFFEA2A33)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Buy',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isBuyMode
                              ? const Color(0xFFEA2A33)
                              : const Color(0xFF848E9C),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onSelectSellMode,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: !isBuyMode
                          ? const Color(0x1AEA2A33)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: !isBuyMode
                              ? const Color(0xFFEA2A33)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Sell',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: !isBuyMode
                              ? const Color(0xFFEA2A33)
                              : const Color(0xFF848E9C),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ─── BUY: Section 1 = TO card (read-only), Section 2 = FROM card (editable)
        // ─── SELL: Section 1 = FROM card (editable), Section 2 = TO card (read-only)

        // ── Section 1 ──
        _buildSectionLabel(
          isBuyMode ? '1. Amount to Receive' : '1. Amount to Sell',
          '(Estimated)',
        ),
        const SizedBox(height: 10),
        if (isBuyMode)
          _withShowcase(
            showcaseKey: amountShowcaseKey,
            title: 'Amount to receive',
            description: 'The estimated amount of the token you will receive.',
            child: SwapToCard(
              token: toToken,
              amountText: toAmountText,
              usdValue: toUsdValue,
              balance: toBalance,
              isCalculating: false,
              onSelectToken: onSelectToToken,
              chainId: tokenIconChainId,
              statusMessage: null,
            ),
          )
        else ...[
          SwapFromCard(
            controller: fromController,
            token: fromToken,
            usdValue: fromUsdValue,
            balance: fromToken?.balance ?? 0,
            selectedPercentage: selectedPercentage,
            onAmountChanged: onAmountChanged,
            onSelectToken: onSelectFromToken,
            onPercentSelected: onPercentSelected,
            chainId: tokenIconChainId,
            inputMode: fromInputMode,
            onToggleInputMode: onToggleFromInputMode,
            equivalentText: fromEquivalentText,
            headerLabel: null,
            showInternalChips: false,
          ),
          const SizedBox(height: 8),
          _LimitChipsRow(
            selectedPercentage: selectedPercentage,
            onPercentSelected: onPercentSelected,
            balance: fromToken?.balance ?? 0,
            symbol: fromToken?.symbol ?? '',
          ),
        ],

        const SizedBox(height: 20),

        // ── Section 2 ──
        _buildSectionLabel(
          isBuyMode ? '2. I want to spend' : '2. Amount to Receive',
          isBuyMode ? null : '(Estimated)',
        ),
        const SizedBox(height: 10),
        if (isBuyMode) ...[
          SwapFromCard(
            controller: fromController,
            token: fromToken,
            usdValue: fromUsdValue,
            balance: fromToken?.balance ?? 0,
            selectedPercentage: selectedPercentage,
            onAmountChanged: onAmountChanged,
            onSelectToken: onSelectFromToken,
            onPercentSelected: onPercentSelected,
            chainId: tokenIconChainId,
            inputMode: fromInputMode,
            onToggleInputMode: onToggleFromInputMode,
            equivalentText: fromEquivalentText,
            headerLabel: null,
            showInternalChips: false,
          ),
          const SizedBox(height: 8),
          _LimitChipsRow(
            selectedPercentage: selectedPercentage,
            onPercentSelected: onPercentSelected,
            balance: fromToken?.balance ?? 0,
            symbol: fromToken?.symbol ?? '',
          ),
        ] else
          SwapToCard(
            token: toToken,
            amountText: toAmountText,
            usdValue: toUsdValue,
            balance: toBalance,
            isCalculating: false,
            onSelectToken: onSelectToToken,
            chainId: tokenIconChainId,
            statusMessage: null,
          ),

        const SizedBox(height: 20),

        // ── Section 3: Limit price ──
        _buildSectionLabel(
          '3. Limit price',
          isBuyMode
              ? 'Set the price at which you want to buy ${toToken?.symbol ?? ''}'
              : 'Set the price at which you want to sell ${fromToken?.symbol ?? ''}',
        ),
        const SizedBox(height: 10),
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
            chainId: tokenIconChainId,
            priceDeviationLabel: priceDeviationLabel,
            usdController: limitUsdController,
            onUsdChanged: onLimitUsdChanged,
            priceInputMode: limitPriceInputMode,
            onToggleInputMode: onToggleLimitPriceInputMode,
          ),
        ),
        const SizedBox(height: 12),
        // ── YOU'LL SPEND / YOU'LL RECEIVE summary boxes ──
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF151C24),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A333D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBuyMode ? "YOU'LL SPEND (MAX)" : "YOU'LL SELL (MAX)",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF848E9C),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fromUsdValue > 0
                          ? '\$${fromUsdValue.toStringAsFixed(2)}'
                          : '--',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF151C24),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A333D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBuyMode
                          ? "YOU'LL RECEIVE (ESTIMATED)"
                          : "YOU'LL GET (ESTIMATED)",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF848E9C),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      toAmountText.isNotEmpty && toAmountText != '0'
                          ? '$toAmountText ${toToken?.symbol ?? ''}'
                          : '--',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionLabel('4. Order expiry', null),
        const SizedBox(height: 12),
        _withShowcase(
          showcaseKey: expiryShowcaseKey,
          title: 'Order expiry',
          description: 'Choose how long the order stays open.',
          child: Row(
            children: [
              Expanded(
                child: LimitExpiryChip(
                  label: '1H',
                  selected: is1hSelected,
                  onTap: onSelect1h,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LimitExpiryChip(
                  label: '24H',
                  selected: is24hSelected,
                  onTap: onSelect24h,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LimitExpiryChip(
                  label: '7D',
                  selected: is7dSelected,
                  onTap: onSelect7d,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onPickCustomExpiry,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isCustomExpirySelected
                          ? const Color(0x19EA2A33)
                          : const Color(0xFF151C24),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCustomExpirySelected
                            ? const Color(0xFFEA2A33)
                            : const Color(0xFF2A333D),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Custom',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isCustomExpirySelected
                                ? const Color(0xFFEA2A33)
                                : const Color(0xFF848E9C),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: isCustomExpirySelected
                              ? const Color(0xFFEA2A33)
                              : const Color(0xFF848E9C),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
            nativeFeeSymbol: blockchain.activeNetworkSymbol,
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

  Widget _buildSectionLabel(String primary, String? secondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          primary,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (secondary != null) ...[
          const SizedBox(width: 6),
          Text(
            secondary,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF8894A0),
            ),
          ),
        ],
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

class _LimitChipsRow extends StatelessWidget {
  final int selectedPercentage;
  final void Function(int) onPercentSelected;
  final double balance;
  final String symbol;

  const _LimitChipsRow({
    required this.selectedPercentage,
    required this.onPercentSelected,
    required this.balance,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final chipPercents = [25, 50, 70, 100];
    return Row(
      children: [
        ...chipPercents.map(
          (p) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onPercentSelected(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selectedPercentage == p
                      ? const Color(0x1AEA2A33)
                      : const Color(0xFF131313),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selectedPercentage == p
                        ? const Color(0x4DEA2A33)
                        : const Color(0x0DFFFFFF),
                  ),
                ),
                child: Text(
                  p == 100 ? '100%' : '$p%',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: selectedPercentage == p
                        ? const Color(0xFFEA2A33)
                        : const Color(0xFFA1A1A1),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 11,
          color: Color(0xFF848E9C),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => onPercentSelected(100),
          child: Text(
            '${balance.toStringAsFixed(2)} $symbol',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF848E9C),
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => onPercentSelected(100),
          child: Text(
            'Max',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFEA2A33),
            ),
          ),
        ),
      ],
    );
  }
}
