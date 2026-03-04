import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/token.dart';
import '../../services/blockchain_service.dart';
import '../../utils/toast_utils.dart';
import 'widgets/token_detail/token_detail_header.dart';
import 'widgets/token_detail/price_overview.dart';
import 'widgets/token_detail/token_chart_card.dart';
import 'widgets/token_detail/timeframe_selector.dart';
import 'widgets/token_detail/token_actions_row.dart';
import 'widgets/token_detail/balance_summary_card.dart';
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
      } catch (_) {}
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
    Clipboard.setData(ClipboardData(text: value));
    ToastUtils.showSuccess('Copied to clipboard');
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  // Map token symbol to CoinGecko ID
  String _tokenToCoinGeckoId(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'ETH':
        return 'ethereum';
      case 'BTC':
        return 'bitcoin';
      case 'BNB':
        return 'binancecoin';
      case 'USDC':
        return 'usd-coin';
      case 'USDT':
        return 'tether';
      case 'MATIC':
        return 'matic-network';
      case 'AVAX':
        return 'avalanche-2';
      case 'FTM':
        return 'fantom';
      case 'CRO':
        return 'crypto-com-chain';
      case 'XDAI':
      case 'DAI':
        return 'xdai';
      case 'KLAY':
        return 'klay-token';
      default:
        return '';
    }
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
      _reloadTokenMarketData(force: true);
    } else {
      _refreshTokenFromService();
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

  Token? _findMatchingToken(List<Token> tokens, Token target) {
    final addr = (target.contractAddress ?? '').toLowerCase();
    if (addr.isNotEmpty) {
      try {
        return tokens.firstWhere(
          (t) => (t.contractAddress ?? '').toLowerCase() == addr,
        );
      } catch (_) {}
    }
    try {
      return tokens.firstWhere((t) => t.symbol == target.symbol);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchChartData() async {
    setState(() => _isLoadingChart = true);
    final coinId = _resolveCoinGeckoId();
    if (coinId == null || coinId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _priceData = [];
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
        _priceData = data;
        _isLoadingChart = false;
      });
    }
  }

  Future<void> _fetchTokenStats() async {
    setState(() => _isLoadingInfo = true);
    final coinId = _resolveCoinGeckoId();
    if (coinId == null || coinId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _marketData = null;
        _isLoadingInfo = false;
      });
      return;
    }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final stats = await blockchain.getTokenMarketData(coinId);
    if (!mounted) return;
    setState(() {
      _marketData = stats;
      _isLoadingInfo = false;
    });
  }

  String _formatFiatValue(double? value) {
    if (value == null || value <= 0) return '\$0.00';
    if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)}T';
    if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)}M';
    if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(2)}K';
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatSupplyValue(double? value) {
    if (value == null || value <= 0) return '0';
    if (value >= 1e12) return '${(value / 1e12).toStringAsFixed(2)}T';
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(2)}K';
    return value.toStringAsFixed(0);
  }

  String _formatPriceLabel(double? price) {
    if (price == null || price <= 0) return '\$0.00';
    if (price >= 1000) return '\$${price.toStringAsFixed(0)}';
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  String _formatHoldingsValue(Token token, double? priceUsd) {
    if (priceUsd == null || priceUsd <= 0) return token.formattedValue;
    final usdValue = token.balance * priceUsd;
    return _formatFiatValue(usdValue);
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
    final mapped = _tokenToCoinGeckoId(token?.symbol ?? '');
    if (mapped.isEmpty) return null;
    return mapped;
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
    final token = _token;
    if (token == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: Text('Token not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final blockchain = Provider.of<BlockchainService>(context);
    final networkName = blockchain.activeChain.name;
    final marketCapText = _isLoadingInfo
        ? 'Loading...'
        : _formatFiatValue(_marketData?.marketCapUsd);
    final totalSupplyText = _isLoadingInfo
        ? 'Loading...'
        : _formatSupplyValue(_marketData?.totalSupply);
    final circulatingSupplyText = _isLoadingInfo
        ? 'Loading...'
        : _formatSupplyValue(_marketData?.circulatingSupply);
    final livePriceUsd = _marketData?.priceUsd ?? token.unitPriceUsd;
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
                              onTap: () =>
                                  Navigator.pushNamed(context, '/send-token'),
                            ),
                            TokenActionData(
                              icon: Icons.sync_alt_rounded,
                              label: 'Swap',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/swap'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        BalanceSummaryCard(token: token),
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
