import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/token.dart';
import '../../widgets/bottom_navigation.dart';
import '../../services/wallet_service.dart';
import '../../services/storage_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/token_visibility_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';
import '../../utils/token_visibility_utils.dart';
import 'widgets/balance_card.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/network_selector_sheet.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/social_banner_card.dart';
import 'widgets/tokens_section.dart';

/// Home Screen - Main Wallet Dashboard
/// Shows wallet balance, quick actions, and token list
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Token> _tokens = [];
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();
  final TokenVisibilityService _tokenVisibilityService = TokenVisibilityService();
  BlockchainService? _blockchain;
  
  
  String? _walletName;
  bool _isLoading = true;
  bool _isLoadingBalances = false;
  double _totalBalance = 0.0;
  bool _balanceVisible = true;
  bool? _hasInternet;
  String _connectivityStatus = 'Checking...';
  int? _lastChainId;
  Set<String> _hiddenTokenKeys = {};

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadWalletData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newService = Provider.of<BlockchainService>(context);
    if (!identical(_blockchain, newService)) {
      _blockchain?.removeListener(_handleBlockchainChange);
      _blockchain = newService;
      _lastChainId = newService.activeChain.chainId;
      _blockchain?.addListener(_handleBlockchainChange);
    }
  }

  @override
  void dispose() {
    _blockchain?.removeListener(_handleBlockchainChange);
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _hasInternet = response.statusCode == 200 || response.statusCode == 429;
          _connectivityStatus = _hasInternet! ? 'Connected' : 'No connection';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasInternet = false;
          _connectivityStatus = 'No Internet Connection';
        });
      }
    }
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      _lastChainId = blockchain.activeChain.chainId;
      await _loadHiddenTokens(_lastChainId!);
      final address = await _walletService.getCurrentWalletAddress();
      final name = await _storage.getWalletName();
      
      if (mounted) {
        setState(() {
          _walletName = name ?? 'Main Wallet';
          _isLoading = false;
        });
      }

      if (address != null && address.isNotEmpty) {
        await _fetchRealBalances(address);
      } else {
        if (mounted) {
          setState(() {
            _tokens = [];
            _totalBalance = 0.0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _tokens = [];
          _totalBalance = 0.0;
        });
      }
    }
  }

  Future<void> _fetchRealBalances(String address) async {
    setState(() => _isLoadingBalances = true);

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final realTokens = await blockchain.fetchWalletTokens(address);

      if (mounted) {
        setState(() {
          _tokens = realTokens;
          _isLoadingBalances = false;
        });
        _calculateTotalBalance();
        _lastChainId = blockchain.activeChain.chainId;
      }
    } catch (e) {
      debugPrint('Error fetching balances: $e');
      if (mounted) {
        setState(() {
          _isLoadingBalances = false;
          // Fallback: show native token with 0 balance so list isn't empty
          if (_tokens.isEmpty) {
            final chain = Provider.of<BlockchainService>(context, listen: false).activeChain;
            _tokens = [
              Token(
                symbol: chain.symbol,
                name: chain.name,
                balance: 0,
                valueUsd: 0,
                changePercent24h: 0,
                coinGeckoId: chain.coinGeckoId.isNotEmpty ? chain.coinGeckoId : null,
              ),
            ];
          }
        });
      }
    }
  }

  void _handleBlockchainChange() {
    if (!mounted) return;
    final chainId = _blockchain?.activeChain.chainId;
    if (chainId == null || chainId == _lastChainId) return;
    _lastChainId = chainId;
    _loadHiddenTokens(chainId);
    _walletService.getCurrentWalletAddress().then((address) {
      if (!mounted || address == null) return;
      _fetchRealBalances(address);
    });
  }

  void _calculateTotalBalance() {
    double total = 0.0;
    for (var token in _tokens) {
      total += token.totalValueUsd;
    }
    if (mounted) {
      setState(() => _totalBalance = total);
    }
  }

  Future<void> _loadHiddenTokens(int chainId) async {
    final hidden = await _tokenVisibilityService.loadHiddenTokens(chainId);
    if (mounted) {
      setState(() => _hiddenTokenKeys = hidden);
    } else {
      _hiddenTokenKeys = hidden;
    }
  }

  bool _isTokenHidden(Token token) {
    return _hiddenTokenKeys.contains(TokenVisibilityUtils.identifier(token));
  }


  String get _formattedTotalBalance {
    if (!_balanceVisible) return '••••••';
    return '\$${_totalBalance.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  void _navigateComingSoon(String feature) {
    Navigator.pushNamed(context, '/coming-soon', arguments: feature);
  }

  Future<void> _openSocialLink() async {
    final uri = Uri.parse('https://x.com/fomowlhq');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ToastUtils.showError('Unable to open X right now');
    }
  }

  Future<void> _openTokenManager() async {
    final result = await Navigator.pushNamed(context, '/token-management');
    if (result == true) {
      final chainId = _lastChainId;
      if (chainId != null) {
        await _loadHiddenTokens(chainId);
      }
      final address = await _walletService.getCurrentWalletAddress();
      if (address != null) {
        await _fetchRealBalances(address);
      }
    }
  }

  void _showNetworkSelector() {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => NetworkSelectorSheet(
        chains: blockchain.allChains,
        activeChainId: blockchain.activeChain.chainId,
        onSelect: (chain) {
          blockchain.setActiveChain(chain);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentRed))
          : SafeArea(
              child: Column(
                children: [
                  HomeTopBar(
                    walletName: _walletName ?? 'Main Wallet',
                    onWalletTap: () => Navigator.pushNamed(context, '/wallets'),
                    chainSymbol: Provider.of<BlockchainService>(context).activeChain.symbol,
                    onChainTap: _showNetworkSelector,
                    onNotificationsTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.accentRed,
                      onRefresh: _loadWalletData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConnectivityBanner(
                              show: _hasInternet != null && !_hasInternet!,
                              statusText: _connectivityStatus,
                            ),
                            const SizedBox(height: 8),
                            BalanceCard(
                              formattedBalance: _formattedTotalBalance,
                              isBalanceVisible: _balanceVisible,
                              isLoadingBalances: _isLoadingBalances,
                              onToggleVisibility: () => setState(() => _balanceVisible = !_balanceVisible),
                              onHistoryTap: () => _navigateComingSoon('Transaction History'),
                              onDepositTap: () => _navigateComingSoon('Deposit Funds'),
                            ),
                            const SizedBox(height: 24),
                            QuickActionsRow(
                              onReceive: () => Navigator.pushNamed(context, '/receive-token'),
                              onSend: () => Navigator.pushNamed(context, '/send-token'),
                              onWithdraw: () => _navigateComingSoon('Withdraw to Bank'),
                            ),
                            const SizedBox(height: 24),
                            SocialBannerCard(onTap: _openSocialLink),
                            const SizedBox(height: 28),
                            TokensSection(
                              tokens: _tokens,
                              isLoading: _isLoadingBalances,
                              localization: l,
                              onManageTokens: _openTokenManager,
                              onOpenNfts: () => Navigator.pushNamed(context, '/nft-gallery'),
                              isTokenHidden: _isTokenHidden,
                              onSelectToken: (token) {
                                Navigator.pushNamed(context, '/token-detail', arguments: token);
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) => BottomNavBar.handleNavigation(context, index, 0),
      ),
    );
  }

}
