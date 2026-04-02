import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/profile/feedback_screen.dart';
import '../../utils/app_error_utils.dart';
import 'browser/browser_session_controller.dart';
import 'browser/widgets/discover_blocked_view.dart';
import 'browser/widgets/discover_browser_view.dart';
import 'catalog/discover_catalog_service.dart';
import 'catalog/widgets/discover_landing_view.dart';
import 'market/discover_trending_token.dart';
import 'market/discover_trending_token_service.dart';
import 'permissions/dapp_permission_service.dart';
import 'provider/dapp_provider_bridge.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final DiscoverCatalogService _catalogService;
  late final DiscoverTrendingTokenService _trendingTokenService;
  late final BrowserSessionController _sessionController;
  late final DappPermissionService _permissionService;
  late final DappProviderBridge _providerBridge;
  final TextEditingController _searchController = TextEditingController();
  List<DiscoverTrendingToken> _trendingTokens = const <DiscoverTrendingToken>[];
  bool _loadingTrendingTokens = false;
  String? _trendingTokensError;

  @override
  void initState() {
    super.initState();
    _catalogService = DiscoverCatalogService();
    _trendingTokenService = DiscoverTrendingTokenService();
    _permissionService = DappPermissionService();
    _sessionController = BrowserSessionController(
      catalogService: _catalogService,
    );
    _providerBridge = DappProviderBridge(
      sessionController: _sessionController,
      permissionService: _permissionService,
    );
    _sessionController.addListener(_syncSearchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionController.loadCatalog();
      _loadTrendingTokens();
    });
  }

  @override
  void dispose() {
    _sessionController.removeListener(_syncSearchField);
    _sessionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _syncSearchField() {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sessionController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.discoverTitle,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _refreshLandingData,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: _sessionController.updateQuery,
            onSubmitted: (value) => _sessionController.openManualInput(
              value,
              invalidInputReason: l.discoverManualInputInvalid,
              webSearchTitle: l.discoverWebSearchTitle,
            ),
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              hintText: l.discoverSearchHint,
              hintStyle: GoogleFonts.outfit(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white54,
              ),
              suffixIcon: _sessionController.query.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _sessionController.updateQuery(''),
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.cardDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.accentRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_sessionController.viewState) {
      case DiscoverViewState.browser:
        return DiscoverBrowserView(
          sessionController: _sessionController,
          providerBridge: _providerBridge,
          onClose: _sessionController.returnToLanding,
        );
      case DiscoverViewState.blocked:
        final state = _sessionController.blockedState;
        if (state == null) {
          return const SizedBox.shrink();
        }
        return DiscoverBlockedView(
          state: state,
          onRequestSupport: () => _openRequestSupport(state),
          onOpenExternal: () => _openExternal(state.url),
          onCancel: _sessionController.returnToLanding,
        );
      case DiscoverViewState.landing:
        final l = AppLocalizations.of(context);
        return DiscoverLandingView(
          featuredDapps: _sessionController.featuredDapps,
          trendingDapps: _sessionController.trendingDapps,
          filteredDapps: _sessionController.filteredDapps,
          categories: _sessionController.categories,
          trendingTokens: _trendingTokens,
          loadingTrendingTokens: _loadingTrendingTokens,
          trendingTokensError: _trendingTokensError,
          loading: _sessionController.loadingCatalog,
          error: _sessionController.catalogError == null
              ? null
              : l.discoverCatalogLoadError,
          onRefresh: _refreshLandingData,
          onOpenDapp: (dapp) => _sessionController.openDapp(
            dapp,
            invalidLaunchUrlReason: l.discoverInvalidLaunchUrl,
          ),
        );
    }
  }

  Future<void> _refreshLandingData() async {
    await Future.wait<void>([
      _sessionController.loadCatalog(forceRefresh: true),
      _loadTrendingTokens(),
    ]);
  }

  Future<void> _loadTrendingTokens() async {
    if (_loadingTrendingTokens) {
      return;
    }
    setState(() {
      _loadingTrendingTokens = true;
      _trendingTokensError = null;
    });
    try {
      final tokens = await _trendingTokenService.fetchTrendingTokens();
      if (!mounted) {
        return;
      }
      setState(() {
        _trendingTokens = tokens;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _trendingTokensError = AppErrorUtils.userMessage(
          error,
          fallback: AppLocalizations.of(
            context,
          ).discoverTrendingTokensLoadError,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingTrendingTokens = false;
        });
      }
    }
  }

  Future<void> _openExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
