import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
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
  InAppWebViewController? _controller;
  bool _canGoBack = false;
  bool _canGoForward = false;
  int _progress = 0;

  @override
  void didUpdateWidget(covariant DiscoverBrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = oldWidget.sessionController.currentUri?.toString();
    final newUrl = widget.sessionController.currentUri?.toString();
    if (_controller != null && newUrl != null && oldUrl != newUrl) {
      _controller!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri.uri(widget.sessionController.currentUri!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUri = widget.sessionController.currentUri;
    if (currentUri == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildChrome(),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri.uri(currentUri)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
              supportZoom: false,
              transparentBackground: true,
              allowsBackForwardNavigationGestures: true,
            ),
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: DappProviderBridge.providerInjectionScript(),
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            ]),
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
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final next = action.request.url?.uriValue;
              if (next == null) {
                return NavigationActionPolicy.ALLOW;
              }
              if (!widget.sessionController.allowsNavigation(next)) {
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, url) {
              final next = url?.uriValue;
              if (next != null) {
                widget.sessionController.updateLoadedPage(next);
              }
            },
            onLoadStop: (controller, url) async {
              final next = url?.uriValue;
              if (next != null) {
                final title = await controller.getTitle();
                widget.sessionController.updateLoadedPage(next, title: title);
                if (widget.sessionController.canInjectProviderFor(next)) {
                  await controller.evaluateJavascript(
                    source: DappProviderBridge.providerInjectionScript(),
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
                widget.sessionController.updateLoadedPage(next);
              }
              await _refreshNavigationState();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChrome() {
    final title =
        widget.sessionController.pageTitle ??
        widget.sessionController.activeDapp?.title ??
        widget.sessionController.currentUri?.host ??
        'Discover';
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
                    ? () async {
                        await _controller?.goBack();
                        await _refreshNavigationState();
                      }
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              IconButton(
                onPressed: _canGoForward
                    ? () async {
                        await _controller?.goForward();
                        await _refreshNavigationState();
                      }
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
                onPressed: () => _controller?.reload(),
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
}
