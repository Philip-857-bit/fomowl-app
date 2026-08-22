import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/blockchain_service.dart';
import '../../../../services/deep_link_service.dart';
import '../../../../services/walletconnect/wallet_connect_service.dart';
import '../../discover_url_utils.dart';

import '../../permissions/dapp_permission_service.dart';
import '../../provider/dapp_provider_bridge.dart';
import '../browser_session_controller.dart';

class DiscoverBrowserView extends StatefulWidget {
  const DiscoverBrowserView({
    super.key,
    required this.sessionController,
    required this.providerBridge,
    required this.onClose,
    required this.tabCount,
    required this.onShowTabs,
  });

  final BrowserSessionController sessionController;
  final DappProviderBridge providerBridge;
  final VoidCallback onClose;
  final int tabCount;
  final VoidCallback onShowTabs;

  @override
  State<DiscoverBrowserView> createState() => _DiscoverBrowserViewState();
}

class _DiscoverBrowserViewState extends State<DiscoverBrowserView> {
  static const String _providerScriptGroup = 'owllet-provider';
  static const String _providerStateScriptGroup = 'owllet-provider-state';
  static const String _detectorScriptGroup = 'owllet-provider-detector';

  InAppWebViewController? _controller;
  bool _canGoBack = false;
  bool _canGoForward = false;
  int _progress = 0;
  String? _lastLoadedUrl;
  String? _pageLoadErrorMessage;
  // True between load start and stop. Drives a themed loading cover so the
  // opaque (white) webview content area doesn't flash before a site paints.
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    DappPermissionService.permissionRevision.addListener(
      _onPermissionRevisionChanged,
    );
    widget.sessionController.setWebViewBackHandler(_handleWebViewBack);
  }

  @override
  void dispose() {
    widget.sessionController.setWebViewBackHandler(null);
    DappPermissionService.permissionRevision.removeListener(
      _onPermissionRevisionChanged,
    );
    super.dispose();
  }

  /// Navigate back in the web view's page history if possible. Returns true if
  /// a back navigation happened (so the system back press is consumed).
  Future<bool> _handleWebViewBack() async {
    final controller = _controller;
    if (controller == null) {
      return false;
    }
    if (await controller.canGoBack()) {
      await controller.goBack();
      return true;
    }
    return false;
  }

  void _onPermissionRevisionChanged() {
    unawaited(_syncInjectedProviderState());
  }

  @override
  void didUpdateWidget(covariant DiscoverBrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newUrl = widget.sessionController.currentUri?.toString();
    if (_controller != null && newUrl != null && newUrl != _lastLoadedUrl) {
      _lastLoadedUrl = newUrl;
      unawaited(_loadCurrentUri(widget.sessionController.currentUri!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentUri = widget.sessionController.currentUri;
    if (currentUri == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildChrome(),
        Expanded(
          child: Stack(
            children: [
              InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  useShouldOverrideUrlLoading: true,
                  supportZoom: false,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  // Opaque white content area, like a normal browser. A
                  // transparent webview over the app's dark scaffold makes
                  // failed-load / native error pages (dark text) render onto
                  // black and become unreadable.
                  transparentBackground: false,
                  allowsBackForwardNavigationGestures: true,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  controller.addJavaScriptHandler(
                    handlerName: DappProviderBridge.handlerName,
                    callback: (args) async {
                      final payload = args.isNotEmpty && args.first is Map
                          ? (args.first as Map).cast<String, dynamic>()
                          : <String, dynamic>{};
                      final uri = widget.sessionController.currentUri;
                      final origin = uri == null
                          ? ''
                          : normalizeOriginFromUri(uri);
                      if (uri == null ||
                          !widget.sessionController.canInjectProviderFor(uri)) {
                        return <String, dynamic>{
                          'error': <String, dynamic>{
                            'code': 4100,
                            'message':
                                'Provider is unavailable for this origin.',
                          },
                        };
                      }
                      return widget.providerBridge.handleRequest(
                        context: context,
                        origin: origin,
                        payload: payload,
                        evaluateJavaScript: (source) async {
                          await controller.evaluateJavascript(source: source);
                        },
                      );
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: DappProviderBridge.detectorHandlerName,
                    callback: (args) async {
                      final payload = args.isNotEmpty && args.first is Map
                          ? (args.first as Map).cast<String, dynamic>()
                          : <String, dynamic>{};
                      final trigger =
                          payload['trigger']?.toString().trim().isNotEmpty ==
                              true
                          ? payload['trigger']!.toString().trim()
                          : l.discoverWalletApiAccessTrigger;
                      final href = payload['href']?.toString().trim();
                      final uri = href == null || href.isEmpty
                          ? widget.sessionController.currentUri
                          : Uri.tryParse(href);
                      if (uri == null ||
                          widget.sessionController.canInjectProviderFor(uri)) {
                        return null;
                      }
                      await controller.stopLoading();
                      widget.sessionController.blockDetectedDapp(
                        uri,
                        trigger: trigger,
                        reason: l.discoverBlockedReason('{trigger}'),
                      );
                      return null;
                    },
                  );
                  unawaited(_initializeWebView(controller, currentUri));
                },
                onPermissionRequest: (controller, request) async {
                  // Deny device-capability requests (camera, microphone,
                  // geolocation, etc.) by default so untrusted sites can't
                  // auto-grant sensitive permissions, especially on Android.
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.DENY,
                  );
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  final next = action.request.url?.uriValue;
                  if (next == null) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  final rawString = next.toString();
                  final wcPairingUri =
                      DeepLinkService.extractWalletConnectPairingUri(rawString);
                  if (wcPairingUri != null && wcPairingUri.isNotEmpty) {
                    unawaited(WalletConnectService.instance.pair(wcPairingUri));
                    return NavigationActionPolicy.CANCEL;
                  }
                  if (!widget.sessionController.allowsNavigation(
                    next,
                    unsupportedSchemeReason: l.discoverUnsupportedScheme,
                  )) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  await _applyUserScriptsFor(next);
                  return NavigationActionPolicy.ALLOW;
                },

                onLoadStart: (controller, url) {
                  final next = url?.uriValue;
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                      if (_pageLoadErrorMessage != null) {
                        _pageLoadErrorMessage = null;
                      }
                    });
                  }
                  if (next != null) {
                    _lastLoadedUrl = next.toString();
                    widget.sessionController.updateLoadedPage(next);
                  }
                },
                onLoadStop: (controller, url) async {
                  final next = url?.uriValue;
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      if (_pageLoadErrorMessage != null) {
                        _pageLoadErrorMessage = null;
                      }
                    });
                  }
                  if (next != null) {
                    final title = await controller.getTitle();
                    if (!context.mounted) {
                      return;
                    }
                    final chainId = context
                        .read<BlockchainService>()
                        .activeChain
                        .chainId;
                    widget.sessionController.updateLoadedPage(
                      next,
                      title: title,
                    );
                    if (widget.sessionController.canInjectProviderFor(next)) {
                      final providerScript = await widget.providerBridge
                          .providerInjectionScript();
                      await controller.evaluateJavascript(
                        source: providerScript,
                      );
                      await controller.evaluateJavascript(
                        source: await widget.providerBridge
                            .buildProviderStateSyncScript(
                              chainId: chainId,
                              origin: normalizeOriginFromUri(next),
                            ),
                      );
                    }
                  }
                  await _refreshNavigationState();
                },
                onReceivedError: (controller, request, error) async {
                  // WebView reports failures for every subresource too. A
                  // missing image/script must not replace an otherwise usable
                  // page with the full-screen browser error state.
                  if (request.isForMainFrame != true) {
                    return;
                  }
                  final requestUri = request.url.uriValue;
                  final current = widget.sessionController.currentUri;
                  final samePage =
                      current != null &&
                      normalizeOriginFromUri(requestUri) ==
                          normalizeOriginFromUri(current);
                  if (!samePage && requestUri.toString() != _lastLoadedUrl) {
                    return;
                  }
                  if (!mounted) {
                    return;
                  }
                  final type = error.type;
                  final message =
                      type == WebResourceErrorType.HOST_LOOKUP ||
                          type == WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
                          type ==
                              WebResourceErrorType.NETWORK_CONNECTION_LOST ||
                          type ==
                              WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
                          type == WebResourceErrorType.TIMEOUT
                      ? l.connectionFailed
                      : 'Unable to load this page right now.';
                  setState(() {
                    _pageLoadErrorMessage = message;
                    _progress = 0;
                    _isLoading = false;
                  });
                },
                onReceivedHttpError:
                    (controller, request, errorResponse) async {
                      if (request.isForMainFrame != true) {
                        return;
                      }
                      final requestUri = request.url.uriValue;
                      final current = widget.sessionController.currentUri;
                      final samePage =
                          current != null &&
                          normalizeOriginFromUri(requestUri) ==
                              normalizeOriginFromUri(current);
                      if (!samePage &&
                          requestUri.toString() != _lastLoadedUrl) {
                        return;
                      }
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _pageLoadErrorMessage =
                            'Unable to load this page right now.';
                        _progress = 0;
                        _isLoading = false;
                      });
                    },
                onTitleChanged: (controller, title) {
                  final currentUri = widget.sessionController.currentUri;
                  if (currentUri == null) {
                    return;
                  }
                  widget.sessionController.updateLoadedPage(
                    currentUri,
                    title: title,
                  );
                },
                onProgressChanged: (_, progress) {
                  setState(() => _progress = progress);
                },
                onUpdateVisitedHistory: (controller, url, isReload) async {
                  final next = url?.uriValue;
                  if (next != null) {
                    _lastLoadedUrl = next.toString();
                    widget.sessionController.updateLoadedPage(next);
                  }
                  await _refreshNavigationState();
                },
              ),
              // Themed loading cover: hides the opaque (white) webview content
              // area until the site paints, so dark sites don't flash white.
              if (_isLoading && _pageLoadErrorMessage == null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: AppColors.background,
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accentRed,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_pageLoadErrorMessage != null)
                Positioned.fill(
                  child: _buildPageErrorState(
                    message: _pageLoadErrorMessage!,
                    host: widget.sessionController.currentUri?.host ?? '',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _initializeWebView(
    InAppWebViewController controller,
    Uri currentUri,
  ) async {
    _lastLoadedUrl = currentUri.toString();
    await _applyBrowserUserAgent(controller);
    await _applyUserScriptsFor(currentUri);
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri.uri(currentUri)),
    );
  }

  Future<void> _applyBrowserUserAgent(InAppWebViewController controller) async {
    try {
      final defaultUserAgent =
          await InAppWebViewController.getDefaultUserAgent();
      final browserUserAgent = defaultUserAgent
          .replaceAll('; wv', '')
          .replaceAll(RegExp(r'\sVersion/[\d.]+'), '');
      if (browserUserAgent == defaultUserAgent || browserUserAgent.isEmpty) {
        return;
      }
      final settings = await controller.getSettings();
      if (settings == null) return;
      settings.userAgent = browserUserAgent;
      await controller.setSettings(settings: settings);
    } catch (error) {
      debugPrint('Discover browser user-agent setup failed: $error');
    }
  }

  Future<void> _loadCurrentUri(Uri uri) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await _applyUserScriptsFor(uri);
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
  }

  Future<void> _applyUserScriptsFor(Uri uri) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final chainId = context.read<BlockchainService>().activeChain.chainId;
    await controller.removeUserScriptsByGroupName(
      groupName: _providerScriptGroup,
    );
    await controller.removeUserScriptsByGroupName(
      groupName: _providerStateScriptGroup,
    );
    await controller.removeUserScriptsByGroupName(
      groupName: _detectorScriptGroup,
    );

    if (widget.sessionController.canInjectProviderFor(uri)) {
      final providerScript = await widget.providerBridge
          .providerInjectionScript();
      final providerStateScript = await widget.providerBridge
          .buildProviderStateSyncScript(
            chainId: chainId,
            origin: normalizeOriginFromUri(uri),
          );
      await controller.addUserScript(
        userScript: UserScript(
          groupName: _providerScriptGroup,
          source: providerScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
      await controller.addUserScript(
        userScript: UserScript(
          groupName: _providerStateScriptGroup,
          source: providerStateScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
      return;
    }

    if (widget.sessionController.shouldInjectDappDetectorFor(uri)) {
      await controller.addUserScript(
        userScript: UserScript(
          groupName: _detectorScriptGroup,
          source: DappProviderBridge.providerDetectionScript(),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    }
  }

  Future<void> _syncInjectedProviderState() async {
    final controller = _controller;
    final currentUri = widget.sessionController.currentUri;
    if (controller == null || currentUri == null || !mounted) {
      return;
    }
    if (!widget.sessionController.canInjectProviderFor(currentUri)) {
      return;
    }

    final chainId = context.read<BlockchainService>().activeChain.chainId;
    await controller.evaluateJavascript(
      source: await widget.providerBridge.buildProviderStateSyncScript(
        chainId: chainId,
        origin: normalizeOriginFromUri(currentUri),
      ),
    );
  }

  Widget _buildChrome() {
    final title =
        widget.sessionController.pageTitle ??
        widget.sessionController.activeDapp?.title ??
        widget.sessionController.currentUri?.host ??
        AppLocalizations.of(context).discoverBrowserFallbackTitle;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _canGoBack
                    ? () => unawaited(_navigateHistory(-1))
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              IconButton(
                onPressed: _canGoForward
                    ? () => unawaited(_navigateHistory(1))
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sessionController.currentUri?.host ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => unawaited(_reloadCurrentPage()),
                icon: const Icon(Icons.refresh_rounded),
              ),
              Semantics(
                button: true,
                label: AppLocalizations.of(context).discoverTabsTitle,
                child: InkWell(
                  onTap: widget.onShowTabs,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      width: 25,
                      height: 25,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 1.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.tabCount}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (_progress > 0 && _progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: Colors.white12,
              color: AppColors.accentRed,
            ),
        ],
      ),
    );
  }

  Future<void> _refreshNavigationState() async {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    final canGoBack = await controller.canGoBack();
    final canGoForward = await controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _navigateHistory(int offset) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final history = await controller.getCopyBackForwardList();
    if (history == null) {
      return;
    }
    final items = history.list ?? const <WebHistoryItem>[];
    final currentIndex = history.currentIndex ?? 0;
    final nextIndex = currentIndex + offset;
    if (nextIndex < 0 || nextIndex >= items.length) {
      return;
    }

    final targetUri = items[nextIndex].url?.uriValue;
    if (targetUri != null) {
      await _applyUserScriptsFor(targetUri);
    }

    if (offset < 0) {
      await controller.goBack();
    } else {
      await controller.goForward();
    }
    await _refreshNavigationState();
  }

  Future<void> _reloadCurrentPage() async {
    final controller = _controller;
    final currentUri = widget.sessionController.currentUri;
    if (controller == null) {
      return;
    }
    if (mounted && _pageLoadErrorMessage != null) {
      setState(() => _pageLoadErrorMessage = null);
    }
    if (currentUri != null) {
      await _applyUserScriptsFor(currentUri);
    }
    await controller.reload();
  }

  Widget _buildPageErrorState({required String message, required String host}) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.public_off_rounded,
                  color: AppColors.accentRed,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to open site',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (host.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  host,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClose,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => unawaited(_reloadCurrentPage()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Try again',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
