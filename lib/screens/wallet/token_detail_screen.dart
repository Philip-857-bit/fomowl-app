import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';

import '../../constants/app_colors.dart';
import '../../features/shell/app_shell_controller.dart';
import '../../models/chain.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../models/token_market_data.dart';
import '../swap/swap_screen.dart';
import '../../services/blockchain_service.dart';
import '../../utils/toast_utils.dart';
import '../../utils/value_formatter.dart';
import 'widgets/token_detail/token_detail_header.dart';
import 'widgets/token_detail/price_overview.dart';
import 'widgets/token_detail/token_chart_card.dart';
import 'widgets/token_detail/timeframe_selector.dart';
import 'widgets/token_detail/token_actions_row.dart';
import 'widgets/token_detail/token_info_table.dart';

/// Token Detail Screen
/// Shows price, chart placeholder, quick actions, balance, and token info
class TokenDetailScreen extends StatefulWidget {
  const TokenDetailScreen({super.key});

  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen> {
  Token? _token;
  bool _isFavorite = false;
  String _selectedTimeframe = '1D';
  List<double> _priceData = [];
  bool _isLoadingChart = true;
  TokenMarketData? _marketData;
  bool _isLoadingInfo = false;
  BlockchainService? _blockchain;
  String? _lastResolvedCoinId;
  int? _lastChainId;

  final List<String> _timeframes = ['5M', '1H', '1D', '1W', '1M', '1Y'];

  List<TokenInfoRowData> _buildTokenInfoRows({
    required Token token,
    required String networkName,
    required String marketCapText,
    required String totalSupplyText,
    required String circulatingSupplyText,
  }) {
    final genesis = _marketData?.genesisDate;
    String createdOn = '--';
    if (genesis != null && genesis.isNotEmpty) {
      try {
        createdOn = DateFormat.yMMMEd().format(DateTime.parse(genesis));
      } catch (e) {
        debugPrint('Error parsing genesis date: $e');
      }
    }
    final contract = token.contractAddress;
    return [
      TokenInfoRowData(label: 'Name', value: token.name),
      TokenInfoRowData(label: 'Ticker', value: token.symbol),
      TokenInfoRowData(label: 'Network', value: networkName),
      TokenInfoRowData(
        label: 'Contract Address',
        value: contract == null || contract.isEmpty
            ? '--'
            : _shortenAddress(contract),
        trailing: (contract == null || contract.isEmpty)
            ? null
            : IconButton(
                icon: const Icon(Icons.copy, color: Colors.white54, size: 16),
                onPressed: () => _copyText(contract),
              ),
      ),
      TokenInfoRowData(label: 'Market Cap', value: marketCapText),
      TokenInfoRowData(label: 'Total Supply', value: totalSupplyText),
      TokenInfoRowData(
        label: 'Circulating Supply',
        value: circulatingSupplyText,
      ),
      const TokenInfoRowData(label: 'Holders', value: '0'),
      TokenInfoRowData(label: 'Created On', value: createdOn),
    ];
  }

  void _copyText(String value) {
    final l = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: value));
    ToastUtils.showSuccess(l.copiedToClipboard);
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = Provider.of<BlockchainService>(context, listen: false);
    if (!identical(_blockchain, service)) {
      _blockchain?.removeListener(_handleBlockchainUpdate);
      _blockchain = service;
      _blockchain?.addListener(_handleBlockchainUpdate);
    }

