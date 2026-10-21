import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../config/app_environment.dart';
import '../../constants/app_colors.dart';
import '../../features/mini_apps/mini_app_host_screen.dart';
import '../../features/mini_apps/mini_app_registry.dart';
import '../../features/shell/app_shell_controller.dart';
import '../../models/chain.dart';
import '../profile/add_network_screen.dart';
import '../../models/token.dart';
import '../../widgets/bottom_navigation.dart';
import '../../services/wallet_service.dart';
import '../../services/storage_service.dart';
import '../../services/affiliate_attribution_service.dart';
import '../../services/runtime_config_service.dart';
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
import '../../utils/in_app_link_router.dart';
import 'home_banner_item.dart';
import 'home_banner_snapshot_service.dart';
import 'home_banner_service.dart';
import 'home_portfolio_data.dart';
import 'home_portfolio_api_service.dart';
import 'home_portfolio_metrics.dart';
import 'home_portfolio_metrics_calculator.dart';
import 'home_portfolio_repository.dart';
import 'home_portfolio_snapshot_service.dart';
import 'widgets/balance_card.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/home_promo_carousel.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/network_selector_sheet.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/tokens_section.dart';
import '../../services/home_snapshot_service.dart';
import '../../services/app_release_checker.dart';
import '../../services/connectivity_recovery.dart';
import 'widgets/whats_new_sheet.dart';

