import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/in_app_link_router.dart';
import '../discover/discover_url_utils.dart';
import 'mini_app_definition.dart';
import 'mini_app_registry.dart';

class MiniAppHostArguments {
  const MiniAppHostArguments({
    required this.miniAppId,
    this.launchSource = 'mobile',
  });

  final String miniAppId;
  final String launchSource;
}

class MiniAppHostScreen extends StatefulWidget {
  const MiniAppHostScreen({
    super.key,
    required this.definition,
    this.launchSource = 'mobile',
  });

  final MiniAppDefinition definition;
  final String launchSource;

  static Widget fromRoute(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final parsed = switch (args) {
      MiniAppHostArguments value => value,
      String value => MiniAppHostArguments(miniAppId: value),
      _ => const MiniAppHostArguments(miniAppId: 'cash_in'),
    };
    final definition = OwlletMiniApps.byId(parsed.miniAppId);
    if (definition == null) {
      return const _MiniAppUnavailableScreen(
        title: 'Coming soon',
        message: 'This Owllet mini app is coming soon.',
      );
    }
    return MiniAppHostScreen(
      definition: definition,
      launchSource: parsed.launchSource,
    );
  }

  @override
  State<MiniAppHostScreen> createState() => _MiniAppHostScreenState();
}

class _MiniAppHostScreenState extends State<MiniAppHostScreen> {
  static const String _handlerName = 'owlletMiniAppBridge';
  static const String _scriptGroup = 'owllet-mini-app';

  final AuthService _authService = AuthService();
  InAppWebViewController? _controller;
  int _progress = 0;
  bool _canGoBack = false;
  bool _loadingContext = true;
  Map<String, dynamic> _bridgeContext = const <String, dynamic>{};

  Uri? get _launchUri =>
      widget.definition.buildLaunchUri(launchSource: widget.launchSource);

  List<String> get _trustedOrigins => widget.definition.trustedOrigins;

  @override
  void initState() {
    super.initState();
    _prepareBridgeContext();
  }

