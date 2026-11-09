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
import '../../models/token_standard.dart';
import '../swap/swap_screen.dart';
import '../../services/blockchain/bitcoin_catalog.dart';
import '../../services/blockchain/blockchain_catalog.dart';
import '../../services/blockchain/solana_catalog.dart';
import '../../services/blockchain/tron_catalog.dart';
import '../../services/blockchain_service.dart';
import '../../utils/toast_utils.dart';
import '../../utils/value_formatter.dart';
import 'widgets/token_detail/token_detail_header.dart';
import 'widgets/token_detail/price_overview.dart';
import 'widgets/token_detail/token_chart_card.dart';
import 'widgets/token_detail/timeframe_selector.dart';
import '../../utils/in_app_link_router.dart';
import 'widgets/token_detail/token_actions_row.dart';
import 'widgets/token_detail/token_info_table.dart';

/// Token Detail Screen
/// Shows price, chart placeholder, quick actions, balance, and token info
class TokenDetailScreen extends StatefulWidget {
  const TokenDetailScreen({super.key});

  static EvmChain? _findChainInService(
    BlockchainService? blockchain,
    int chainId,
  ) {
    if (blockchain == null) return null;
    try {
      return blockchain.allChains.firstWhere((c) => c.chainId == chainId);
    } catch (_) {
      return null;
    }
  }

  static String? resolveNetworkExplorerUrl(
    Token token, {
    BlockchainService? blockchain,
  }) {
    String? baseUrl;
    final networkKey = token.networkKey?.trim();
    if (networkKey != null && networkKey.isNotEmpty) {
      final family = NetworkKey.familyOf(networkKey);
      switch (family) {
        case ChainFamily.evm:
          final chainId = NetworkKey.evmChainIdOf(networkKey);
          if (chainId != null) {
            final chain =
                BlockchainCatalog.findChain(chainId) ??
                _findChainInService(blockchain, chainId);
            baseUrl = chain?.explorerUrl;
          }
          break;
        case ChainFamily.solana:
          final chain = SolanaCatalog.builtInChains.firstWhere(
            (c) => c.networkKey == networkKey,
            orElse: () => SolanaCatalog.mainnet,
          );
          baseUrl = chain.explorerUrl;
          break;
        case ChainFamily.tron:
          final chain = TronCatalog.builtInChains.firstWhere(
            (c) => c.networkKey == networkKey,
            orElse: () => TronCatalog.mainnet,
          );
          baseUrl = chain.explorerUrl;
          break;
        case ChainFamily.bitcoin:
          final chain = BitcoinCatalog.builtInChains.firstWhere(
            (c) => c.networkKey == networkKey,
            orElse: () => BitcoinCatalog.mainnet,
          );
          baseUrl = chain.explorerUrl;
          break;
      }
    }
    baseUrl ??= blockchain?.activeNetworkExplorerUrl;
    if (baseUrl == null || baseUrl.trim().isEmpty) return null;
    return baseUrl.trim().endsWith('/')
        ? baseUrl.trim().substring(0, baseUrl.trim().length - 1)
        : baseUrl.trim();
  }

