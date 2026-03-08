import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_environment.dart';
import '../../constants/app_colors.dart';
import '../../models/token.dart';
import '../../widgets/bottom_navigation.dart';
import '../../services/wallet_service.dart';
import '../../services/storage_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/token_visibility_service.dart';
import '../../services/nft_service.dart';
import '../../services/push_notification_registration_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';
import '../../utils/token_visibility_utils.dart';
import '../../utils/value_formatter.dart';
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
  final TokenVisibilityService _tokenVisibilityService =
      TokenVisibilityService();
  final NftService _nftService = NftService();
  final PushNotificationRegistrationService _pushRegistrationService =
      PushNotificationRegistrationService();
  BlockchainService? _blockchain;

  String? _walletName;
  bool _isLoading = true;
  bool _isLoadingBalances = false;
  bool _isLoadingNfts = false;
  double _totalBalance = 0.0;
  bool _balanceVisible = true;
  bool _hasUnreadNotifications = false;
  bool? _hasInternet;
  String _connectivityStatus = '';
  int? _lastChainId;
  Set<String> _hiddenTokenKeys = {};
  List<NftAsset> _nftPreview = [];
  bool _hasMoreNfts = false;
  bool _clipboardChecked = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadWalletData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context);
    if (_connectivityStatus.isEmpty) {
      _connectivityStatus = l.checkingStatus;
    }
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
      final response = await http
          .get(Uri.parse(AppEnvironment.connectivityCheckUrl))
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() {
          _hasInternet =
              response.statusCode == 200 || response.statusCode == 429;
          _connectivityStatus = _hasInternet! ? l.connected : l.noConnection;
        });
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() {
          _hasInternet = false;
          _connectivityStatus = l.noInternetConnection;
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
        final l = AppLocalizations.of(context);
        setState(() {
          _walletName = name ?? l.mainWallet;
          _isLoading = false;
        });
      }

      if (address != null && address.isNotEmpty) {
        unawaited(_pushRegistrationService.syncForActiveWallet());
        await Future.wait([
          _fetchRealBalances(address),
          _fetchNftPreview(address),
          _refreshNotificationDot(address: address),
        ]);
        await _checkClipboardTokenSuggestion();
      } else {
        if (mounted) {
          setState(() {
            _tokens = [];
            _totalBalance = 0.0;
            _nftPreview = [];
            _hasMoreNfts = false;
            _hasUnreadNotifications = false;
            _isLoadingNfts = false;
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

  bool _isContractAddress(String value) {
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value.trim());
  }

  bool _tokenExistsForAddress(String contractAddress) {
    final target = contractAddress.toLowerCase();
    return _tokens.any(
      (token) => (token.contractAddress ?? '').toLowerCase() == target,
    );
  }

  Future<void> _checkClipboardTokenSuggestion() async {
    if (_clipboardChecked || !mounted) return;
    _clipboardChecked = true;

    try {
      final data = await Clipboard.getData('text/plain');
      if (!mounted) return;
      final copied = data?.text?.trim() ?? '';
      if (!_isContractAddress(copied)) return;
      if (_tokenExistsForAddress(copied)) return;

      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final l = AppLocalizations.of(context);
      final detected = await blockchain.detectTokenByContract(copied);
      if (detected == null || !mounted) return;

      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l.tokenDetected,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detected.name,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                detected.symbol,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 10),
              Text(
                copied,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l.ignore,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.background,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context).addToken),
            ),
          ],
        ),
      );

      if (shouldAdd != true || !mounted) return;
      final added = await blockchain.addCustomToken(
        chainId: blockchain.activeChain.chainId,
        token: detected,
      );
      if (!added) {
        ToastUtils.showInfo(l.tokenAlreadyExistsOnNetwork);
        return;
      }
      await _loadWalletData();
      if (!mounted) return;
      ToastUtils.showSuccess(l.tokenAddedFromClipboard(detected.symbol));
    } catch (e, stackTrace) {
      debugPrint('Clipboard check error: $e');
      debugPrint(stackTrace.toString());
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
            final chain = Provider.of<BlockchainService>(
              context,
              listen: false,
            ).activeChain;
            _tokens = [
              Token(
                symbol: chain.symbol,
                name: chain.name,
                balance: 0,
                valueUsd: 0,
                changePercent24h: 0,
                coinGeckoId: chain.coinGeckoId,
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
      _fetchNftPreview(address);
      _refreshNotificationDot(address: address);
    });
  }

  void _calculateTotalBalance() {
    var total = ValueFormatter.decimalFromNum(0);
    for (final token in _tokens) {
      total += token.totalValueUsdDecimal;
    }
    if (mounted) {
      setState(() => _totalBalance = ValueFormatter.doubleFromDecimal(total));
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

  Future<void> _refreshNotificationDot({String? address}) async {
    try {
      final walletAddress =
          address ?? await _walletService.getCurrentWalletAddress();
      if (walletAddress == null || walletAddress.isEmpty) {
        if (mounted) {
          setState(() => _hasUnreadNotifications = false);
        }
        return;
      }

      final url = AppEnvironment.notifications('/$walletAddress');
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        if (mounted) {
          setState(() => _hasUnreadNotifications = false);
        }
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final notifications = data['notifications'] as List<dynamic>? ?? const [];
      final hasUnread = notifications.any((item) {
        final notification = item as Map<String, dynamic>;
        final isRead =
            notification['is_read'] == 1 || notification['is_read'] == true;
        return !isRead;
      });

      if (mounted) {
        setState(() => _hasUnreadNotifications = hasUnread);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasUnreadNotifications = false);
      }
    }
  }

  Future<void> _fetchNftPreview(String address) async {
    if (address.isEmpty) {
      if (mounted) {
        setState(() {
          _nftPreview = [];
          _hasMoreNfts = false;
          _isLoadingNfts = false;
        });
      }
      return;
    }

    final chain = Provider.of<BlockchainService>(
      context,
      listen: false,
    ).activeChain;
    if (!_nftService.isSupportedChain(chain.chainId)) {
      if (mounted) {
        setState(() {
          _nftPreview = [];
          _hasMoreNfts = false;
          _isLoadingNfts = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingNfts = true);
    }

    try {
      final nfts = await _nftService.fetchOwnedNfts(
        chainId: chain.chainId,
        chainName: chain.name,
        walletAddress: address,
      );
      if (!mounted) return;
      setState(() {
        _nftPreview = nfts.take(8).toList();
        _hasMoreNfts = nfts.length > 8;
        _isLoadingNfts = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _nftPreview = [];
          _hasMoreNfts = false;
          _isLoadingNfts = false;
        });
      }
    }
  }

  String get _formattedTotalBalance {
    if (!_balanceVisible) return '******';
    return ValueFormatter.formatCurrencyWithGrouping(
      ValueFormatter.decimalFromNum(_totalBalance),
    );
  }

  Future<void> _openSocialLink() async {
    final uri = Uri.parse('https://x.com/fomowlhq');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      ToastUtils.showError(AppLocalizations.of(context).unableToOpenLink('X'));
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
        onAddCustomNetwork: () async {
          Navigator.pop(ctx);
          await Navigator.pushNamed(context, '/add-network');
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentRed),
            )
          : SafeArea(
              child: Column(
                children: [
                  HomeTopBar(
                    walletName: _walletName ?? l.mainWallet,
                    onWalletTap: () async {
                      await Navigator.pushNamed(context, '/wallets');
                      await _loadWalletData();
                    },
                    chainSymbol: Provider.of<BlockchainService>(
                      context,
                    ).activeChain.symbol,
                    chainLogoUrl: Provider.of<BlockchainService>(
                      context,
                    ).activeChain.logoUrl,
                    onChainTap: _showNetworkSelector,
                    showNotificationDot: _hasUnreadNotifications,
                    onNotificationsTap: () async {
                      await Navigator.pushNamed(context, '/notifications');
                      await _refreshNotificationDot();
                    },
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
                              onToggleVisibility: () => setState(
                                () => _balanceVisible = !_balanceVisible,
                              ),
                              onHistoryTap: () =>
                                  Navigator.pushNamed(context, '/transactions'),
                              onDepositTap: () => Navigator.pushNamed(
                                context,
                                '/deposit-funds',
                              ),
                            ),
                            const SizedBox(height: 24),
                            QuickActionsRow(
                              onReceive: () => Navigator.pushNamed(
                                context,
                                '/receive-token',
                              ),
                              onSend: () =>
                                  Navigator.pushNamed(context, '/send-token'),
                              onWithdraw: () => Navigator.pushNamed(
                                context,
                                '/withdraw-to-bank',
                              ),
                            ),
                            const SizedBox(height: 24),
                            SocialBannerCard(onTap: _openSocialLink),
                            const SizedBox(height: 28),
                            TokensSection(
                              tokens: _tokens,
                              isLoading: _isLoadingBalances,
                              isLoadingNfts: _isLoadingNfts,
                              nftPreview: _nftPreview,
                              hasMoreNfts: _hasMoreNfts,
                              localization: l,
                              onManageTokens: _openTokenManager,
                              onOpenNfts: () {
                                if (_hasMoreNfts) {
                                  Navigator.pushNamed(context, '/nft-gallery');
                                  return;
                                }
                                if (_nftPreview.isEmpty) {
                                  ToastUtils.showInfo(l.noNftsToDisplay);
                                } else {
                                  ToastUtils.showInfo(l.moreNftsAvailable);
                                }
                              },
                              isTokenHidden: _isTokenHidden,
                              chainId: _lastChainId,
                              onSelectToken: (token) {
                                Navigator.pushNamed(
                                  context,
                                  '/token-detail',
                                  arguments: token,
                                );
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