  Future<void> _prepareBridgeContext() async {
    final profile = await _authService.getCachedProfile();
    final isLoggedIn = await _authService.isLoggedIn();
    if (!mounted) {
      return;
    }
    final profilePayload = profile == null
        ? null
        : <String, dynamic>{
            'id': profile['id'],
            'email': profile['email'],
            'username': profile['username'],
            'country': profile['country'],
            'primaryWalletAddress': profile['primary_wallet_address'],
            'primary_wallet_address': profile['primary_wallet_address'],
            'emailVerified': profile['email_verified'],
            'twoFactorEnabled': profile['two_factor_enabled'],
            'email_verified': profile['email_verified'],
            'two_factor_enabled': profile['two_factor_enabled'],
          };
    setState(() {
      _bridgeContext = <String, dynamic>{
        'host': 'owllet-mobile',
        'hostInfo': <String, dynamic>{
          'name': 'owllet-mobile',
          'version': '1.0',
          'platform': defaultTargetPlatform.name,
          'theme': 'dark',
        },
        'miniAppId': widget.definition.id,
        'miniAppTitle': widget.definition.title,
        'miniApp': <String, dynamic>{
          'id': widget.definition.id,
          'title': widget.definition.title,
        },
        'launchSource': widget.launchSource,
        'launch': <String, dynamic>{'source': widget.launchSource},
        'platform': defaultTargetPlatform.name,
        'theme': 'dark',
        'walletAccess': 'gated',
        'permissions': <String, dynamic>{'walletAccess': 'gated'},
        'hasSession': isLoggedIn,
        'session': <String, dynamic>{
          'authenticated': isLoggedIn,
          'hasSession': isLoggedIn,
          'profile': profilePayload,
        },
        'profile': profilePayload,
        'capabilities': const <String, dynamic>{
          'ready': true,
          'close': true,
          'openExternal': true,
          'getContext': true,
        },
      };
      _loadingContext = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final launchUri = _launchUri;
    if (launchUri == null) {
      return _MiniAppUnavailableScreen(
        title: '${widget.definition.title} coming soon',
        message: 'This Owllet mini app is coming soon.',
      );
    }
    if (_loadingContext) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.success),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildChrome(launchUri),
            Expanded(
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: false,
                  transparentBackground: true,
                  useShouldOverrideUrlLoading: true,
                  allowsBackForwardNavigationGestures: true,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  controller.addJavaScriptHandler(
                    handlerName: _handlerName,
                    callback: (args) async => _handleBridgeCall(args),
                  );
                  _initializeWebView(controller, launchUri);
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  final next = action.request.url?.uriValue;
                  if (next == null) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  if (!isSupportedDiscoverWebUri(next)) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  if (!_isTrustedOrigin(next)) {
                    await _openExternal(next);
                    return NavigationActionPolicy.CANCEL;
                  }
                  await _applyBridgeIfTrusted(next);
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStart: (controller, url) {
                  setState(() => _progress = 0);
                },
                onProgressChanged: (_, progress) {
                  setState(() => _progress = progress);
                },
                onLoadStop: (controller, url) async {
                  final next = url?.uriValue;
                  if (next != null) {
                    await _applyBridgeIfTrusted(next);
                  }
                  await _refreshNavigationState();
                },
                onUpdateVisitedHistory:
                    (controller, url, androidIsReload) async {
                      await _refreshNavigationState();
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChrome(Uri launchUri) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.definition.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      launchUri.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _canGoBack ? _goBack : null,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_progress > 0 && _progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: Colors.white12,
              color: AppColors.success,
            ),
        ],
      ),
    );
  }

  Future<void> _initializeWebView(
    InAppWebViewController controller,
    Uri launchUri,
  ) async {
    await _applyBridgeIfTrusted(launchUri);
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri.uri(launchUri)),
    );
  }

  Future<void> _applyBridgeIfTrusted(Uri uri) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.removeUserScriptsByGroupName(groupName: _scriptGroup);
    if (!_isTrustedOrigin(uri)) {
      return;
    }
    await controller.addUserScript(
      userScript: UserScript(
        groupName: _scriptGroup,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        source: _buildBridgeScript(),
      ),
    );
  }

  String _buildBridgeScript() {
    final encodedContext = jsonEncode(_bridgeContext);
    return '''
(function() {
  const context = $encodedContext;
  const callHost = function(payload) {
    return window.flutter_inappwebview.callHandler('$_handlerName', payload);
  };
  window.OwlletMiniApp = {
    version: '1.0',
    host: 'owllet-mobile',
    ready: function(payload) {
      return callHost({ type: 'ready', payload: payload || {} });
    },
    close: function() {
      return callHost({ type: 'close' });
    },
    openExternal: function(url) {
      return callHost({ type: 'open_external', url: url });
    },
    getContext: function() {
      return context;
    }
  };
  window.dispatchEvent(new CustomEvent('owllet:miniapp:ready', { detail: context }));
})();
''';
  }

  Future<Map<String, dynamic>> _handleBridgeCall(List<dynamic> args) async {
    final raw = args.isNotEmpty && args.first is Map
        ? (args.first as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final type = raw['type']?.toString().trim() ?? '';
    switch (type) {
      case 'close':
        if (mounted) {
          Navigator.of(context).pop();
        }
        return const <String, dynamic>{'ok': true};
      case 'open_external':
        final url = raw['url']?.toString().trim();
        if (url == null || url.isEmpty) {
          return const <String, dynamic>{'ok': false, 'error': 'Missing URL.'};
        }
        final uri = Uri.tryParse(url);
        if (uri == null) {
          return const <String, dynamic>{'ok': false, 'error': 'Invalid URL.'};
        }
        await _openExternal(uri);
        return const <String, dynamic>{'ok': true};
      case 'ready':
        return <String, dynamic>{'ok': true, 'context': _bridgeContext};
      default:
        return <String, dynamic>{
          'ok': false,
          'error': 'Unsupported bridge action: $type',
        };
    }
  }

  bool _isTrustedOrigin(Uri uri) {
    if (!isSupportedDiscoverWebUri(uri)) {
      return false;
    }
    final origin = normalizeOriginFromUri(uri);
    return _trustedOrigins.contains(origin);
  }

  Future<void> _openExternal(Uri uri) async {
    await InAppLinkRouter.open(context, uri.toString());
  }

  Future<void> _refreshNavigationState() async {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    final canGoBack = await controller.canGoBack();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canGoBack;
    });
  }

  Future<void> _goBack() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (await controller.canGoBack()) {
      await controller.goBack();
      await _refreshNavigationState();
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _reload() async {
    await _controller?.reload();
  }
}

class _MiniAppUnavailableScreen extends StatelessWidget {
  const _MiniAppUnavailableScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.public_off_rounded,
                  color: AppColors.success,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
