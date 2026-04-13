import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/blockchain_service.dart';
import '../../discover_url_utils.dart';
import '../../provider/dapp_provider_bridge.dart';
import '../browser_session_controller.dart';

class DiscoverBrowserView extends StatefulWidget {
  const DiscoverBrowserView({
    super.key,
    required this.sessionController,
    required this.providerBridge,
    required this.onClose,
  });

  final BrowserSessionController sessionController;
  final DappProviderBridge providerBridge;
  final VoidCallback onClose;

  @override
  State<DiscoverBrowserView> createState() => _DiscoverBrowserViewState();
}

class _DiscoverBrowserViewState extends State<DiscoverBrowserView> {
  static const String _providerScriptGroup = 'owllet-provider';
  static const String _detectorScriptGroup = 'owllet-provider-detector';

  InAppWebViewController? _controller;
  bool _canGoBack = false;
  bool _canGoForward = false;
  int _progress = 0;
  String? _lastLoadedUrl;

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
          child: InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
              supportZoom: false,
              transparentBackground: true,
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
                  final origin = uri == null ? '' : normalizeOriginFromUri(uri);
                  if (uri == null ||
                      !widget.sessionController.canInjectProviderFor(uri)) {
                    return <String, dynamic>{
                      'error': <String, dynamic>{
                        'code': 4100,
                        'message': 'Provider is unavailable for this origin.',
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
                      payload['trigger']?.toString().trim().isNotEmpty == true
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
            shouldOverrideUrlLoading: (controller, action) async {
              final next = action.request.url?.uriValue;
              if (next == null) {
                return NavigationActionPolicy.ALLOW;
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
              if (next != null) {
                _lastLoadedUrl = next.toString();
                widget.sessionController.updateLoadedPage(next);
              }
            },
            onLoadStop: (controller, url) async {
              final next = url?.uriValue;
              if (next != null) {
                final title = await controller.getTitle();
                if (!context.mounted) {
                  return;
                }
                final chainId = context
                    .read<BlockchainService>()
                    .activeChain
                    .chainId;
                widget.sessionController.updateLoadedPage(next, title: title);
                if (widget.sessionController.canInjectProviderFor(next)) {
                  final providerScript = await widget.providerBridge
                      .providerInjectionScript();
                  await controller.evaluateJavascript(source: providerScript);
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
        ),
      ],
    );
  }

  Future<void> _initializeWebView(
    InAppWebViewController controller,
    Uri currentUri,
  ) async {
    _lastLoadedUrl = currentUri.toString();
    await _applyUserScriptsFor(currentUri);
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri.uri(currentUri)),
    );
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
    await controller.removeUserScriptsByGroupName(
      groupName: _providerScriptGroup,
    );
    await controller.removeUserScriptsByGroupName(
      groupName: _detectorScriptGroup,
    );

    if (widget.sessionController.canInjectProviderFor(uri)) {
      final providerScript = await widget.providerBridge
          .providerInjectionScript();
      await controller.addUserScript(
        userScript: UserScript(
          groupName: _providerScriptGroup,
          source: providerScript,
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
    if (currentUri != null) {
      await _applyUserScriptsFor(currentUri);
    }
    await controller.reload();
  }
}
