import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../features/mini_apps/mini_app_definition.dart';
import '../../features/mini_apps/mini_app_host_screen.dart';
import '../../features/mini_apps/mini_app_registry.dart';
import '../../features/shell/app_shell_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/profile/feedback_screen.dart';
import '../../services/deep_link_service.dart';

import '../../services/wallet_service.dart';
import '../../services/walletconnect/wallet_connect_service.dart';
import 'browser/browser_session_controller.dart';
import 'browser/discover_tab_manager.dart';
import 'discover_url_utils.dart';
import 'browser/widgets/discover_blocked_view.dart';
import 'browser/widgets/discover_browser_view.dart';
import 'browser/widgets/discover_tab_overview.dart';
import 'catalog/discover_dapp_entry.dart';
import 'catalog/discover_product_entry.dart';
import 'catalog/discover_catalog_service.dart';
import 'catalog/widgets/discover_landing_view.dart';
import 'permissions/dapp_permission_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final DiscoverCatalogService _catalogService;
  late final DiscoverTabManager _tabManager;
  late final DappPermissionService _permissionService;
  final WalletService _walletService = WalletService();
  AppShellController? _shellController;
  final TextEditingController _searchController = TextEditingController();
  bool _showTabOverview = false;

  BrowserSessionController get _sessionController =>
      _tabManager.activeTab.sessionController;

  @override
  void initState() {
    super.initState();
    _catalogService = DiscoverCatalogService();
    _permissionService = DappPermissionService();
    _tabManager = DiscoverTabManager(
      catalogService: _catalogService,
      permissionService: _permissionService,
    );
    _tabManager.addListener(_syncSearchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDiscover();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Let the shell route the hardware back button into the in-app browser
    // (page history / close page) before leaving the Discover tab.
    _shellController ??= context.read<AppShellController>();
    _shellController!.setDiscoverBackHandler(_handleDiscoverBack);
  }

  @override
  void dispose() {
    _shellController?.setDiscoverBackHandler(null);
    _shellController?.setBottomNavVisible(true);
    _tabManager.removeListener(_syncSearchField);
    _tabManager.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _syncNavbarVisibility() {
    final isBrowser = _sessionController.viewState == DiscoverViewState.browser;
    _shellController?.setBottomNavVisible(!isBrowser);
  }

  void _syncSearchField() {
    _syncNavbarVisibility();
    if (_searchController.text == _sessionController.query) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: _sessionController.query,
      selection: TextSelection.collapsed(
        offset: _sessionController.query.length,
      ),
    );
  }

  Future<bool> _handleDiscoverBack() async {
    if (_showTabOverview) {
      setState(() => _showTabOverview = false);
      return true;
    }
    return _tabManager.handleBackRequest();
  }

  Future<void> _initializeDiscover() async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    await _tabManager.initialize(scopeKey: walletAddress);
    if (!mounted) return;
    final pending = context
        .read<AppShellController>()
        .consumePendingDiscoverUrl();
    if (pending != null && pending.trim().isNotEmpty) {
      _handleBrowserInput(pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingDiscoverUrl = context.select<AppShellController, String?>(
      (controller) => controller.pendingDiscoverUrl,
    );
    if (_tabManager.initialized &&
        pendingDiscoverUrl != null &&
        pendingDiscoverUrl.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final nextUrl = context
            .read<AppShellController>()
            .consumePendingDiscoverUrl();
        if (nextUrl == null || nextUrl.trim().isEmpty) {
          return;
        }
        _handleBrowserInput(nextUrl);
      });
    }
    return AnimatedBuilder(
      animation: _tabManager,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              SafeArea(
                child: IndexedStack(
                  index: _tabManager.activeIndex,
                  children: _tabManager.tabs
                      .map(
                        (tab) => KeyedSubtree(
                          key: ValueKey<String>('discover-tab-${tab.id}'),
                          child: _buildTab(tab),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              if (_showTabOverview)
                Positioned.fill(
                  child: DiscoverTabOverview(
                    manager: _tabManager,
                    onDone: () => setState(() => _showTabOverview = false),
                    onLimitReached: _showTabLimitMessage,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(DiscoverBrowserTab tab) {
    final session = tab.sessionController;
    final isActive = tab.id == _tabManager.activeTabId;
    if (!isActive && session.viewState != DiscoverViewState.browser) {
      return const SizedBox.shrink();
    }
    final isBrowser = session.viewState == DiscoverViewState.browser;
    return isBrowser
        ? _buildBody(tab)
        : Column(
            children: [
              _buildLandingHeader(),
              Expanded(child: _buildBody(tab)),
            ],
          );
  }

  Widget _buildLandingHeader() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  l.discoverBrowserFallbackTitle,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _buildTabCountButton(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('discover-search-field'),
            controller: _searchController,
            onChanged: (value) {
              _sessionController.updateQuery(value);
              if (value.trim().startsWith('wc:')) {
                _handleBrowserInput(value);
              }
            },
            onSubmitted: _handleBrowserInput,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: l.discoverSearchHint,
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFFA0A0A0),
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFA0A0A0),
                size: 18,
              ),
              suffixIcon: _sessionController.query.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _sessionController.updateQuery(''),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.accentRed,
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabCountButton() {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).discoverTabsTitle,
      child: InkWell(
        onTap: () => setState(() => _showTabOverview = true),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x80A0A0A0), width: 1),
          ),
          child: Text(
            '${_tabManager.tabCount}',
            style: GoogleFonts.inter(
              color: const Color(0xFFEA2A33),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DiscoverBrowserTab tab) {
    final session = tab.sessionController;
    switch (session.viewState) {
      case DiscoverViewState.browser:
        return DiscoverBrowserView(
          sessionController: session,
          providerBridge: tab.providerBridge,
          onClose: session.returnToLanding,
          tabCount: _tabManager.tabCount,
          onShowTabs: () => setState(() => _showTabOverview = true),
        );
      case DiscoverViewState.blocked:
        final state = session.blockedState;
        if (state == null) {
          return const SizedBox.shrink();
        }
        return DiscoverBlockedView(
          state: state,
          onRequestSupport: () => _openRequestSupport(state),
          onOpenExternal: () => _openExternal(state.url),
          onCancel: session.returnToLanding,
        );
      case DiscoverViewState.landing:
        final l = AppLocalizations.of(context);
        final dapps = session.snapshot?.dapps ?? const <DiscoverDappEntry>[];
        final products = DiscoverProductEntry.merge(
          miniApps: OwlletMiniApps.all,
          catalogDapps: dapps,
        );
        return DiscoverLandingView(
          query: session.query,
          products: products,
          dapps: dapps,
          filteredDapps: session.filteredDapps,
          categories: DiscoverProductEntry.orderedCategories(dapps),
          loading: session.loadingCatalog,
          error: session.catalogError == null
              ? null
              : l.discoverCatalogLoadError,
          onRefresh: () => session.loadCatalog(forceRefresh: true),
          onOpenProduct: (product) => _openProduct(session, product),
          onOpenDapp: (dapp) => _openDapp(session, dapp),
          onOpenOwlletPay: () => _openMiniApp(
            OwlletMiniApps.owlletPay,
            launchSource: 'discover_banner',
          ),
        );
    }
  }

  void _openProduct(
    BrowserSessionController session,
    DiscoverProductEntry product,
  ) {
    final miniApp = product.miniApp;
    if (miniApp != null) {
      _openMiniApp(miniApp, launchSource: 'discover_products');
      return;
    }
    _openDapp(session, product.dapp!);
  }

  void _openDapp(BrowserSessionController session, DiscoverDappEntry dapp) {
    final miniApp = DiscoverProductEntry.trustedMiniAppForDapp(
      dapp,
      OwlletMiniApps.all,
    );
    if (miniApp != null) {
      _openMiniApp(
        miniApp,
        launchSource: 'discover_catalog',
        initialUrl: dapp.launchUrl,
      );
      return;
    }
    session.openDapp(
      dapp,
      invalidLaunchUrlReason: AppLocalizations.of(
        context,
      ).discoverInvalidLaunchUrl,
    );
  }

  void _openMiniApp(
    MiniAppDefinition miniApp, {
    required String launchSource,
    String? initialUrl,
  }) {
    Navigator.of(context).pushNamed(
      '/mini-app-host',
      arguments: MiniAppHostArguments(
        miniAppId: miniApp.id,
        launchSource: launchSource,
        initialUrl: initialUrl,
      ),
    );
  }

  void _showTabLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).discoverMaxTabsReached),
      ),
    );
  }

  /// Routes browser input. When the entered/opened URL belongs to a registered
  /// Owllet mini app (e.g. the affiliate or cash-in app), it is opened in the
  /// mini-app host — which injects the OwlletMiniApp bridge + wallet session —
  /// instead of the plain provider-only browser. Everything else falls through
  /// to normal browsing/search. This is what lets a mini-app link load its full
  /// context just by being entered in the address bar, with no Discover tile.
  void _handleBrowserInput(String value) {
    final l = AppLocalizations.of(context);
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    // 1. Check if user pasted a WalletConnect URI / link
    final wcPairingUri = DeepLinkService.extractWalletConnectPairingUri(
      trimmed,
    );
    if (wcPairingUri != null && wcPairingUri.isNotEmpty) {
      _searchController.clear();
      _sessionController.updateQuery('');
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting to DApp via WalletConnect...'),
          duration: Duration(seconds: 2),
        ),
      );
      WalletConnectService.instance.pair(wcPairingUri);
      return;
    }

    // 2. Check if mini-app
    final target = resolveDiscoverInput(trimmed);
    if (target != null && target.type == DiscoverInputType.url) {
      final miniApp = OwlletMiniApps.findByUri(target.uri);
      if (miniApp != null) {
        Navigator.of(context).pushNamed(
          '/mini-app-host',
          arguments: MiniAppHostArguments(
            miniAppId: miniApp.id,
            launchSource: 'browser',
            initialUrl: target.uri.toString(),
          ),
        );
        return;
      }
    }

    _sessionController.openManualInput(
      trimmed,
      invalidInputReason: l.discoverManualInputInvalid,
      webSearchTitle: l.discoverWebSearchTitle,
    );
  }

  Future<void> _openExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  Future<void> _openRequestSupport(dynamic state) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeedbackScreen(
          initialCategory: 'dapp_request',
          initialSubject: AppLocalizations.of(context).discoverSupportSubject,
          initialMessage: AppLocalizations.of(
            context,
          ).discoverSupportMessage(state.origin, state.url, state.reason),
        ),
      ),
    );
  }
}
