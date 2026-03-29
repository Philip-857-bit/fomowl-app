import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../screens/profile/feedback_screen.dart';
import 'browser/browser_session_controller.dart';
import 'browser/widgets/discover_blocked_view.dart';
import 'browser/widgets/discover_browser_view.dart';
import 'catalog/discover_catalog_service.dart';
import 'catalog/widgets/discover_landing_view.dart';
import 'permissions/dapp_permission_service.dart';
import 'provider/dapp_provider_bridge.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final DiscoverCatalogService _catalogService;
  late final BrowserSessionController _sessionController;
  late final DappPermissionService _permissionService;
  late final DappProviderBridge _providerBridge;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _catalogService = DiscoverCatalogService();
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Discover',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    _sessionController.loadCatalog(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: _sessionController.updateQuery,
            onSubmitted: _sessionController.openManualInput,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search approved DApps or enter allowlisted URL',
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
        return DiscoverLandingView(
          featuredDapps: _sessionController.featuredDapps,
          trendingDapps: _sessionController.trendingDapps,
          filteredDapps: _sessionController.filteredDapps,
          categories: _sessionController.categories,
          loading: _sessionController.loadingCatalog,
          error: _sessionController.catalogError,
          onRefresh: () => _sessionController.loadCatalog(forceRefresh: true),
          onOpenDapp: _sessionController.openDapp,
        );
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
          initialSubject: 'Discover allowlist request',
          initialMessage:
              'Please review this DApp for Owllet Discover.\n\nOrigin: ${state.origin}\nURL: ${state.url}\nReason shown: ${state.reason}',
        ),
      ),
    );
  }
}