/// Home Screen - Main Wallet Dashboard
/// Shows wallet balance, quick actions, and token list
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.showBottomNavigation = true,
    this.refreshRevision = 0,
  });

  final bool showBottomNavigation;
  final int refreshRevision;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _livePriceScope = 'home_screen';
  static const String _homeShowcaseSeenKey = 'home_showcase_seen_v1';

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshRevision != oldWidget.refreshRevision) {
      unawaited(_refreshBalancesAfterMiniApp());
    }
  }

  Future<String?> _networkDataWalletIdentity(ChainFamily family) =>
      family == ChainFamily.bitcoin
      ? _walletService.getCurrentWalletAddress()
      : _walletService.getActiveAddressForFamily(family);

  Future<void> _refreshBalancesAfterMiniApp() async {
    final blockchain = _blockchain;
    if (!mounted || blockchain == null) return;
    final address = await _networkDataWalletIdentity(blockchain.activeFamily);
    if (!mounted || address == null || address.isEmpty) return;
    await _fetchRealBalances(address, forceRefresh: true);
    if (mounted && _portfolioRuntimeEnabled) {
      await _fetchPortfolioData(address, sync: true);
    }
  }

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
  final HomeBannerService _homeBannerService = HomeBannerService();
  final HomeBannerSnapshotService _homeBannerSnapshotService =
      HomeBannerSnapshotService();
  final HomePortfolioRepository _portfolioRepository =
      const HomePortfolioRepository();
  final HomePortfolioApiService _portfolioApiService =
      HomePortfolioApiService();
  final HomePortfolioSnapshotService _portfolioSnapshotService =
      HomePortfolioSnapshotService();
  BlockchainService? _blockchain;

  String? _walletName;
  bool _isLoading = true;
  bool _isLoadingBalances = false;
  bool _balanceLoadFailed = false;
  bool _isLoadingPortfolio = false;
  bool _isLoadingNfts = false;
  HomePortfolioMetrics _portfolioMetrics = HomePortfolioMetrics.zero();
  List<HomePortfolioSection> _portfolioSections = const [];
  List<HomePortfolioSection> _portfolioRawSections = const [];
  DateTime? _portfolioUpdatedAt;
  bool _balanceVisible = true;
  bool _hasUnreadNotifications = false;
  bool? _hasInternet;
  String _connectivityStatus = '';
  int? _lastChainId;
  String? _lastNetworkKey;
  String? _lastWalletAddress;
  Set<String> _hiddenTokenKeys = {};
  List<NftAsset> _nftPreview = [];
  bool _hasMoreNfts = false;
  bool _clipboardChecked = false;
  bool _isUsingCachedData = false;
  int _deferredLoadGeneration = 0;
  bool _isLoadingHomeBanners = false;
  bool _homeShowcaseScheduled = false;
  bool _showFallbackSocialBanner = true;
  bool _whatsNewChecked = false;
  int _walletLoadGeneration = 0;
  final AppReleaseChecker _releaseChecker = AppReleaseChecker();
  final ConnectivityRecovery _connectivityRecovery = ConnectivityRecovery();
  final RuntimeConfigService _runtimeConfig = RuntimeConfigService.instance;
  StreamSubscription<TokenVisibilityChange>? _tokenVisibilitySubscription;
  StreamSubscription<AppNotificationEvent>? _notificationEventSubscription;
  String _lastTokenSignature = '';
  HomeAssetTab _selectedAssetTab = HomeAssetTab.tokens;
  String? _latestLiveBalanceWallet;
  List<HomeBannerItem> _homeBanners = const [];
  int _homeBannerIndex = 0;
  Timer? _homeBannerRotationTimer;
  Timer? _connectivityTimer;
  final PageController _homeBannerPageController = PageController();
  final GlobalKey _walletSwitcherShowcaseKey = GlobalKey();
  final GlobalKey _balanceShowcaseKey = GlobalKey();
  final GlobalKey _quickActionsShowcaseKey = GlobalKey();
  final GlobalKey _promoCarouselShowcaseKey = GlobalKey();
  final GlobalKey _assetTabsShowcaseKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _runtimeConfig.addListener(_handleRuntimeConfigChanged);
    _tokenVisibilitySubscription = _tokenVisibilityService.changes.listen((
      change,
    ) {
      if (!mounted) {
        return;
      }
      final blockchain = _blockchain;
      if (blockchain != null &&
          change.chainId == _effectiveVisibilityChainId(blockchain)) {
        setState(() => _hiddenTokenKeys = change.hiddenTokens);
      }
      unawaited(_reloadPortfolioFromCachedTokens());
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
      unawaited(_loadWalletData(forcePortfolioSync: true));
      unawaited(_loadHomeBanners());
    });
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted &&
          (_hasInternet == false || _connectivityRecovery.hasPendingRetry)) {
        unawaited(_checkConnectivity());
      }
    });
  }

  void _handleRuntimeConfigChanged() {
    if (!mounted) return;
    if (!_runtimeConfig.snapshot.portfolioUiEnabled &&
        _selectedAssetTab == HomeAssetTab.portfolio) {
      _selectedAssetTab = HomeAssetTab.tokens;
    }
    setState(() {});
    if (_runtimeConfig.snapshot.portfolioEnabled &&
        _runtimeConfig.snapshot.portfolioUiEnabled) {
      unawaited(_loadWalletData());
    }
  }

  bool get _portfolioRuntimeEnabled =>
      _runtimeConfig.snapshot.portfolioEnabled &&
      _runtimeConfig.snapshot.portfolioUiEnabled;

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
      _lastChainId = _activePortfolioChainId(newService);
      _lastNetworkKey = newService.activeNetworkKey;
      _blockchain?.addListener(_handleBlockchainChange);
    }
  }

  @override
  void dispose() {
    _walletLoadGeneration++;
    _deferredLoadGeneration++;
    _homeBannerRotationTimer?.cancel();
    _connectivityTimer?.cancel();
    _homeBannerPageController.dispose();
    _homeBannerService.dispose();
    _blockchain?.clearLivePriceTracking(scope: _livePriceScope);
    _blockchain?.removeListener(_handleBlockchainChange);
    _tokenVisibilitySubscription?.cancel();
    _notificationEventSubscription?.cancel();
    _runtimeConfig.removeListener(_handleRuntimeConfigChanged);
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
            // PATCH: Price-source changes should refresh DEX badges.
            token.priceSource,
            // PATCH: DEX-only changes should refresh DEX badges.
            token.isDexOnly.toString(),
            imageUrl,
          ].join(':');
        })
        .join('|');
  }

  void _replaceDisplayedTokens(
    List<Token> tokens, {
    required bool isUsingCachedData,
  }) {
    final nextTokens = List<Token>.from(tokens);
    _tokens = nextTokens;
    _lastTokenSignature = _buildTokenSignature(nextTokens);
    _isUsingCachedData = isUsingCachedData;
  }

  void _applyPortfolioData(HomePortfolioData data) {
    _portfolioSections = List<HomePortfolioSection>.from(data.sections);
    _portfolioMetrics = data.metrics;
  }

  List<Token> _displayableTokens(List<Token> tokens) {
    final userAdded = <String>{
      for (final c in (_blockchain?.customTokensForActiveChain ?? const []))
        c.address.trim().toLowerCase(),
    };
    final visible = _portfolioRepository.prepareVisibleTokens(
      tokens,
      _hiddenTokenKeys,
      userAddedAddresses: userAdded,
      chainId: _blockchain?.activeTokenStorageChainId ?? 0,
    );
    final blockchain = _blockchain;
    if (blockchain == null) {
      return visible;
    }

    final byKey = <String, Token>{
      for (final token in visible)
        ((token.contractAddress?.trim().isNotEmpty == true
                        ? token.contractAddress
                        : token.symbol)
                    ?.toLowerCase() ??
                token.name.toLowerCase()):
            token,
    };

    for (final custom in blockchain.customTokensForActiveChain) {
      // Try to find an existing Token object (may have a live balance).
      Token? customToken = tokens
          .where((token) {
            final contract = token.contractAddress?.trim().toLowerCase();
            return contract != null && contract == custom.address.toLowerCase();
          })
          .cast<Token?>()
          .firstWhere((token) => token != null, orElse: () => null);

      // If the token isn't in the live list yet (e.g. $0 balance omitted by
      // the backend, or the wallet was just loaded), synthesise a zero-balance
      // entry so the user-added token always shows in the Tokens tab.
      customToken ??= Token(
        symbol: custom.symbol,
        name: custom.name,
        contractAddress: custom.address,
        balance: 0,
        valueUsd: 0,
        priceUsd: 0,
        changePercent24h: 0,
        decimals: custom.decimals,
        imageUrl: custom.imageUrl,
        coinGeckoId: custom.coinGeckoId,
        isCertified: false,
        networkKey: custom.networkKey ?? blockchain.activeNetworkKey,
        tokenStandard: custom.tokenStandard,
      );

      if (TokenVisibilityUtils.contains(_hiddenTokenKeys, customToken)) {
        continue;
      }
      final key =
          (customToken.contractAddress?.trim().isNotEmpty == true
                  ? customToken.contractAddress
                  : customToken.symbol)
              ?.toLowerCase() ??
          customToken.name.toLowerCase();
      byKey.putIfAbsent(key, () => customToken!);
    }

    final nextTokens = byKey.values.toList()
      ..sort(
        (left, right) =>
            right.totalValueUsdDecimal.compareTo(left.totalValueUsdDecimal),
      );
    return nextTokens;
  }

  int _activePortfolioChainId(BlockchainService blockchain) {
    return blockchain.activeTokenStorageChainId;
  }

  EvmChain _activePortfolioChain(BlockchainService blockchain) {
    return EvmChain(
      name: blockchain.activeNetworkName,
      symbol: blockchain.activeNetworkSymbol,
      chainId: _activePortfolioChainId(blockchain),
      rpcUrl: '',
      coinGeckoId: blockchain.activeNetworkCoinGeckoId,
      explorerUrl: blockchain.activeNetworkExplorerUrl,
      logoUrl: blockchain.activeNetworkLogoUrl,
      family: blockchain.activeFamily,
    );
  }

  EvmChain _portfolioChainForId(BlockchainService blockchain, int chainId) {
    if (chainId == _activePortfolioChainId(blockchain)) {
      return _activePortfolioChain(blockchain);
    }
    if (chainId == BitcoinLegacyUiIds.mainnet ||
        chainId == BitcoinLegacyUiIds.testnet4) {
      final testnet = chainId == BitcoinLegacyUiIds.testnet4;
      return EvmChain(
        name: testnet ? 'Bitcoin Testnet4' : 'Bitcoin',
        symbol: 'BTC',
        chainId: chainId,
        rpcUrl: '',
        coinGeckoId: testnet ? null : 'bitcoin',
        family: ChainFamily.bitcoin,
      );
    }
    if (chainId == -501) {
      return const EvmChain(
        name: 'Solana',
        symbol: 'SOL',
        chainId: -501,
        rpcUrl: '',
        coinGeckoId: 'solana',
        logoUrl: 'https://cryptologos.cc/logos/solana-sol-logo.png',
        family: ChainFamily.solana,
      );
    }
    if (chainId == -195) {
      return const EvmChain(
        name: 'Tron',
        symbol: 'TRX',
        chainId: -195,
        rpcUrl: '',
        coinGeckoId: 'tron',
        logoUrl: 'https://cryptologos.cc/logos/tron-trx-logo.png',
        family: ChainFamily.tron,
      );
    }
    return blockchain.allChains.firstWhere(
      (candidate) => candidate.chainId == chainId,
      orElse: () => blockchain.activeChain,
    );
  }

  Future<HomePortfolioData> _buildPortfolioDataFromSections(
    List<HomePortfolioSection> sections,
  ) {
    return _portfolioRepository.filterSections(
      sections: sections,
      loadHiddenTokens: _tokenVisibilityService.loadHiddenTokens,
      loadUserAddedAddresses: (chainId) => {
        for (final token
            in _blockchain?.customTokensForChain(chainId) ?? const [])
          token.address.trim().toLowerCase(),
      },
    );
  }

  void _hydrateActiveTokensFromPortfolio({required bool isUsingCachedData}) {
    final currentChainId = _lastChainId;
    if (currentChainId == null) {
      return;
    }

    HomePortfolioSection? section;
    for (final candidate in _portfolioSections) {
      if (candidate.chain.chainId == currentChainId) {
        section = candidate;
        break;
      }
    }
    if (section == null) {
      return;
    }

    if (_tokens.isNotEmpty && !_isUsingCachedData && !isUsingCachedData) {
      return;
    }

    _replaceDisplayedTokens(
      section.tokens,
      isUsingCachedData: isUsingCachedData,
    );
  }

  Future<void> _applyPortfolioSnapshotState(
    HomeAggregatedPortfolioSnapshot snapshot, {
    required bool isUsingCachedData,
  }) async {
    // Aggregate portfolio state is optional and must stay completely dormant
    // when either the backend feature or its UI has been disabled at runtime.
    // This second-line guard also rejects a request that completed after an
    // administrator turned the feature off.
    if (!_portfolioRuntimeEnabled) return;
    _portfolioRawSections = List<HomePortfolioSection>.from(snapshot.sections);
    final data = await _buildPortfolioDataFromSections(_portfolioRawSections);
    if (!mounted) {
      return;
    }

    setState(() {
      _applyPortfolioData(
        data.sections.isNotEmpty ? data : _fallbackPortfolioData(),
      );
      _portfolioUpdatedAt = snapshot.timestamp;
      _hydrateActiveTokensFromPortfolio(
        isUsingCachedData: isUsingCachedData || snapshot.isStale,
      );
    });
  }

  HomePortfolioData _fallbackPortfolioData() {
    if (_tokens.isEmpty || _lastChainId == null || _blockchain == null) {
      return HomePortfolioData.empty();
    }

    final chain = _portfolioChainForId(_blockchain!, _lastChainId!);
    final visibleTokens = _displayableTokens(_tokens);
    if (visibleTokens.isEmpty) {
      return HomePortfolioData.empty();
    }

    return HomePortfolioData.fromSections([
      HomePortfolioSection(chain: chain, tokens: visibleTokens),
    ]);
  }

  Future<void> _fetchPortfolioData(
    String walletAddress, {
    bool sync = false,
  }) async {
    if (!mounted || walletAddress.isEmpty || !_portfolioRuntimeEnabled) {
      return;
    }
    final requestNetworkKey = _blockchain?.activeNetworkKey;
    if (requestNetworkKey == null) return;
    final requestFamily = NetworkKey.familyOf(requestNetworkKey);

    setState(() => _isLoadingPortfolio = true);

    if (requestFamily != ChainFamily.evm) {
      try {
        final fallbackSnapshot = await _buildPortfolioFallbackSnapshot(
          walletAddress,
        );
        if (!await _isStillActiveWalletRequest(
          walletAddress,
          requestNetworkKey,
        )) {
          return;
        }
        if (!mounted) {
          return;
        }
        if (fallbackSnapshot != null) {
          await _applyPortfolioSnapshotState(
            fallbackSnapshot,
            isUsingCachedData: false,
          );
          await _portfolioSnapshotService.saveSnapshot(fallbackSnapshot);
        } else {
          setState(() {
            _applyPortfolioData(_fallbackPortfolioData());
          });
        }
      } catch (error) {
        debugPrint('Error building $requestNetworkKey portfolio data: $error');
      } finally {
        if (mounted &&
            await _isStillActiveWalletRequest(
              walletAddress,
              requestNetworkKey,
            )) {
          setState(() => _isLoadingPortfolio = false);
        }
      }
      return;
    }

    try {
      final snapshot = _mergePortfolioSnapshotWithLiveChain(
        await _portfolioApiService
            .fetchPortfolio(walletAddress, sync: sync)
            .timeout(const Duration(seconds: 45)),
      );
      if (!await _isStillActiveWalletRequest(
        walletAddress,
        requestNetworkKey,
      )) {
        return;
      }
      if (!mounted) {
        return;
      }

      await _applyPortfolioSnapshotState(
        snapshot,
        isUsingCachedData: snapshot.isStale,
      );
      if (mounted) {
        setState(() => _isLoadingPortfolio = false);
      }
      await _portfolioSnapshotService.saveSnapshot(snapshot);
    } catch (error) {
      debugPrint('Error fetching portfolio data: $error');
      if (!await _isStillActiveWalletRequest(
        walletAddress,
        requestNetworkKey,
      )) {
        return;
      }
      final fallbackSnapshot = await _buildPortfolioFallbackSnapshot(
        walletAddress,
      );
      if (!await _isStillActiveWalletRequest(
        walletAddress,
        requestNetworkKey,
      )) {
        return;
      }
      if (!mounted) {
        return;
      }
      if (fallbackSnapshot != null) {
        await _applyPortfolioSnapshotState(
          fallbackSnapshot,
          isUsingCachedData: false,
        );
        await _portfolioSnapshotService.saveSnapshot(fallbackSnapshot);
      }
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingPortfolio = false);
    }
  }

  HomeAggregatedPortfolioSnapshot _mergePortfolioSnapshotWithLiveChain(
    HomeAggregatedPortfolioSnapshot snapshot,
  ) {
    final blockchain = _blockchain;
    final currentChainId = _lastChainId;
    final latestLiveWallet = _latestLiveBalanceWallet;
    if (blockchain == null ||
        currentChainId == null ||
        latestLiveWallet == null ||
        snapshot.walletAddress.trim().toLowerCase() != latestLiveWallet) {
      return snapshot;
    }

    final chain = _portfolioChainForId(blockchain, currentChainId);
    final mergedSections = snapshot.sections
        .where((section) => section.chain.chainId != currentChainId)
        .toList(growable: true);
    final liveTokens = _displayableTokens(_tokens);
    if (liveTokens.isNotEmpty) {
      mergedSections.add(
        HomePortfolioSection(chain: chain, tokens: liveTokens),
      );
    }
    mergedSections.sort(
      (left, right) => right.totalBalanceUsd.compareTo(left.totalBalanceUsd),
    );

    return snapshot.copyWith(sections: mergedSections);
  }

  Future<void> _upsertLiveChainPortfolioSection(List<Token> chainTokens) async {
    final blockchain = _blockchain;
    final currentChainId = _lastChainId;
    if (!mounted || blockchain == null || currentChainId == null) {
      return;
    }

    final sectionChain = _portfolioChainForId(blockchain, currentChainId);

    final nextSections = List<HomePortfolioSection>.from(_portfolioRawSections);
    final existingIndex = nextSections.indexWhere(
      (section) => section.chain.chainId == currentChainId,
    );
    final visibleTokens = _displayableTokens(chainTokens);

    if (visibleTokens.isEmpty) {
      if (existingIndex >= 0) {
        nextSections.removeAt(existingIndex);
      }
    } else {
      final nextSection = HomePortfolioSection(
        chain: sectionChain,
        tokens: visibleTokens,
      );
      if (existingIndex >= 0) {
        nextSections[existingIndex] = nextSection;
      } else {
        nextSections.add(nextSection);
      }
    }

    final data = await _buildPortfolioDataFromSections(nextSections);
    if (!mounted ||
        _lastChainId != currentChainId ||
        _buildTokenSignature(_tokens) != _buildTokenSignature(chainTokens)) {
      return;
    }

    setState(() {
      _portfolioRawSections = nextSections;
      _applyPortfolioData(
        data.sections.isNotEmpty ? data : _fallbackPortfolioData(),
      );
      _portfolioUpdatedAt = DateTime.now().toUtc();
    });
  }

  Future<HomeAggregatedPortfolioSnapshot?> _buildPortfolioFallbackSnapshot(
    String walletAddress,
  ) async {
    final blockchain =
        _blockchain ?? Provider.of<BlockchainService>(context, listen: false);

    if (blockchain.activeFamily != ChainFamily.evm) {
      try {
        final tokens = await blockchain.fetchWalletTokens(walletAddress);
        final hiddenTokenKeys = await _tokenVisibilityService.loadHiddenTokens(
          _effectiveVisibilityChainId(blockchain),
        );
        final visibleTokens = _portfolioRepository.prepareVisibleTokens(
          tokens,
          hiddenTokenKeys,
          userAddedAddresses: {
            for (final token in blockchain.customTokensForChain(
              _effectiveVisibilityChainId(blockchain),
            ))
              token.address.trim().toLowerCase(),
          },
          chainId: _effectiveVisibilityChainId(blockchain),
        );
        if (visibleTokens.isEmpty) {
          return null;
        }
        return HomeAggregatedPortfolioSnapshot(
          walletAddress: walletAddress,
          sections: [
            HomePortfolioSection(
              chain: _activePortfolioChain(blockchain),
              tokens: visibleTokens,
            ),
          ],
          timestamp: DateTime.now().toUtc(),
          source: 'client-fallback',
          isStale: false,
          partialFailure: false,
          chainsPending: const <int>[],
        );
      } catch (error) {
        debugPrint(
          'Portfolio fallback fetch failed for ${blockchain.activeNetworkKey}: $error',
        );
        return null;
      }
    }

    final rawSections = await Future.wait(
      blockchain.allChains.map((chain) async {
        try {
          final tokens = await blockchain.fetchWalletTokens(
            walletAddress,
            chainId: chain.chainId,
          );
          final hiddenTokenKeys = await _tokenVisibilityService
              .loadHiddenTokens(chain.chainId);
          final visibleTokens = _portfolioRepository.prepareVisibleTokens(
            tokens,
            hiddenTokenKeys,
            userAddedAddresses: {
              for (final token in blockchain.customTokensForChain(
                chain.chainId,
              ))
                token.address.trim().toLowerCase(),
            },
            chainId: chain.chainId,
          );
          if (visibleTokens.isEmpty) {
            return null;
          }
          return HomePortfolioSection(chain: chain, tokens: visibleTokens);
        } catch (error) {
          debugPrint(
            'Portfolio fallback fetch failed for chain ${chain.chainId}: $error',
          );
          return null;
        }
      }),
    );

    final sections = rawSections.whereType<HomePortfolioSection>().toList()
      ..sort(
        (left, right) => right.totalBalanceUsd.compareTo(left.totalBalanceUsd),
      );

    if (sections.isEmpty) {
      return null;
    }

    return HomeAggregatedPortfolioSnapshot(
      walletAddress: walletAddress,
      sections: sections,
      timestamp: DateTime.now().toUtc(),
      source: 'client-fallback',
      isStale: false,
      partialFailure: false,
      chainsPending: const <int>[],
    );
  }

  Future<void> _reloadPortfolioFromCachedTokens() async {
    final blockchain = _blockchain;
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (!mounted ||
        blockchain == null ||
        walletAddress == null ||
        walletAddress.isEmpty) {
      return;
    }
    final requestNetworkKey = blockchain.activeNetworkKey;

    final data = _portfolioRawSections.isNotEmpty
        ? await _buildPortfolioDataFromSections(_portfolioRawSections)
        : await _portfolioRepository.loadPortfolio(
            walletAddress: walletAddress,
            chains: blockchain.allChains,
            fetchTokens: (chainId) async => blockchain.getCachedWalletTokens(
              walletAddress,
              chainId: chainId,
            ),
            loadHiddenTokens: _tokenVisibilityService.loadHiddenTokens,
            loadUserAddedAddresses: (chainId) => {
              for (final token in blockchain.customTokensForChain(chainId))
                token.address.trim().toLowerCase(),
            },
          );

    if (!await _isStillActiveWalletRequest(walletAddress, requestNetworkKey) ||
        !mounted) {
      return;
    }

    setState(() {
      _applyPortfolioData(
        data.sections.isNotEmpty ? data : _fallbackPortfolioData(),
      );
      _hydrateActiveTokensFromPortfolio(isUsingCachedData: _isUsingCachedData);
    });
  }

  Future<void> _applyPortfolioSnapshot(String walletAddress) async {
    if (!_portfolioRuntimeEnabled) return;
    final requestNetworkKey = _blockchain?.activeNetworkKey;
    final snapshot = await _portfolioSnapshotService.loadSnapshot(
      walletAddress,
    );
    if (requestNetworkKey == null ||
        !await _isStillActiveWalletRequest(walletAddress, requestNetworkKey)) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (snapshot != null) {
      await _applyPortfolioSnapshotState(snapshot, isUsingCachedData: true);
      return;
    }

    if (_portfolioSections.isEmpty) {
      setState(() {
        _applyPortfolioData(_fallbackPortfolioData());
        _portfolioUpdatedAt = null;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    var online = false;
    try {
      final response = await http
          .get(Uri.parse(AppEnvironment.connectivityCheckUrl))
          .timeout(const Duration(seconds: 5));
      online = response.statusCode == 200 || response.statusCode == 429;
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() {
          _hasInternet = online;
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
    if (!mounted || !_connectivityRecovery.shouldRefresh(online)) return;
    var balanceRefreshSucceeded = false;
    try {
      await _runtimeConfig.refresh();
      if (!mounted) return;
      await _loadWalletData(forcePortfolioSync: true);
      if (!mounted) return;
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final address = await _networkDataWalletIdentity(blockchain.activeFamily);
      if (!mounted) return;
      balanceRefreshSucceeded =
          address == null ||
          address.isEmpty ||
          await _fetchRealBalances(address, forceRefresh: true);
    } finally {
      _connectivityRecovery.finishRefresh(succeeded: balanceRefreshSucceeded);
    }
  }

  Future<void> _loadWalletData({
    bool forcePortfolioSync = false,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    final loadGeneration = ++_walletLoadGeneration;
    debugPrint('[OWLLET] Starting wallet data load...');
    setState(() => _isLoading = true);

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);

      // Load address + cached snapshot concurrently with blockchain.init()
      // so the UI unblocks as soon as local storage is ready, without
      // waiting for the full init chain.
      final initFuture = blockchain.init().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[OWLLET] CRITICAL: Blockchain init timed out after 10s');
        },
      );

      final addressFuture = _walletService.getCurrentWalletAddress();
      final nameFuture = _storage.getWalletName();
      final activeAccountFuture = _walletService.getActiveWalletAccount();

      // Wait only for the address/name — these are fast local reads.
      final address = await addressFuture;
      final name = await nameFuture;
      final activeAccount = await activeAccountFuture;
      if (!mounted || loadGeneration != _walletLoadGeneration) return;

      // Remember the active wallet so cross-tab switches can be detected,
      // and push the wallet context so the network selector hides families
      // the wallet does not actually support (e.g. EVM-only imports).
      final normalizedAddress = address?.trim().toLowerCase();
      if (normalizedAddress != null &&
          normalizedAddress.isNotEmpty &&
          normalizedAddress != _lastWalletAddress) {
        unawaited(
          AffiliateAttributionService.instance.applyToWallet(normalizedAddress),
        );
      }
      final walletChanged =
          normalizedAddress != null && normalizedAddress != _lastWalletAddress;
      _lastWalletAddress = normalizedAddress;
      blockchain.setActiveWalletContext(
        address: address ?? '',
        supportedFamilies:
            activeAccount?.supportedFamilies ?? const {ChainFamily.evm},
      );
      final l = AppLocalizations.of(context);
      final activeAccountName = activeAccount?.name.trim();
      final displayName =
          activeAccountName != null && activeAccountName.isNotEmpty
          ? activeAccountName
          : name ?? l.mainWallet;
      setState(() {
        _walletName = displayName;
        if (walletChanged) {
          _replaceDisplayedTokens(const [], isUsingCachedData: false);
          _applyPortfolioData(HomePortfolioData.empty());
          _portfolioRawSections = const [];
          _portfolioUpdatedAt = null;
          _latestLiveBalanceWallet = null;
          _nftPreview = const [];
          _hasMoreNfts = false;
          _hasUnreadNotifications = false;
          _isLoadingBalances = false;
          _isLoadingPortfolio = false;
          _isLoadingNfts = false;
        }
      });

      if (address != null && address.isNotEmpty) {
        // Load snapshot immediately — don't wait for blockchain.init().
        // We use the last known chainId if available, otherwise fall through.
        final preChainId = _lastChainId ?? _activePortfolioChainId(blockchain);
        final snapshot = await _snapshotService.loadSnapshot(
          preChainId,
          address,
        );
        final portfolioSnapshotFuture = _portfolioRuntimeEnabled
            ? _applyPortfolioSnapshot(address)
            : Future<void>.value();

        if (snapshot != null &&
            mounted &&
            loadGeneration == _walletLoadGeneration) {
          setState(() {
            _replaceDisplayedTokens(
              snapshot.tokens,
              isUsingCachedData: snapshot.isStale,
            );
            _walletName = displayName;
          });
          blockchain.setLivePriceTrackingForTokens(
            _tokens,
            scope: _livePriceScope,
          );
          debugPrint(
            '[OWLLET] Loaded cached snapshot: ${_tokens.length} tokens',
          );
        }

        await portfolioSnapshotFuture;

        // Unblock the UI now — cached data is shown.
        if (mounted && loadGeneration == _walletLoadGeneration) {
          setState(() {
            _walletName = displayName;
            _isLoading = false;
          });
          debugPrint('[OWLLET] Loading state cleared. UI unblocked (cached).');
        }

        // Now wait for blockchain.init() to finish before the live refresh.
        await initFuture;
        if (!mounted || loadGeneration != _walletLoadGeneration) return;

        _lastChainId = _activePortfolioChainId(blockchain);
        debugPrint('[OWLLET] Active Chain ID: $_lastChainId');
        await _loadHiddenTokens(_effectiveVisibilityChainId(blockchain));
        if (!mounted || loadGeneration != _walletLoadGeneration) return;
        final balanceAddress = await _networkDataWalletIdentity(
          blockchain.activeFamily,
        );
        if (!mounted || loadGeneration != _walletLoadGeneration) return;

        debugPrint('[OWLLET] Triggering background data sync...');
        if (balanceAddress != null && balanceAddress.isNotEmpty) {
          unawaited(
            blockchain.requestActiveBalanceRefresh(
              reason: forceRefresh ? 'manual' : 'entry',
            ),
          );
          unawaited(
            _fetchRealBalances(balanceAddress, forceRefresh: forceRefresh),
          );
        } else if (mounted) {
          setState(() {
            _replaceDisplayedTokens(const [], isUsingCachedData: false);
            _isLoadingBalances = false;
          });
        }
        if (balanceAddress != null && balanceAddress.isNotEmpty) {
          unawaited(
            _fetchPortfolioData(balanceAddress, sync: forcePortfolioSync),
          );
        }
        _scheduleDeferredHomeTasks(balanceAddress ?? address);
        unawaited(_checkWhatsNew());
      } else {
        // No wallet — still need blockchain init to know the chain.
        await initFuture;
        if (mounted && loadGeneration == _walletLoadGeneration) {
          setState(() {
            _walletName = name ?? l.mainWallet;
            _applyPortfolioData(HomePortfolioData.empty());
            _isLoading = false;
          });
        }
        debugPrint('[OWLLET] WARNING: No wallet address found during init');
      }
    } catch (e, stack) {
      debugPrint('[OWLLET] ERROR in _loadWalletData: $e');
      debugPrint('[OWLLET] STACKTRACE: $stack');
      if (mounted && loadGeneration == _walletLoadGeneration) {
        setState(() {
          _isLoading = false;
          if (_portfolioSections.isEmpty) {
            _applyPortfolioData(_fallbackPortfolioData());
          }
        });
      }
    }
  }

  Future<void> _checkWhatsNew() async {
    if (_whatsNewChecked || !mounted) return;
    _whatsNewChecked = true;

    // Small delay so the home screen finishes painting first.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    try {
      final result = await _releaseChecker.checkForWhatsNew();
      if (result == null || !mounted) return;
      await WhatsNewSheet.show(context, result);
    } catch (_) {
      // Never block the user over a non-critical feature.
    }
  }

  void _scheduleDeferredHomeTasks(String address) {
    final generation = ++_deferredLoadGeneration;
    unawaited(_runDeferredHomeTasks(address, generation));
  }

  bool _sameWalletAddress(String? left, String? right) {
    final normalizedLeft = left?.trim().toLowerCase();
    final normalizedRight = right?.trim().toLowerCase();
    return normalizedLeft != null &&
        normalizedLeft.isNotEmpty &&
        normalizedLeft == normalizedRight;
  }

  Future<bool> _isStillActiveWalletRequest(
    String walletAddress,
    String networkKey,
  ) async {
    if (!mounted) return false;
    final blockchain = _blockchain;
    if (blockchain == null || blockchain.activeNetworkKey != networkKey) {
      return false;
    }
    final currentAddress = await _networkDataWalletIdentity(
      blockchain.activeFamily,
    );
    return mounted && _sameWalletAddress(currentAddress, walletAddress);
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
        chainId: blockchain.activeTokenStorageChainId,
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

  Future<bool> _fetchRealBalances(
    String address, {
    bool forceRefresh = false,
  }) async {
    setState(() => _isLoadingBalances = true);

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final requestNetworkKey = blockchain.activeNetworkKey;
      final realTokens = await blockchain
          .fetchWalletTokens(address, forceRefresh: forceRefresh)
          .timeout(const Duration(seconds: 45));

      if (!await _isStillActiveWalletRequest(address, requestNetworkKey)) {
        return false;
      }

      if (mounted) {
        setState(() {
          _replaceDisplayedTokens(realTokens, isUsingCachedData: false);
          _isLoadingBalances = false;
          _balanceLoadFailed = blockchain.lastDiscoveryPartialFailure;
          _latestLiveBalanceWallet = address.toLowerCase();
        });
        blockchain.setLivePriceTrackingForTokens(
          _tokens,
          scope: _livePriceScope,
        );
        _lastChainId = _activePortfolioChainId(blockchain);
        await _upsertLiveChainPortfolioSection(realTokens);

        // Save fresh snapshot
        final name = await _storage.getWalletName();
        if (!await _isStillActiveWalletRequest(address, requestNetworkKey)) {
          return false;
        }
        if (!mounted) return false;
        final l = AppLocalizations.of(context);
        _snapshotService.saveSnapshot(
          HomePortfolioSnapshot(
            walletAddress: address,
            chainId: _lastChainId!,
            walletName: name ?? l.mainWallet,
            totalBalance: ValueFormatter.doubleFromDecimal(
              _portfolioMetrics.totalBalanceUsd,
            ),
            tokens: _tokens,
            timestamp: DateTime.now(),
          ),
        );

        if (_portfolioRawSections.isEmpty) {
          unawaited(_reloadPortfolioFromCachedTokens());
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error fetching balances: $e');
      final blockchain = _blockchain;
      final requestNetworkKey = blockchain?.activeNetworkKey;
      if (requestNetworkKey == null ||
          !await _isStillActiveWalletRequest(address, requestNetworkKey)) {
        return false;
      }
      if (mounted) {
        setState(() {
          _isLoadingBalances = false;
          _balanceLoadFailed = true;
        });
      }
      return false;
    }
  }

  void _handleBlockchainChange() {
    if (!mounted) return;
    final blockchain = _blockchain;
    final chainId = blockchain == null
        ? null
        : _activePortfolioChainId(blockchain);
    if (blockchain == null || chainId == null) return;

    final currentNetworkKey = blockchain.activeNetworkKey;
    final networkKeyChanged = currentNetworkKey != _lastNetworkKey;
    final chainIdChanged = chainId != _lastChainId;

    // Detect a wallet switch performed from another tab in the IndexedStack
    // shell (e.g. from settings → wallets). When the active wallet address
    // changes, the home screen needs to reload the wallet name, snapshot,
    // and balances — not just the token list.
    final currentWallet = blockchain.activeWalletAddress.trim().toLowerCase();
    final walletChanged =
        currentWallet.isNotEmpty && currentWallet != (_lastWalletAddress ?? '');
    if (walletChanged) {
      unawaited(_loadWalletData(forcePortfolioSync: true));
      return;
    }

    // Same network — just refresh token list if the signature changed.
    if (!networkKeyChanged && !chainIdChanged) {
      final nextTokens = blockchain.tokens;
      final nextSignature = _buildTokenSignature(nextTokens);
      if (nextSignature == _lastTokenSignature) {
        return;
      }
      setState(() {
        _replaceDisplayedTokens(nextTokens, isUsingCachedData: false);
      });
      blockchain.setLivePriceTrackingForTokens(_tokens, scope: _livePriceScope);
      if (_portfolioRawSections.isEmpty) {
        unawaited(_reloadPortfolioFromCachedTokens());
      } else {
        unawaited(_upsertLiveChainPortfolioSection(nextTokens));
      }
      return;
    }

    _lastChainId = chainId;
    _lastNetworkKey = currentNetworkKey;
    _loadHiddenTokens(_effectiveVisibilityChainId(blockchain));
    _networkDataWalletIdentity(blockchain.activeFamily).then((address) async {
      if (!mounted) return;
      if (address == null || address.isEmpty) {
        setState(() {
          _replaceDisplayedTokens(const [], isUsingCachedData: false);
          _applyPortfolioData(_fallbackPortfolioData());
        });
        return;
      }

      // For EVM chains, try to load a cached snapshot instantly.
      // For non-EVM, clear the list so stale EVM tokens don't show.
      if (blockchain.activeFamily == ChainFamily.evm) {
        final snapshot = await _snapshotService.loadSnapshot(chainId, address);
        if (snapshot != null && mounted) {
          setState(() {
            _replaceDisplayedTokens(
              snapshot.tokens,
              isUsingCachedData: snapshot.isStale,
            );
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
      } else if (mounted) {
        setState(() {
          _replaceDisplayedTokens(const [], isUsingCachedData: false);
        });
      }

      await _applyPortfolioSnapshot(address);
      _fetchRealBalances(address);
      unawaited(_fetchPortfolioData(address, sync: true));
      _scheduleDeferredHomeTasks(address);
    });
  }

  /// Returns the chain-ID key used by [TokenVisibilityService] for the
  /// currently active network. Mirrors the sentinel logic in token management:
  /// EVM uses the real chainId; Solana = -501; Tron = -195.
  int _effectiveVisibilityChainId(BlockchainService blockchain) {
    switch (blockchain.activeFamily) {
      case ChainFamily.bitcoin:
        return blockchain.activeTokenStorageChainId;
      case ChainFamily.solana:
        return -501;
      case ChainFamily.tron:
        return -195;
      case ChainFamily.evm:
        return blockchain.activeChain.chainId;
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
    return TokenVisibilityUtils.contains(_hiddenTokenKeys, token);
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
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final solanaAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.solana,
    );
    final evmAddress = RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address.trim())
        ? address.trim()
        : '';
    if (evmAddress.isEmpty &&
        (solanaAddress == null || solanaAddress.isEmpty)) {
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
      final activeChain = blockchain.activeChain;
      final orderedChains = [
        activeChain,
        ...blockchain.allChains.where(
          (chain) => chain.chainId != activeChain.chainId,
        ),
      ];
      final nfts = await _nftService.fetchOwnedNftsAcrossChains(
        chains: orderedChains,
        walletAddress: evmAddress,
        solanaWalletAddress: solanaAddress ?? '',
      );
      if (!mounted) return;
      setState(() {
        _nftPreview = nfts;
        _hasMoreNfts = nfts.isNotEmpty;
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
    final metrics = _selectedAssetTab == HomeAssetTab.tokens
        ? HomePortfolioMetricsCalculator.fromTokens(_displayableTokens(_tokens))
        : _portfolioMetrics;
    return ValueFormatter.formatCurrencyWithGrouping(metrics.totalBalanceUsd);
  }

  String _balanceTitleText(AppLocalizations l) {
    return _selectedAssetTab == HomeAssetTab.portfolio
        ? l.totalNetWorth
        : l.availableBalance;
  }

  String? _tokenFreshnessCaption(AppLocalizations l) {
    if (_hasInternet == false) return l.noInternetConnection;
    if (_isLoadingBalances) return l.balanceSyncingStatus;
    final blockchain = _blockchain;
    if (blockchain != null && blockchain.lastDiscoveryPartialFailure) {
      return l.balanceSyncingStatus;
    }
    if (_isUsingCachedData) return _balanceStatusText(l);
    return null;
  }

  String? _balanceStatusText(AppLocalizations l) {
    if (_isLoadingPortfolio || _isLoadingBalances) {
      return l.balanceSyncingStatus;
    }
    final updatedAt = _portfolioUpdatedAt;
    if (updatedAt == null) {
      return null;
    }
    // `_portfolioUpdatedAt` is stored in UTC; convert to the device's local
    // zone so the displayed time matches the user's clock (TimeOfDay reads the
    // DateTime's hour/minute fields verbatim, so the conversion must happen
    // before extracting it).
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt.toLocal()));
    return l.balanceUpdatedAt(time);
  }

  Future<void> _openHomeBanner(HomeBannerItem banner) async {
    await InAppLinkRouter.open(
      context,
      banner.linkUrl,
      miniAppLaunchSource: 'home_banner',
    );
  }

  Future<void> _loadHomeBanners() async {
    if (!mounted) {
      return;
    }

    final cachedSnapshot = await _homeBannerSnapshotService.loadSnapshot();
    if (!mounted) {
      return;
    }

    final cachedFeed = cachedSnapshot?.feed;
    if (cachedFeed != null) {
      setState(() {
        _homeBanners = cachedFeed.banners.take(4).toList(growable: false);
        _showFallbackSocialBanner = cachedFeed.showFallbackSocialBanner;
        _homeBannerIndex = 0;
        _isLoadingHomeBanners = false;
      });
      _configureHomeBannerRotation();
    } else {
      setState(() => _isLoadingHomeBanners = true);
    }

    try {
      final feed = await _homeBannerService.fetchHomeBanners();
      if (!mounted) {
        return;
      }
      setState(() {
        _homeBanners = feed.banners.take(4).toList(growable: false);
        _showFallbackSocialBanner = feed.showFallbackSocialBanner;
        _homeBannerIndex = 0;
        _isLoadingHomeBanners = false;
      });
      await _homeBannerSnapshotService.saveSnapshot(feed);
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (cachedFeed == null) {
        setState(() {
          _homeBanners = const [];
          _showFallbackSocialBanner = true;
          _homeBannerIndex = 0;
          _isLoadingHomeBanners = false;
        });
      } else {
        setState(() => _isLoadingHomeBanners = false);
      }
    }
    _configureHomeBannerRotation();
  }

  void _configureHomeBannerRotation() {
    _homeBannerRotationTimer?.cancel();
    if (_homeBanners.length < 2) {
      return;
    }

    _homeBannerRotationTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_homeBannerPageController.hasClients) {
        return;
      }
      final nextIndex = (_homeBannerIndex + 1) % _homeBanners.length;
      _homeBannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _startHomeShowcaseIfNeeded() async {
    if (_homeShowcaseScheduled || !widget.showBottomNavigation || !mounted) {
      return;
    }
    _homeShowcaseScheduled = true;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenShowcase = prefs.getBool(_homeShowcaseSeenKey) ?? false;
    if (hasSeenShowcase || !mounted) {
      return;
    }
    await prefs.setBool(_homeShowcaseSeenKey, true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final showcaseKeys = <GlobalKey>[
        _walletSwitcherShowcaseKey,
        _balanceShowcaseKey,
        _quickActionsShowcaseKey,
        _assetTabsShowcaseKey,
      ];
      if (_shouldShowHomePromoSection) {
        showcaseKeys.insert(3, _promoCarouselShowcaseKey);
      }
      ShowcaseView.get().startShowCase(showcaseKeys);
    });
  }

  bool get _shouldShowHomePromoSection =>
      _isLoadingHomeBanners ||
      _homeBanners.isNotEmpty ||
      _showFallbackSocialBanner;

  Future<void> _openFallbackSocialBanner() async {
    await InAppLinkRouter.open(context, 'https://t.me/FOMOWL');
  }

  Future<void> _openOwlletPayDeposit() async {
    if (context.read<BlockchainService>().activeFamily == ChainFamily.bitcoin) {
      ToastUtils.showInfo('Bitcoin payments are not available yet.');
      return;
    }
    final base = OwlletMiniApps.owlletPay.configuredLaunchUri;
    final depositUrl = base?.replace(path: '/deposit').toString();
    await Navigator.pushNamed(
      context,
      '/owllet-pay',
      arguments: MiniAppHostArguments(
        miniAppId: 'owllet_pay',
        launchSource: 'home_deposit',
        initialUrl: depositUrl,
      ),
    );
    if (!mounted) return;
    final blockchain = context.read<BlockchainService>();
    final wallet = blockchain.activeWalletAddress.trim();
    if (wallet.isNotEmpty) {
      await blockchain.requestTransactionBalanceRefresh(
        walletAddress: wallet,
        networkKey: blockchain.activeNetworkKey,
        family: 'transfer',
        operationReference:
            'owllet-pay-deposit-return-${DateTime.now().microsecondsSinceEpoch}',
      );
    }
    if (mounted) {
      await _refreshBalancesAfterMiniApp();
    }
  }

  /// Open OwlletPay straight on its withdraw (off-ramp) page. The
  /// hosted app's own middleware redirects unauthenticated users to its login
  /// screen and returns them to `/withdraw` after signing in, so we only need to
  /// point the host at the withdraw URL here. Falls back to the mini app's base
  /// launch URL when the deep link can't be built.
  void _openCashInWithdraw() {
    final base = OwlletMiniApps.owlletPay.configuredLaunchUri;
    final withdrawUrl = base?.replace(path: '/withdraw').toString();
    Navigator.pushNamed(
      context,
      '/owllet-pay',
      arguments: MiniAppHostArguments(
        miniAppId: 'owllet_pay',
        launchSource: 'home_withdraw',
        initialUrl: withdrawUrl,
      ),
    );
  }

  void _openSettingsScreen() {
    Navigator.pushNamed(context, '/profile');
  }

  Future<void> _openTokenManager() async {
    final hasChanges = await Navigator.pushNamed(context, '/token-management');
    if (hasChanges == true && mounted) {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      setState(() {
        _replaceDisplayedTokens(blockchain.tokens, isUsingCachedData: false);
      });
      blockchain.setLivePriceTrackingForTokens(_tokens, scope: _livePriceScope);

      final address = await _networkDataWalletIdentity(blockchain.activeFamily);
      if (address != null && address.isNotEmpty) {
        unawaited(_fetchRealBalances(address));
        unawaited(_fetchPortfolioData(address, sync: true));
      }
    }
  }

  void _showNetworkSelector() {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => NetworkSelectorSheet(
        entries: blockchain.networkEntries,
        activeNetworkKey: blockchain.activeNetworkKey,
        onSelect: (entry) {
          blockchain.setActiveNetworkKey(entry.networkKey);
          Navigator.pop(ctx);
        },
        onAddCustomNetwork: blockchain.enabledFamilies.contains(ChainFamily.evm)
            ? () async {
                Navigator.pop(ctx);
                await Navigator.pushNamed(context, '/add-network');
              }
            : null,
        onEditCustom: (chain) async {
          Navigator.pop(ctx);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddNetworkScreen(existing: chain),
            ),
          );
        },
        onDeleteCustom: (chain) async {
          Navigator.pop(ctx);
          await _confirmDeleteCustomNetwork(blockchain, chain);
        },
      ),
    );
  }

  Future<void> _confirmDeleteCustomNetwork(
    BlockchainService blockchain,
    EvmChain chain,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          'Remove ${chain.name}?',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'This removes the custom network from this device.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Remove',
              style: GoogleFonts.outfit(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await blockchain.removeCustomChain(chain.chainId);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.select<CurrencyController, String>((c) => c.currencyCode);
    final l = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context);
    if (!_isLoading) {
      unawaited(_startHomeShowcaseIfNeeded());
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentRed),
            )
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Showcase(
                    key: _walletSwitcherShowcaseKey,
                    title: 'Wallet and support',
                    description:
                        'Switch wallets, open settings, and reach notifications from here.',
                    child: HomeTopBar(
                      walletName: _walletName ?? l.mainWallet,
                      onWalletTap: () async {
                        await Navigator.pushNamed(context, '/wallets');
                        await _loadWalletData();
                      },
                      chainSymbol: blockchain.activeNetworkDisplaySymbol,
                      chainId: blockchain.activeFamily == ChainFamily.evm
                          ? blockchain.activeChain.chainId
                          : null,
                      chainLogoUrl: blockchain.activeNetworkLogoUrl,
                      onNetworkTap: _showNetworkSelector,
                      onSettingsTap: _openSettingsScreen,
                      showNotificationDot: _hasUnreadNotifications,
                      onNotificationsTap: () async {
                        await Navigator.pushNamed(context, '/notifications');
                        await _refreshNotificationDot();
                      },
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.accentRed,
                      onRefresh: () async {
                        await Future.wait<void>([
                          _loadWalletData(
                            forcePortfolioSync: true,
                            forceRefresh: true,
                          ),
                          _loadHomeBanners(),
                        ]);
                      },
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
                            const SizedBox(height: 24),
                            Showcase(
                              key: _balanceShowcaseKey,
                              title: 'Portfolio status',
                              description:
                                  'Use this card to track live value, hide balances, and jump into transaction history.',
                              child: BalanceCard(
                                titleText: _balanceTitleText(l),
                                formattedBalance: _formattedTotalBalance,
                                portfolioMetrics:
                                    HomePortfolioMetricsCalculator.fromTokens(
                                      _displayableTokens(_tokens),
                                    ),
                                statusText: _balanceStatusText(l),
                                isBalanceVisible: _balanceVisible,
                                isLoadingBalances:
                                    _isLoadingBalances || _isLoadingPortfolio,
                                onToggleVisibility: () => setState(
                                  () => _balanceVisible = !_balanceVisible,
                                ),
                                onHistoryTap: () => Navigator.pushNamed(
                                  context,
                                  '/transactions',
                                ),
                                onAddFunds: _openOwlletPayDeposit,
                              ),
                            ),

                            const SizedBox(height: 24),
                            Showcase(
                              key: _quickActionsShowcaseKey,
                              title: 'Core wallet actions',
                              description:
                                  'Receive, send, and withdraw stay visible on the home screen for the main wallet flow.',
                              child: QuickActionsRow(
                                onReceive: () => Navigator.pushNamed(
                                  context,
                                  '/receive-token',
                                ),
                                onSend: () =>
                                    Navigator.pushNamed(context, '/send-token'),
                                onWithdraw: _openCashInWithdraw,
                              ),
                            ),
                            const SizedBox(height: 26),
                            if (_shouldShowHomePromoSection) ...[
                              Showcase(
                                key: _promoCarouselShowcaseKey,
                                title: 'Spotlight',
                                description:
                                    'Quick updates, featured campaigns, and Owllet announcements appear here.',
                                child: HomePromoCarousel(
                                  banners: _homeBanners,
                                  showFallbackSocialBanner:
                                      _showFallbackSocialBanner,
                                  activeIndex: _homeBannerIndex,
                                  pageController: _homeBannerPageController,
                                  isLoading: _isLoadingHomeBanners,
                                  onPageChanged: (index) {
                                    if (!mounted) {
                                      return;
                                    }
                                    setState(() => _homeBannerIndex = index);
                                  },
                                  onTapBanner: (banner) {
                                    unawaited(_openHomeBanner(banner));
                                  },
                                  onTapFallbackSocialBanner:
                                      _openFallbackSocialBanner,
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],
                            Showcase(
                              key: _assetTabsShowcaseKey,
                              title: 'Asset views',
                              description:
                                  'Move between Tokens, Portfolio, and NFTs without leaving the dashboard.',
                              child: TokensSection(
                                tokens: _displayableTokens(_tokens),
                                portfolioSections: _portfolioSections,
                                freshnessCaption: _tokenFreshnessCaption(l),
                                balancesUnavailable:
                                    _tokens.isEmpty &&
                                    (_hasInternet == false ||
                                        _balanceLoadFailed ||
                                        blockchain.lastDiscoveryPartialFailure),
                                confirmedZero:
                                    _hasInternet == true &&
                                    !_isLoadingBalances &&
                                    _tokens.isEmpty &&
                                    !_balanceLoadFailed &&
                                    !blockchain.lastDiscoveryPartialFailure,
                                isLoading:
                                    _isLoadingBalances && !_isUsingCachedData,
                                isLoadingPortfolio: _isLoadingPortfolio,
                                isLoadingNfts: _isLoadingNfts,
                                nftPreview: _nftPreview,
                                hasMoreNfts: _hasMoreNfts,
                                localization: l,
                                initialTab: _selectedAssetTab,
                                portfolioEnabled:
                                    _runtimeConfig.snapshot.portfolioUiEnabled,
                                onScan: () =>
                                    Navigator.pushNamed(context, '/qr-scanner'),
                                onManageTokens: _openTokenManager,
                                onOpenNfts: () {
                                  if (_hasMoreNfts) {
                                    Navigator.pushNamed(
                                      context,
                                      '/nft-gallery',
                                    );
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
                                onTabChanged: (tab) {
                                  if (!mounted || _selectedAssetTab == tab) {
                                    return;
                                  }
                                  setState(() => _selectedAssetTab = tab);
                                },
                                onSelectToken: (token) {
                                  Navigator.pushNamed(
                                    context,
                                    '/token-detail',
                                    arguments: token,
                                  );
                                },
                                onSelectNftCollection: (collection) {
                                  Navigator.pushNamed(
                                    context,
                                    '/nft-gallery',
                                    arguments: collection.key,
                                  );
                                },
                              ),
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
      bottomNavigationBar: widget.showBottomNavigation
          ? const BottomNavBar(currentTab: AppShellTab.wallet)
          : null,
    );
  }
}
