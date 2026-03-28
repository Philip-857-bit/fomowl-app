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
import '../../services/currency_controller.dart';
import '../../services/token_visibility_service.dart';
import '../../services/nft_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/push_notification_registration_service.dart';
import '../../services/screen_capture_guard.dart';
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
import '../../services/home_snapshot_service.dart';

/// Home Screen - Main Wallet Dashboard
/// Shows wallet balance, quick actions, and token list
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _livePriceScope = 'home_screen';
  List<Token> _tokens = [];
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();
  final TokenVisibilityService _tokenVisibilityService =
      TokenVisibilityService();
  final NftService _nftService = NftService();
  final PushNotificationRegistrationService _pushRegistrationService =
      PushNotificationRegistrationService();
  final ScreenCaptureGuard _screenCaptureGuard = ScreenCaptureGuard();
  final HomeSnapshotService _snapshotService = HomeSnapshotService();
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
  bool _isUsingCachedData = false;
  int _deferredLoadGeneration = 0;
  StreamSubscription<TokenVisibilityChange>? _tokenVisibilitySubscription;
  StreamSubscription<AppNotificationEvent>? _notificationEventSubscription;
  String _lastTokenSignature = '';

  @override
  void initState() {
    super.initState();
    _tokenVisibilitySubscription = _tokenVisibilityService.changes.listen((
      change,
    ) {
      if (!mounted || change.chainId != _lastChainId) {
        return;
      }
      setState(() => _hiddenTokenKeys = change.hiddenTokens);
    });
    _notificationEventSubscription = AppNotificationService().events.listen((
      event,
    ) {
      unawaited(_handleNotificationEvent(event));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_screenCaptureGuard.disableProtection());
      unawaited(_checkConnectivity());
      unawaited(_loadWalletData());
    });
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
    _deferredLoadGeneration++;
    _blockchain?.clearLivePriceTracking(scope: _livePriceScope);
    _blockchain?.removeListener(_handleBlockchainChange);
    _tokenVisibilitySubscription?.cancel();
    _notificationEventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleNotificationEvent(AppNotificationEvent event) async {
    final currentWalletAddress = await _walletService.getCurrentWalletAddress();
    if (!mounted ||
        currentWalletAddress == null ||
        currentWalletAddress.isEmpty) {
      return;
    }

    final eventWalletAddress = event.walletAddress?.trim().toLowerCase();
    if (eventWalletAddress != null &&
        eventWalletAddress.isNotEmpty &&
        eventWalletAddress != currentWalletAddress.toLowerCase()) {
      return;
    }

    await _refreshNotificationDot(address: currentWalletAddress);
  }

  String _buildTokenSignature(List<Token> tokens) {
    return tokens
        .map((token) {
          final contractAddress = (token.contractAddress ?? '').toLowerCase();
          final imageUrl = token.imageUrl ?? '';
          return [
            contractAddress,
            token.symbol.toLowerCase(),
            token.name.toLowerCase(),
            token.balance.toStringAsPrecision(12),
            token.priceUsd.toStringAsPrecision(12),
            imageUrl,
          ].join(':');
        })
        .join('|');
  }

  double _sumTokenUsdValue(List<Token> tokens) {
    var total = ValueFormatter.decimalFromNum(0);
    for (final token in tokens) {
      total += token.totalValueUsdDecimal;
    }
    return ValueFormatter.doubleFromDecimal(total);
  }

  void _replaceDisplayedTokens(
    List<Token> tokens, {
    required bool isUsingCachedData,
  }) {
    final nextTokens = List<Token>.from(tokens);
    _tokens = nextTokens;
    _totalBalance = _sumTokenUsdValue(nextTokens);
    _lastTokenSignature = _buildTokenSignature(nextTokens);
    _isUsingCachedData = isUsingCachedData;
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
    if (!mounted) return;
    debugPrint('[OWLLET] Starting wallet data load...');
    setState(() => _isLoading = true);

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);

      debugPrint('[OWLLET] Initializing BlockchainService...');
      await blockchain.init().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[OWLLET] CRITICAL: Blockchain init timed out after 10s');
        },
      );

      _lastChainId = blockchain.activeChain.chainId;
      debugPrint('[OWLLET] Active Chain ID: $_lastChainId');

      await _loadHiddenTokens(_lastChainId!);
      final address = await _walletService.getCurrentWalletAddress();
      final name = await _storage.getWalletName();
      if (address != null && address.isNotEmpty) {
        // Load snapshot before unblocking UI with _isLoading = false
        final snapshot = await _snapshotService.loadSnapshot(
          _lastChainId!,
          address,
        );
        if (snapshot != null && mounted) {
          setState(() {
            _replaceDisplayedTokens(snapshot.tokens, isUsingCachedData: true);
            _walletName = snapshot.walletName;
          });
          blockchain.setLivePriceTrackingForTokens(
            _tokens,
            scope: _livePriceScope,
          );
          debugPrint(
            '[OWLLET] Loaded cached snapshot: ${_tokens.length} tokens',
          );
        }

        if (mounted) {
          final l = AppLocalizations.of(context);
          setState(() {
            _walletName ??= name ?? l.mainWallet;
            _isLoading = false;
          });
          debugPrint('[OWLLET] Loading state cleared. UI unblocked.');
        }

        debugPrint('[OWLLET] Triggering background data sync...');
        unawaited(_fetchRealBalances(address));
        _scheduleDeferredHomeTasks(address);
      } else {
        if (mounted) {
          final l = AppLocalizations.of(context);
          setState(() {
            _walletName = name ?? l.mainWallet;
            _isLoading = false;
          });
        }
        debugPrint('[OWLLET] WARNING: No wallet address found during init');
      }
    } catch (e, stack) {
      debugPrint('[OWLLET] ERROR in _loadWalletData: $e');
      debugPrint('[OWLLET] STACKTRACE: $stack');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scheduleDeferredHomeTasks(String address) {
    final generation = ++_deferredLoadGeneration;
    unawaited(_runDeferredHomeTasks(address, generation));
  }

  Future<void> _runDeferredHomeTasks(String address, int generation) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || generation != _deferredLoadGeneration) {
      return;
    }

    unawaited(_safeSyncPushRegistration());
    unawaited(_refreshNotificationDot(address: address));

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || generation != _deferredLoadGeneration) {
      return;
    }

    unawaited(_fetchNftPreview(address));
    unawaited(_checkClipboardTokenSuggestion());
  }

  Future<void> _safeSyncPushRegistration() async {
    try {
      final walletAddress = await _walletService.getCurrentWalletAddress();
      if (walletAddress == null || walletAddress.isEmpty) {
        return;
      }
      final pushEnabled = await _storage.getPushNotificationsEnabledForWallet(
        walletAddress,
      );
      if (pushEnabled == false) {
        return;
      }
      await _pushRegistrationService.syncForActiveWallet();
    } catch (error, stackTrace) {
      debugPrint('Push registration failed during home load: $error');
      debugPrint(stackTrace.toString());
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
          _replaceDisplayedTokens(realTokens, isUsingCachedData: false);
          _isLoadingBalances = false;
        });
        blockchain.setLivePriceTrackingForTokens(
          _tokens,
          scope: _livePriceScope,
        );
        _lastChainId = blockchain.activeChain.chainId;

        // Save fresh snapshot
        final name = await _storage.getWalletName();
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        _snapshotService.saveSnapshot(
          HomePortfolioSnapshot(
            walletAddress: address,
            chainId: _lastChainId!,
            walletName: name ?? l.mainWallet,
            totalBalance: _totalBalance,
            tokens: _tokens,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching balances: $e');
      if (mounted) {
        setState(() {
          _isLoadingBalances = false;
          // Keep existing tokens on transient failures. Only inject a native
          // placeholder when we truly have nothing to show.
          if (_tokens.isEmpty && !_isUsingCachedData) {
            final chain = Provider.of<BlockchainService>(
              context,
              listen: false,
            ).activeChain;
            _replaceDisplayedTokens([
              Token(
                symbol: chain.symbol,
                name: chain.name,
                balance: 0,
                valueUsd: 0,
                changePercent24h: 0,
                coinGeckoId: chain.coinGeckoId,
              ),
            ], isUsingCachedData: false);
          }
        });
      }
    }
  }

  void _handleBlockchainChange() {
    if (!mounted) return;
    final blockchain = _blockchain;
    final chainId = blockchain?.activeChain.chainId;
    if (blockchain == null || chainId == null) return;

    if (chainId == _lastChainId) {
      final nextTokens = blockchain.tokens;
      final nextSignature = _buildTokenSignature(nextTokens);
      if (nextSignature == _lastTokenSignature) {
        return;
      }
      setState(() {
        _replaceDisplayedTokens(nextTokens, isUsingCachedData: false);
      });
      blockchain.setLivePriceTrackingForTokens(_tokens, scope: _livePriceScope);
      return;
    }

    _lastChainId = chainId;
    _loadHiddenTokens(chainId);
    _walletService.getCurrentWalletAddress().then((address) async {
      if (!mounted || address == null) return;

      // Attempt to load snapshot for the new chain to show something instantly
      final snapshot = await _snapshotService.loadSnapshot(chainId, address);
      if (snapshot != null && mounted) {
        setState(() {
          _replaceDisplayedTokens(snapshot.tokens, isUsingCachedData: true);
        });
        _blockchain?.setLivePriceTrackingForTokens(
          _tokens,
          scope: _livePriceScope,
        );
      } else if (mounted) {
        setState(() {
          _replaceDisplayedTokens(const [], isUsingCachedData: false);
        });
      }

      _fetchRealBalances(address);
      _scheduleDeferredHomeTasks(address);
    });
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

      final normalizedAddress = walletAddress.trim().toLowerCase();
      final url = AppEnvironment.notifications('/$normalizedAddress');
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

    final blockchain = Provider.of<BlockchainService>(context, listen: false);

    if (mounted) {
      setState(() => _isLoadingNfts = true);
    }

    try {
      final activeChain = blockchain.activeChain;
      final orderedChains = [
        activeChain,
        ...blockchain.allChains.where(
          (chain) => chain.chainId != activeChain.chainId,
        ),
      ];
      final nfts = await _nftService.fetchOwnedNftsAcrossChains(
        chains: orderedChains,
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
    final hasChanges = await Navigator.pushNamed(context, '/token-management');
    if (hasChanges == true && mounted) {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      setState(() {
        _replaceDisplayedTokens(blockchain.tokens, isUsingCachedData: false);
      });
      blockchain.setLivePriceTrackingForTokens(_tokens, scope: _livePriceScope);

      final address = await _walletService.getCurrentWalletAddress();
      if (address != null && address.isNotEmpty) {
        unawaited(_fetchRealBalances(address));
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
    context.select<CurrencyController, String>((c) => c.currencyCode);
    final l = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context);
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
                    chainSymbol: blockchain.activeChain.symbol,
                    chainLogoUrl: blockchain.activeChain.logoUrl,
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
                            if (blockchain.lastDiscoveryPartialFailure)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  0,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33F59E0B),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0x66F59E0B),
                                    ),
                                  ),
                                  child: Text(
                                    blockchain
                                                .lastDiscoveryMessage
                                                ?.isNotEmpty ==
                                            true
                                        ? blockchain.lastDiscoveryMessage!
                                        : l.networkError,
                                    style: const TextStyle(
                                      color: Color(0xFFFFE7C2),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
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
                            ),
                            const SizedBox(height: 24),
                            QuickActionsRow(
                              onReceive: () => Navigator.pushNamed(
                                context,
                                '/receive-token',
                              ),
                              onSend: () =>
                                  Navigator.pushNamed(context, '/send-token'),
                              onSwap: () =>
                                  Navigator.pushNamed(context, '/swap'),
                            ),
                            const SizedBox(height: 24),
                            SocialBannerCard(onTap: _openSocialLink),
                            const SizedBox(height: 28),
                            TokensSection(
                              tokens: _tokens,
                              isLoading:
                                  _isLoadingBalances && !_isUsingCachedData,
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