    if (_token == null) {
      final passedToken = ModalRoute.of(context)?.settings.arguments as Token?;
      if (passedToken != null) {
        // Try to grab the live token from BlockchainService to ensure up-to-date balance
        final tokens = service.tokens;
        _token = _findMatchingToken(tokens, passedToken) ?? passedToken;
      }
      unawaited(_enrichTokenMetadataIfNeeded());
      _reloadTokenMarketData(force: true);
    } else {
      _refreshTokenFromService();
      unawaited(_enrichTokenMetadataIfNeeded());
      _reloadTokenMarketData();
    }
  }

  @override
  void dispose() {
    _blockchain?.removeListener(_handleBlockchainUpdate);
    super.dispose();
  }

  void _handleBlockchainUpdate() {
    if (!mounted) return;
    _refreshTokenFromService();
    _reloadTokenMarketData();
  }

  void _refreshTokenFromService() {
    final current = _token;
    final service = _blockchain;
    if (current == null || service == null) return;
    final updated = _findMatchingToken(service.tokens, current);
    if (updated != null && !identical(updated, current)) {
      setState(() {
        _token = updated;
      });
      _reloadTokenMarketData(force: true);
    }
  }

  Future<void> _enrichTokenMetadataIfNeeded() async {
    final current = _token;
    final blockchain = _blockchain;
    if (!mounted || current == null || blockchain == null) {
      return;
    }
    final contract = current.contractAddress?.trim();
    if (contract == null || contract.isEmpty) {
      return;
    }
    final needsEnrichment =
        (current.imageUrl == null || current.imageUrl!.trim().isEmpty) ||
        (current.coinGeckoId == null || current.coinGeckoId!.trim().isEmpty) ||
        current.name.trim().isEmpty;
    if (!needsEnrichment) {
      return;
    }

    final resolved = await blockchain.detectTokenByContract(contract);
    if (!mounted || resolved == null) {
      return;
    }
    setState(() {
      _token = _mergeResolvedMetadata(current, resolved);
    });
  }

  Token _mergeResolvedMetadata(Token current, CustomTokenDefinition resolved) {
    return Token(
      symbol: resolved.symbol.isNotEmpty ? resolved.symbol : current.symbol,
      name: resolved.name.isNotEmpty ? resolved.name : current.name,
      contractAddress: current.contractAddress,
      balance: current.balance,
      valueUsd: current.valueUsd,
      priceUsd: current.priceUsd,
      changePercent24h: current.changePercent24h,
      decimals: resolved.decimals > 0 ? resolved.decimals : current.decimals,
      imageUrl: (resolved.imageUrl?.trim().isNotEmpty ?? false)
          ? resolved.imageUrl
          : current.imageUrl,
      coinGeckoId: (resolved.coinGeckoId?.trim().isNotEmpty ?? false)
          ? resolved.coinGeckoId
          : current.coinGeckoId,
      isCertified: current.isCertified,
      // PATCH: Preserve backend price source metadata when metadata is refreshed.
      priceSource: current.priceSource,
      // PATCH: Preserve backend DEX liquidity metadata when metadata is refreshed.
      liquidityUsd: current.liquidityUsd,
      // PATCH: Preserve backend DEX-only marker when metadata is refreshed.
      isDexOnly: current.isDexOnly,
    );
  }

  Token? _findMatchingToken(List<Token> tokens, Token target) {
    final addr = (target.contractAddress ?? '').toLowerCase();
    if (addr.isNotEmpty) {
      try {
        return tokens.firstWhere(
          (t) => (t.contractAddress ?? '').toLowerCase() == addr,
        );
      } catch (e) {
        debugPrint('Error finding token by address: $e');
      }
    }
    try {
      return tokens.firstWhere((t) => t.symbol == target.symbol);
    } catch (e) {
      debugPrint('Error finding token by symbol: $e');
      return null;
    }
  }

  Future<void> _fetchChartData() async {
    setState(() => _isLoadingChart = true);
    final coinId = _resolveCoinGeckoId();
    if (coinId == null || coinId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _priceData = _buildFallbackChartData();
        _isLoadingChart = false;
      });
      return;
    }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final data = await blockchain.getPriceHistoryForTimeframe(
      coinId,
      _selectedTimeframe,
    );
    if (mounted) {
      setState(() {
        _priceData = data.isNotEmpty ? data : _buildFallbackChartData();
        _isLoadingChart = false;
      });
    }
  }

  Future<void> _fetchTokenStats() async {
    setState(() => _isLoadingInfo = true);
    final coinId = _resolveCoinGeckoId();
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    TokenMarketData? stats;
    if (coinId != null && coinId.isNotEmpty) {
      stats = await blockchain.getTokenMarketData(coinId);
    } else if (_token?.contractAddress != null &&
        _token!.contractAddress!.isNotEmpty) {
      stats = await blockchain.getBackendTokenMarketData(
        _token!.contractAddress!,
      );
    }
    if (!mounted) return;
    setState(() {
      _marketData = stats;
      _isLoadingInfo = false;
    });
  }

  String _formatFiatValue(double? value) {
    return ValueFormatter.formatUsdValue(ValueFormatter.decimalFromNum(value));
  }

  String _formatSupplyValue(double? value) {
    return ValueFormatter.formatCompactNumber(
      ValueFormatter.decimalFromNum(value),
    );
  }

  String _formatPriceLabel(double? price) {
    final decimal = ValueFormatter.decimalFromNum(price);
    if (decimal <= Decimal.zero) {
      return ValueFormatter.formatUsdPrice(decimal);
    }

    final priceDouble = ValueFormatter.doubleFromDecimal(decimal);
    if (priceDouble >= 1) {
      return ValueFormatter.formatUsdPrice(decimal);
    }

    if (priceDouble >= 0.01) {
      return '\$${_trimTrailingZeros(priceDouble.toStringAsFixed(4))}';
    }

    if (priceDouble >= 0.000001) {
      return '\$${_trimTrailingZeros(priceDouble.toStringAsFixed(8))}';
    }

    return '\$${_trimTrailingZeros(priceDouble.toStringAsFixed(10))}';
  }

  String _trimTrailingZeros(String value) {
    final withoutTrailingZeros = value.replaceFirst(RegExp(r'0+$'), '');
    return withoutTrailingZeros.replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatHoldingsValue(Token token, double? priceUsd) {
    if (priceUsd == null || priceUsd <= 0) return token.formattedValue;
    return ValueFormatter.formatUsdValue(
      token.balanceDecimal * ValueFormatter.decimalFromNum(priceUsd),
    );
  }

  String? _resolveCoinGeckoId() {
    final token = _token;
    final blockchain = _blockchain;
    if (token != null &&
        token.coinGeckoId != null &&
        token.coinGeckoId!.isNotEmpty) {
      return token.coinGeckoId!;
    }
    final isNative =
        token != null &&
        (token.contractAddress == null || token.contractAddress!.isEmpty);
    if (isNative &&
        blockchain != null &&
        blockchain.activeChain.coinGeckoId != null &&
        blockchain.activeChain.coinGeckoId!.isNotEmpty) {
      return blockchain.activeChain.coinGeckoId!;
    }
    return null;
  }

  double _resolvedDisplayPriceUsd() {
    final marketPrice = _marketData?.priceUsd;
    if (marketPrice != null && marketPrice > 0) {
      return marketPrice;
    }
    final token = _token;
    if (token == null) {
      return 0;
    }
    return token.unitPriceUsd;
  }

  List<double> _buildFallbackChartData() {
    final token = _token;
    if (token == null) {
      return const [];
    }

    final currentPrice = _resolvedDisplayPriceUsd();
    if (currentPrice <= 0) {
      return const [];
    }

    final changePercent = token.changePercent24h;
    final denominator = 1 + (changePercent / 100);
    final baselinePrice = denominator > 0
        ? currentPrice / denominator
        : currentPrice;
    final safeBaseline = baselinePrice.isFinite && baselinePrice > 0
        ? baselinePrice
        : currentPrice;
    final delta = currentPrice - safeBaseline;
    const pointCount = 24;

    return List<double>.generate(pointCount, (index) {
      final progress = pointCount == 1 ? 1.0 : index / (pointCount - 1);
      final wave = (progress < 0.5 ? progress : (1 - progress)) * 0.04;
      final next = safeBaseline + (delta * progress) + (currentPrice * wave);
      return next > 0 && next.isFinite ? next : currentPrice;
    });
  }

  void _reloadTokenMarketData({bool force = false}) {
    final blockchain = _blockchain;
    final coinId = _resolveCoinGeckoId();
    final chainId = blockchain?.activeChain.chainId;
    if (!force && coinId == _lastResolvedCoinId && chainId == _lastChainId) {
      return;
    }
    _lastResolvedCoinId = coinId;
    _lastChainId = chainId;
    _fetchChartData();
    _fetchTokenStats();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final token = _token;
    if (token == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            l.tokenNotFound,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final blockchain = Provider.of<BlockchainService>(context);
    final networkName = blockchain.activeNetworkName;
    final marketCapText = _isLoadingInfo
        ? l.loading
        : _formatFiatValue(_marketData?.marketCapUsd);
    final totalSupplyText = _isLoadingInfo
        ? l.loading
        : _formatSupplyValue(_marketData?.totalSupply);
    final circulatingSupplyText = _isLoadingInfo
        ? l.loading
        : _formatSupplyValue(_marketData?.circulatingSupply);
    final livePriceUsd = _resolvedDisplayPriceUsd();
    final priceDisplay = _formatPriceLabel(livePriceUsd);
    final holdingsDisplay = _formatHoldingsValue(token, _marketData?.priceUsd);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 230,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentGradientStart.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                TokenDetailHeader(
                  token: token,
                  isFavorite: _isFavorite,
                  onBack: () => Navigator.pop(context),
                  onToggleFavorite: () =>
                      setState(() => _isFavorite = !_isFavorite),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PriceOverview(
                          priceText: priceDisplay,
                          changeText: token.formattedChange,
                          holdingsText: holdingsDisplay,
                          isPositiveChange: token.isPositiveChange,
                        ),
                        const SizedBox(height: 20),
                        TokenChartCard(
                          isLoading: _isLoadingChart,
                          data: _priceData,
                        ),
                        const SizedBox(height: 16),
                        TimeframeSelector(
                          timeframes: _timeframes,
                          selected: _selectedTimeframe,
                          onSelected: (tf) {
                            setState(() => _selectedTimeframe = tf);
                            _fetchChartData();
                          },
                        ),
                        const SizedBox(height: 20),
                        TokenActionsRow(
                          actions: [
                            TokenActionData(
                              icon: Icons.south_rounded,
                              label: 'Receive',
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/receive-token',
                              ),
                            ),
                            TokenActionData(
                              icon: Icons.north_rounded,
                              label: 'Send',
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/send-token',
                                arguments: token,
                              ),
                            ),
                            TokenActionData(
                              icon: Icons.sync_alt_rounded,
                              label: 'Swap',
                              onTap: () {
                                // Open one standalone Swap route above token
                                // details. This preserves the back button and
                                // avoids the legacy /swap redirect creating a
                                // second app shell.
                                context
                                    .read<AppShellController>()
                                    .openSwapWithToken(token);
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SwapScreen(
                                      showBottomNavigation: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TokenInfoTable(
                          rows: _buildTokenInfoRows(
                            token: token,
                            networkName: networkName,
                            marketCapText: marketCapText,
                            totalSupplyText: totalSupplyText,
                            circulatingSupplyText: circulatingSupplyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