  static String? resolveExplorerUrl(
    Token token, {
    BlockchainService? blockchain,
  }) {
    final baseUrl = resolveNetworkExplorerUrl(token, blockchain: blockchain);
    if (baseUrl == null) return null;
    final contract = token.contractAddress?.trim();
    if (contract == null || contract.isEmpty) {
      return baseUrl;
    }
    final family = token.networkKey != null
        ? NetworkKey.familyOf(token.networkKey!)
        : (blockchain?.activeFamily ?? ChainFamily.evm);
    switch (family) {
      case ChainFamily.solana:
        if (baseUrl.contains('?cluster=')) {
          final parts = baseUrl.split('?cluster=');
          return '${parts[0]}/address/$contract?cluster=${parts[1]}';
        }
        return '$baseUrl/address/$contract';
      case ChainFamily.tron:
        return '$baseUrl/#/token20/$contract';
      case ChainFamily.evm:
      case ChainFamily.bitcoin:
        return '$baseUrl/token/$contract';
    }
  }

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
  bool _hasAppliedInitialNetwork = false;
  Token? _metadataToken;
  String? _metadataNetworkKey;
  int _metadataGeneration = 0;
  int _chartGeneration = 0;
  int _statsGeneration = 0;

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
      TokenInfoRowData(
        label: 'Network',
        value: networkName,
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new, color: Colors.white54, size: 16),
          tooltip: 'Explorer',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          onPressed: () => _openNetworkExplorer(token),
        ),
      ),
      TokenInfoRowData(
        label: 'Contract Address',
        value: contract == null || contract.isEmpty
            ? '--'
            : _shortenAddress(contract),
        trailing: (contract == null || contract.isEmpty)
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.white54,
                      size: 16,
                    ),
                    tooltip: 'Copy',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _copyText(contract),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.open_in_new,
                      color: Colors.white54,
                      size: 16,
                    ),
                    tooltip: 'Explorer',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _openExplorer(token, contract),
                  ),
                ],
              ),
      ),
      TokenInfoRowData(label: 'Decimals', value: '${token.decimals}'),
      TokenInfoRowData(label: 'Balance', value: token.formattedBalance),
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

  Future<void> _openExplorer(Token token, String contract) async {
    final explorerUrl = TokenDetailScreen.resolveExplorerUrl(
      token,
      blockchain: _blockchain,
    );
    if (explorerUrl != null && explorerUrl.isNotEmpty) {
      await InAppLinkRouter.open(context, explorerUrl);
    }
  }

  Future<void> _openNetworkExplorer(Token token) async {
    final baseUrl = TokenDetailScreen.resolveNetworkExplorerUrl(
      token,
      blockchain: _blockchain,
    );
    if (baseUrl != null && baseUrl.isNotEmpty) {
      await InAppLinkRouter.open(context, baseUrl);
    }
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
        if (!_hasAppliedInitialNetwork &&
            passedToken.networkKey != null &&
            passedToken.networkKey != service.activeNetworkKey) {
          _hasAppliedInitialNetwork = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && service.activeNetworkKey != passedToken.networkKey) {
              service.setActiveNetworkKey(passedToken.networkKey!);
            }
          });
        }
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
    unawaited(_enrichTokenMetadataIfNeeded());
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
    if (_metadataNetworkKey != blockchain.activeNetworkKey) {
      _metadataNetworkKey = blockchain.activeNetworkKey;
      _metadataToken = null;
      ++_metadataGeneration;
    }
    final networkKey = current.networkKey ?? blockchain.activeNetworkKey;
    // Detection currently uses the service's active network. Wait for the
    // route's network switch rather than querying the previous chain.
    if (blockchain.activeNetworkKey != networkKey ||
        identical(_metadataToken, current)) {
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

    _metadataToken = current;
    final generation = ++_metadataGeneration;
    try {
      final resolved = await blockchain.detectTokenByContract(contract);
      if (!mounted ||
          resolved == null ||
          generation != _metadataGeneration ||
          !identical(_token, current) ||
          blockchain.activeNetworkKey != networkKey ||
          (resolved.networkKey != null && resolved.networkKey != networkKey)) {
        return;
      }
      setState(() {
        _token = _mergeResolvedMetadata(current, resolved);
      });
      _reloadTokenMarketData(force: true);
    } finally {
      if (generation == _metadataGeneration) _metadataToken = null;
    }
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
      decimals: resolved.decimals >= 0 ? resolved.decimals : current.decimals,
      imageUrl: (resolved.imageUrl?.trim().isNotEmpty ?? false)
          ? resolved.imageUrl
          : current.imageUrl,
      coinGeckoId: (resolved.coinGeckoId?.trim().isNotEmpty ?? false)
          ? resolved.coinGeckoId
          : current.coinGeckoId,
      isCertified: current.isCertified,
      networkKey: current.networkKey ?? resolved.networkKey,
      tokenStandard: current.tokenStandard != TokenStandard.erc20
          ? current.tokenStandard
          : resolved.tokenStandard,
      // PATCH: Preserve backend price source metadata when metadata is refreshed.
      priceSource: current.priceSource,
      priceStatus: current.priceStatus,
      priceUpdatedAt: current.priceUpdatedAt,
      // PATCH: Preserve backend DEX liquidity metadata when metadata is refreshed.
      liquidityUsd: current.liquidityUsd,
      // PATCH: Preserve backend DEX-only marker when metadata is refreshed.
      isDexOnly: current.isDexOnly,
    );
  }

  Token? _findMatchingToken(List<Token> tokens, Token target) {
    final addr = (target.contractAddress ?? '').trim().toLowerCase();
    final targetNetwork = target.networkKey?.trim().toLowerCase();
    if (addr.isNotEmpty) {
      if (targetNetwork != null) {
        for (final t in tokens) {
          if ((t.contractAddress ?? '').trim().toLowerCase() == addr &&
              (t.networkKey == null ||
                  t.networkKey?.trim().toLowerCase() == targetNetwork)) {
            return t;
          }
        }
      } else {
        for (final t in tokens) {
          if ((t.contractAddress ?? '').trim().toLowerCase() == addr) {
            return t;
          }
        }
      }
      // If contract address was specified, never fall back to matching an unrelated token by symbol.
      return null;
    }

    // Native token matching: target contract address is empty
    if (targetNetwork != null) {
      for (final t in tokens) {
        final tAddr = (t.contractAddress ?? '').trim();
        if (tAddr.isEmpty &&
            t.symbol == target.symbol &&
            (t.networkKey == null ||
                t.networkKey?.trim().toLowerCase() == targetNetwork)) {
          return t;
        }
      }
    } else {
      for (final t in tokens) {
        final tAddr = (t.contractAddress ?? '').trim();
        if (tAddr.isEmpty && t.symbol == target.symbol) {
          return t;
        }
      }
    }
    return null;
  }

  Future<void> _fetchChartData() async {
    final generation = ++_chartGeneration;
    setState(() => _isLoadingChart = true);
    final coinId = _resolveCoinGeckoId();
    if (coinId == null || coinId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _priceData = const [];
        _isLoadingChart = false;
      });
      return;
    }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final data = await blockchain.getPriceHistoryForTimeframe(
      coinId,
      _selectedTimeframe,
    );
    if (mounted && generation == _chartGeneration) {
      setState(() {
        _priceData = data;
        _isLoadingChart = false;
      });
    }
  }

  Future<void> _fetchTokenStats() async {
    final generation = ++_statsGeneration;
    setState(() => _isLoadingInfo = true);
    final coinId = _resolveCoinGeckoId();
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final token = _token;
    final networkKey = token?.networkKey ?? blockchain.activeNetworkKey;
    TokenMarketData? stats;
    if (coinId != null && coinId.isNotEmpty) {
      stats = await blockchain.getTokenMarketData(coinId);
    } else if (blockchain.activeNetworkKey == networkKey &&
        token?.contractAddress != null &&
        token!.contractAddress!.isNotEmpty) {
      stats = await blockchain.getBackendTokenMarketData(
        token.contractAddress!,
      );
    }
    if (!mounted || generation != _statsGeneration) return;
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
    if (isNative && blockchain != null) {
      final networkKey = token.networkKey ?? blockchain.activeNetworkKey;
      final chainId = NetworkKey.evmChainIdOf(networkKey);
      if (chainId != null) {
        return (BlockchainCatalog.findChain(chainId) ??
                TokenDetailScreen._findChainInService(blockchain, chainId))
            ?.coinGeckoId;
      }
      if (blockchain.activeNetworkKey == networkKey) {
        return blockchain.activeNetworkCoinGeckoId;
      }
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

  String _resolveNetworkName(Token token, BlockchainService blockchain) {
    final networkKey = token.networkKey?.trim();
    if (networkKey != null && networkKey.isNotEmpty) {
      final family = NetworkKey.familyOf(networkKey);
      switch (family) {
        case ChainFamily.evm:
          final chainId = NetworkKey.evmChainIdOf(networkKey);
          if (chainId != null) {
            final chain =
                BlockchainCatalog.findChain(chainId) ??
                TokenDetailScreen._findChainInService(blockchain, chainId);
            if (chain != null && chain.name.isNotEmpty) return chain.name;
          }
          break;
        case ChainFamily.solana:
          final chain = SolanaCatalog.builtInChains.firstWhere(
            (c) => c.networkKey == networkKey,
            orElse: () => SolanaCatalog.mainnet,
          );
          return chain.name;
        case ChainFamily.tron:
          final chain = TronCatalog.builtInChains.firstWhere(
            (c) => c.networkKey == networkKey,
            orElse: () => TronCatalog.mainnet,
          );
          return chain.name;
        case ChainFamily.bitcoin:
          final chain = BitcoinCatalog.builtInChains.firstWhere(
            (c) => c.networkKey == networkKey,
            orElse: () => BitcoinCatalog.mainnet,
          );
          return chain.name;
      }
    }
    return blockchain.activeNetworkName;
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
    final networkName = _resolveNetworkName(token, blockchain);
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
                  chainId: token.networkKey != null
                      ? NetworkKey.evmChainIdOf(token.networkKey!)
                      : (_blockchain?.activeFamily == ChainFamily.evm
                            ? _blockchain?.activeChain.chainId
                            : null),
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
                                arguments: token,
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
