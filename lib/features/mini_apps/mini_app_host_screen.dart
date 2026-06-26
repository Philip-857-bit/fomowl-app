import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../config/app_environment.dart';
import '../../models/chain.dart';
import '../../models/wallet_account.dart';
import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_backend_auth_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/bridge_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/http_client_service.dart';
import '../../services/system_picker_guard.dart';
import '../../services/transaction_monitor.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/in_app_link_router.dart';
import '../../screens/transaction/transaction_processing_screen.dart';
import '../../screens/home/home_portfolio_api_service.dart';
import '../discover/discover_url_utils.dart';
import 'mini_app_definition.dart';
import 'mini_app_registry.dart';

class MiniAppHostArguments {
  const MiniAppHostArguments({
    required this.miniAppId,
    this.launchSource = 'mobile',
    this.initialUrl,
  });

  final String miniAppId;
  final String launchSource;

  /// Optional deep-link URL to open instead of the mini app's base launch URL.
  /// Only honored when it resolves to one of the mini app's trusted origins.
  final String? initialUrl;
}

class MiniAppHostScreen extends StatefulWidget {
  const MiniAppHostScreen({
    super.key,
    required this.definition,
    this.launchSource = 'mobile',
    this.initialUrl,
  });

  final MiniAppDefinition definition;
  final String launchSource;
  final String? initialUrl;

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
      initialUrl: parsed.initialUrl,
    );
  }

  @override
  State<MiniAppHostScreen> createState() => _MiniAppHostScreenState();
}

/// Build-time opt-in to expose the mini-app webview to remote inspectors on a
/// release build (debug builds are always inspectable). Set with
/// `--dart-define=OWLLET_WEBVIEW_INSPECTABLE=true` when you need to debug the
/// hosted website in a release artifact; defaults to false for production.
const bool _webviewInspectable = bool.fromEnvironment(
  'OWLLET_WEBVIEW_INSPECTABLE',
);

class _MiniAppHostScreenState extends State<MiniAppHostScreen> {
  static const String _handlerName = 'owlletMiniAppBridge';
  static const String _scriptGroup = 'owllet-mini-app';
  static const MethodChannel _cameraPermissionChannel = MethodChannel(
    'owllet/camera_permission',
  );

  final AuthService _authService = AuthService();
  final WalletBackendAuthService _walletBackendAuthService =
      WalletBackendAuthService();
  final WalletService _walletService = WalletService();
  final TransactionMonitor _transactionMonitor = TransactionMonitor();
  InAppWebViewController? _controller;
  int _progress = 0;
  bool _canGoBack = false;
  bool _loadingContext = true;
  Map<String, dynamic> _bridgeContext = const <String, dynamic>{};

  Uri? get _overrideUri {
    final raw = widget.initialUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return Uri.tryParse(raw);
  }

  Uri? get _launchUri => widget.definition.buildLaunchUri(
    launchSource: widget.launchSource,
    overrideUri: _overrideUri,
  );

  List<String> get _trustedOrigins => widget.definition.trustedOrigins;

  @override
  void initState() {
    super.initState();
    _prepareBridgeContext();
  }

  @override
  void dispose() {
    // Don't leave the lock-on-background suppressed once the user leaves the
    // mini app; the guard is only meant to cover an in-flight capture here.
    SystemPickerGuard.clear();
    super.dispose();
  }

  Future<void> _prepareBridgeContext() async {
    final profile = await _authService.getCachedProfile();
    final isLoggedIn = await _authService.isLoggedIn();

    // Resolve the EVM wallet address from the wallet itself first — the most
    // reliable source. The cached backend profile does not always carry
    // `primary_wallet_address`, which previously left mini-apps with no wallet
    // context at all. Fall back to the profile field when the wallet lookup is
    // unavailable.
    String? rawWalletAddress;
    try {
      rawWalletAddress = await _walletService.getCurrentWalletAddress();
    } catch (_) {
      rawWalletAddress = null;
    }
    if (rawWalletAddress == null || rawWalletAddress.isEmpty) {
      rawWalletAddress = profile?['primary_wallet_address']?.toString();
    }
    final String? walletAddress =
        (rawWalletAddress != null && rawWalletAddress.isNotEmpty)
        ? rawWalletAddress
        : null;
    final hasWallet = walletAddress != null;

    // The user's Solana address — needed by cross-chain flows (e.g. cash-in's
    // sell-any-token saga uses it as the USDC refund address). Best-effort.
    String? solanaWalletAddress;
    try {
      solanaWalletAddress =
          await _walletService.getWalletAddressForFamily(ChainFamily.solana);
    } catch (_) {
      solanaWalletAddress = null;
    }

    // Surface the wallet-auth (ws_) session token to the mini-app so it can call
    // wallet-scoped backend endpoints (e.g. the affiliate dashboard) as the user.
    // For mini apps that require it we mint a session (signing silently with the
    // wallet key); otherwise we only surface a cached token to keep open fast.
    String? walletSessionToken;
    if (walletAddress != null) {
      try {
        walletSessionToken = widget.definition.requiresWalletSession
            ? await _walletBackendAuthService
                  .ensureWalletSession(walletAddress)
                  .timeout(const Duration(seconds: 12))
            : await _walletBackendAuthService.getValidSessionToken(
                walletAddress,
              );
      } catch (_) {
        walletSessionToken = null;
      }
    }

    if (!mounted) {
      return;
    }
    // The wallet's currently-selected network, so mini apps can scope a balance
    // headline to the active chain instead of summing every network. Use
    // `activeNetworkKey` (NOT `activeChain.networkKey`): the latter is always the
    // EVM chain, so it would report e.g. evm:56 even when the user has switched
    // the wallet to Tron/Solana, hiding their balance on the truly-active chain.
    // We also derive the chain family + (EVM) chain id from the key so the SDK's
    // `activeNetwork` is fully populated, not just the bare key.
    // Best-effort: omitted if the provider isn't reachable.
    String? activeNetworkKey;
    String? activeChainFamily;
    int? activeChainId;
    try {
      activeNetworkKey = context.read<BlockchainService>().activeNetworkKey;
      // networkKey is "<family>:<rest>" — e.g. "evm:56", "tron:mainnet".
      if (activeNetworkKey.contains(':')) {
        final parts = activeNetworkKey.split(':');
        activeChainFamily = parts.first;
        if (parts.first == 'evm' && parts.length > 1) {
          activeChainId = int.tryParse(parts[1]);
        }
      }
    } catch (_) {
      activeNetworkKey = null;
      activeChainFamily = null;
      activeChainId = null;
    }
    final profilePayload = (profile == null && !hasWallet)
        ? null
        : <String, dynamic>{
            'id': profile?['id'],
            'email': profile?['email'],
            'username': profile?['username'],
            'country': profile?['country'],
            'primaryWalletAddress': walletAddress,
            'primary_wallet_address': walletAddress,
            'emailVerified': profile?['email_verified'],
            'twoFactorEnabled': profile?['two_factor_enabled'],
            'email_verified': profile?['email_verified'],
            'two_factor_enabled': profile?['two_factor_enabled'],
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
        'activeNetworkKey': activeNetworkKey,
        'activeChainFamily': activeChainFamily,
        'activeChainId': activeChainId,
        'solanaWalletAddress': solanaWalletAddress,
        'walletAccess': 'gated',
        'permissions': <String, dynamic>{'walletAccess': 'gated'},
        'hasSession': isLoggedIn,
        'session': <String, dynamic>{
          'authenticated': isLoggedIn,
          'hasSession': isLoggedIn,
          'profile': profilePayload,
          'token': walletSessionToken,
        },
        'profile': profilePayload,
        'capabilities': const <String, dynamic>{
          'ready': true,
          'close': true,
          'openExternal': true,
          'getContext': true,
          'requestWalletTransfer': true,
          'requestSwapThenTransfer': false,
          'requestCrossChainSwap': true,
          'requestSignMessage': true,
          'notify': true,
          'getBalances': true,
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
                  // Expose the webview to chrome://inspect (Android) and Safari
                  // Web Inspector (iOS) for debugging the mini-app's JS console.
                  // On by default in debug builds; to debug a RELEASE build, build
                  // with --dart-define=OWLLET_WEBVIEW_INSPECTABLE=true. A normal
                  // production release (no flag) stays locked.
                  isInspectable: kDebugMode || _webviewInspectable,
                  // Allow the in-app live camera (getUserMedia) used by KYC
                  // capture so the flow never has to background into the
                  // external camera app (which trips the app lock and loses
                  // the captured image).
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  iframeAllow: 'camera; microphone',
                  iframeAllowFullscreen: true,
                ),
                onPermissionRequest: (controller, request) async {
                  // Only a trusted mini-app origin may use the device camera
                  // (e.g. Cash In KYC selfie). Some Android WebView builds report
                  // an empty/null permission-request origin, which previously
                  // tripped the trust check and silently denied getUserMedia
                  // (NotAllowedError) even with the OS camera permission granted.
                  // Fall back to the CURRENTLY-LOADED page origin — that URL is
                  // already origin-guarded by shouldOverrideUrlLoading, so only a
                  // trusted page can ever be the top-level document here.
                  final pageTrusted =
                      _isTrustedOrigin(request.origin) ||
                      await _isCurrentPageTrusted();
                  if (!pageTrusted) {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.DENY,
                    );
                  }
                  // Tell the host lock guard this backgrounding (system
                  // permission dialog / camera) is expected so it doesn't throw
                  // up the unlock screen and wipe the capture in progress.
                  SystemPickerGuard.arm();
                  final granted = await _ensureNativeCameraPermission();
                  return PermissionResponse(
                    resources: request.resources,
                    action: granted
                        ? PermissionResponseAction.GRANT
                        : PermissionResponseAction.DENY,
                  );
                },
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
    requestWalletTransfer: function(payload) {
      return callHost({ type: 'request_wallet_transfer', payload: payload || {} });
    },
    requestCrossChainSwap: function(payload) {
      return callHost({ type: 'request_cross_chain_swap', payload: payload || {} });
    },
    requestSignMessage: function(payload) {
      return callHost({ type: 'request_sign_message', payload: payload || {} });
    },
    notify: function(payload) {
      return callHost({ type: 'notify', payload: payload || {} });
    },
    getBalances: function() {
      return callHost({ type: 'get_balances' });
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
      case 'request_wallet_transfer':
        final payload = raw['payload'];
        if (payload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid wallet transfer request.',
          };
        }
        return _handleWalletTransferRequest(payload.cast<String, dynamic>());
      case 'request_cross_chain_swap':
        final swapPayload = raw['payload'];
        if (swapPayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid cross-chain swap request.',
          };
        }
        return _handleCrossChainSwapRequest(swapPayload.cast<String, dynamic>());
      case 'request_sign_message':
        final signPayload = raw['payload'];
        if (signPayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid sign-message request.',
          };
        }
        return _handleSignMessageRequest(signPayload.cast<String, dynamic>());
      case 'notify':
        final notifyPayload = raw['payload'];
        if (notifyPayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid notification request.',
          };
        }
        return _handleNotifyRequest(notifyPayload.cast<String, dynamic>());
      case 'get_balances':
        return _handleGetBalancesRequest();
      default:
        return <String, dynamic>{
          'ok': false,
          'error': 'Unsupported bridge action: $type',
        };
    }
  }

  /// Returns the user's wallet token balances for the mini app across EVM,
  /// Solana, and Tron. Sourced from the same backend endpoints the wallet uses,
  /// so the wallet address stays gated — only normalized per-token balances
  /// cross the bridge. Each chain family is best-effort; a failure on one does
  /// not drop the others. Including non-EVM balances lets off-ramp assets like
  /// USDT·SOL surface a balance (previously only EVM chains were returned).
  Future<Map<String, dynamic>> _handleGetBalancesRequest() async {
    final balances = <Map<String, dynamic>>[];

    // EVM balances via the aggregated portfolio endpoint.
    final evmAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.evm,
    );
    if (evmAddress != null && evmAddress.trim().isNotEmpty) {
      try {
        final snapshot = await HomePortfolioApiService().fetchPortfolio(
          evmAddress,
        );
        for (final section in snapshot.sections) {
          for (final token in section.tokens) {
            final networkKey =
                (token.networkKey == null || token.networkKey!.trim().isEmpty)
                ? section.chain.networkKey
                : token.networkKey!;
            balances.add(<String, dynamic>{
              'symbol': token.symbol,
              'name': token.name,
              'networkKey': networkKey,
              'chainFamily': NetworkKey.familyOf(networkKey).wireValue,
              'contractAddress': token.contractAddress,
              'decimals': token.decimals,
              'balance': token.balance,
              'valueUsd': token.valueUsd,
              'priceUsd': token.priceUsd,
            });
          }
        }
      } catch (error) {
        debugPrint('Mini-app getBalances: EVM portfolio failed: $error');
      }
    }

    // Non-EVM balances (Solana, Tron) so off-ramp assets on those chains show a
    // balance and can be validated client-side.
    balances.addAll(
      await _fetchNonEvmBridgeBalances(ChainFamily.solana, 'solana:mainnet'),
    );
    balances.addAll(
      await _fetchNonEvmBridgeBalances(ChainFamily.tron, 'tron:mainnet'),
    );

    return <String, dynamic>{'ok': true, 'balances': balances};
  }

  /// Fetch non-EVM (Solana/Tron) wallet token balances statelessly via the
  /// backend network-key wallet-tokens endpoint, normalized to the same shape
  /// as the EVM balances above. Best-effort: returns empty on any failure.
  Future<List<Map<String, dynamic>>> _fetchNonEvmBridgeBalances(
    ChainFamily family,
    String networkKey,
  ) async {
    final address = await _walletService.getWalletAddressForFamily(family);
    if (address == null || address.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final uri = AppEnvironment.blockchain(
        '/networks/${Uri.encodeComponent(networkKey)}'
        '/wallet-tokens/${Uri.encodeComponent(address)}',
      );
      final response = await HttpClientService().client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      final rawTokens = decoded['tokens'];
      if (rawTokens is! List) {
        return const <Map<String, dynamic>>[];
      }
      final defaultDecimals = family == ChainFamily.solana ? 9 : 6;
      final result = <Map<String, dynamic>>[];
      for (final raw in rawTokens) {
        if (raw is! Map) continue;
        final token = raw.map((key, value) => MapEntry('$key', value));
        final symbol = (token['symbol'] as String?)?.trim() ?? '';
        final balance = (token['balance'] as num?)?.toDouble() ?? 0;
        if (symbol.isEmpty || balance <= 0) continue;
        result.add(<String, dynamic>{
          'symbol': symbol,
          'name': (token['name'] as String?) ?? symbol,
          'networkKey': networkKey,
          'chainFamily': family.wireValue,
          'contractAddress': token['contractAddress'],
          'decimals': (token['decimals'] as num?)?.toInt() ?? defaultDecimals,
          'balance': balance,
          'valueUsd': (token['valueUsd'] as num?)?.toDouble() ?? 0,
          'priceUsd': (token['priceUsd'] as num?)?.toDouble() ?? 0,
        });
      }
      return result;
    } catch (error) {
      debugPrint('Mini-app getBalances: $networkKey fetch failed: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> _handleWalletTransferRequest(
    Map<String, dynamic> payload,
  ) async {
    final reference = payload['reference']?.toString().trim() ?? '';
    final action = payload['action']?.toString().trim().toLowerCase();
    final networkKey = payload['networkKey']?.toString().trim() ?? '';
    final symbol =
        payload['assetSymbol']?.toString().trim().toUpperCase() ?? '';
    final assetName = payload['assetName']?.toString().trim() ?? symbol;
    final toAddress = payload['toAddress']?.toString().trim() ?? '';
    final amountDisplay = payload['amountDisplay']?.toString().trim() ?? '';
    final nativeSymbol = payload['nativeSymbol']?.toString().trim() ?? '';
    final amountBaseUnits = BigInt.tryParse(
      payload['amountBaseUnits']?.toString() ?? '',
    );
    final decimals = int.tryParse(payload['decimals']?.toString() ?? '') ?? 18;
    final tokenContract = payload['tokenContract']?.toString().trim();

    if (action != null &&
        action.isNotEmpty &&
        action != 'transfer' &&
        action != 'wallet_transfer') {
      return const <String, dynamic>{
        'ok': false,
        'error':
            'Withdrawals settle in USDT or USDC. To withdraw another token, swap it to USDT in your wallet first, then withdraw.',
      };
    }

    if (reference.isEmpty ||
        networkKey.isEmpty ||
        symbol.isEmpty ||
        toAddress.isEmpty ||
        amountBaseUnits == null ||
        amountBaseUnits <= BigInt.zero) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Invalid wallet transfer request.',
      };
    }

    final family = NetworkKey.familyOf(networkKey);
    if (!_isValidAddressForFamily(toAddress, family)) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Invalid settlement route.',
      };
    }

    final fromAddress = await _walletService.getWalletAddressForFamily(family);
    if (fromAddress == null || fromAddress.trim().isEmpty) {
      return <String, dynamic>{
        'ok': false,
        'error': 'This wallet does not support ${family.wireValue}.',
      };
    }

    final confirmed = await _confirmHiddenSettlementTransfer(
      reference: reference,
      amountDisplay: amountDisplay.isEmpty ? symbol : amountDisplay,
      assetSymbol: symbol,
      nativeSymbol: nativeSymbol,
    );
    if (confirmed != true) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Wallet transfer was cancelled.',
      };
    }

    final token = Token(
      symbol: symbol,
      name: assetName.isEmpty ? symbol : assetName,
      contractAddress: tokenContract == null || tokenContract.isEmpty
          ? null
          : tokenContract,
      balance: 0,
      valueUsd: 0,
      changePercent24h: 0,
      decimals: decimals,
      networkKey: networkKey,
      tokenStandard: tokenContract == null || tokenContract.isEmpty
          ? TokenStandard.native
          : switch (family) {
              ChainFamily.solana => TokenStandard.spl,
              ChainFamily.tron => TokenStandard.trc20,
              ChainFamily.evm => TokenStandard.erc20,
            },
    );

    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.transfer,
    );
    if (mounted) {
      unawaited(
        Navigator.of(context).pushNamed(
          '/transaction-processing',
          arguments: TransactionProcessingArguments(controller: controller),
        ),
      );
    }

    try {
      controller.setPreparing();
      controller.setSwapSubmitting();
      final txHash = await _sendBridgeTransfer(
        networkKey: networkKey,
        family: family,
        fromAddress: fromAddress,
        toAddress: toAddress,
        amountBaseUnits: amountBaseUnits,
        token: token,
      );
      if (!mounted) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Transfer status could not be tracked.',
        };
      }
      final detailsUrl = _transactionDetailsUrl(txHash, networkKey);
      controller.setSwapPending(
        reference: _shortHash(txHash),
        detailsUrl: detailsUrl,
      );

      final blockchain = context.read<BlockchainService>();
      final confirmed = await _transactionMonitor.waitForConfirmation(
        txHash: txHash,
        blockchain: blockchain,
        networkKey: networkKey,
        evmChain: family == ChainFamily.evm
            ? _evmChainForNetwork(blockchain, networkKey)
            : null,
      );
      if (confirmed) {
        controller.setSuccess(
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
      } else {
        controller.setError(
          'Transfer submitted and awaiting network confirmation.',
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
      }

      return <String, dynamic>{
        'ok': true,
        'transactionHash': txHash,
        'confirmed': confirmed,
      };
    } catch (error) {
      final message = _bridgeTransferErrorMessage(
        error,
        nativeSymbol: nativeSymbol,
      );
      controller.setError(message);
      return <String, dynamic>{'ok': false, 'error': message};
    }
  }

  /// Personal-sign a message with the host EVM wallet on behalf of the mini
  /// app (SIWE-style sign-in). Always gated behind an explicit user approval
  /// dialog — the mini app never gets a silent signature.
  Future<Map<String, dynamic>> _handleSignMessageRequest(
    Map<String, dynamic> payload,
  ) async {
    final message = payload['message']?.toString() ?? '';
    if (message.trim().isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Missing message to sign.',
      };
    }
    // Keep the host safe from absurd payloads; SIWE nonce messages are short.
    if (message.length > 2000) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Message is too long to sign.',
      };
    }

    final activeAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.evm,
    );
    // Multi-wallet support: list every EVM-capable account so the user picks
    // which identity signs in (defaulting to the active wallet).
    final accounts = await _walletService.getWalletAccounts();
    final candidates = <MapEntry<String, String>>[]; // name -> evm address
    final seen = <String>{};
    for (final WalletAccount account in accounts) {
      final evm = account.addressesByFamily[ChainFamily.evm]?.trim();
      if (evm == null || evm.isEmpty) continue;
      if (!seen.add(evm.toLowerCase())) continue;
      candidates.add(MapEntry(account.name, evm));
    }
    if (candidates.isEmpty &&
        activeAddress != null &&
        activeAddress.trim().isNotEmpty) {
      candidates.add(MapEntry('Wallet', activeAddress));
    }
    if (candidates.isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'No EVM wallet is available in this Owllet account.',
      };
    }

    // When the mini app pinned an address (re-auth of a known account), it must
    // be one of this user's wallets — and we sign with exactly that one.
    final requestedAddress = payload['address']?.toString().trim() ?? '';
    String? pinned;
    if (requestedAddress.isNotEmpty) {
      pinned = candidates
          .where((c) => c.value.toLowerCase() == requestedAddress.toLowerCase())
          .map((c) => c.value)
          .firstOrNull;
      if (pinned == null) {
        return const <String, dynamic>{
          'ok': false,
          'error':
              'The requested address does not match any wallet in this Owllet account.',
        };
      }
    }

    final walletAddress = await _confirmSignMessage(
      message: message,
      candidates: pinned != null
          ? candidates
                .where((c) => c.value.toLowerCase() == pinned!.toLowerCase())
                .toList()
          : candidates,
      defaultAddress: pinned ?? activeAddress ?? candidates.first.value,
    );
    if (walletAddress == null || walletAddress.isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Signature request was declined.',
      };
    }

    try {
      final signature = await _walletService.signMessageForAddress(
        walletAddress,
        message,
      );
      final prefixed = signature.startsWith('0x') ? signature : '0x$signature';
      return <String, dynamic>{
        'ok': true,
        'signature': prefixed,
        'address': walletAddress,
      };
    } catch (error) {
      debugPrint('[MiniAppHost] sign-message failed: $error');
      return const <String, dynamic>{
        'ok': false,
        'error': 'Unable to sign with this wallet right now.',
      };
    }
  }

  Future<String?> _confirmSignMessage({
    required String message,
    required List<MapEntry<String, String>> candidates,
    required String defaultAddress,
  }) {
    final preview = message.length > 280
        ? '${message.substring(0, 280)}…'
        : message;
    String selected =
        candidates
            .where((c) => c.value.toLowerCase() == defaultAddress.toLowerCase())
            .map((c) => c.value)
            .firstOrNull ??
        candidates.first.value;
    String shorten(String address) => address.length > 12
        ? '${address.substring(0, 6)}…${address.substring(address.length - 4)}'
        : address;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Sign in to ${widget.definition.title}',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This mini app wants your wallet signature to sign you in. Signing is free and does not move any funds.',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.4,
                    ),
                  ),
                  if (candidates.length > 1) ...[
                    const SizedBox(height: 12),
                    Text(
                      'SIGN IN AS',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...candidates.map(
                      (candidate) => RadioListTile<String>(
                        value: candidate.value,
                        // ignore: deprecated_member_use
                        groupValue: selected,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.success,
                        // ignore: deprecated_member_use
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selected = value);
                          }
                        },
                        title: Text(
                          candidate.key,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          shorten(candidate.value),
                          style: GoogleFonts.robotoMono(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      preview,
                      style: GoogleFonts.robotoMono(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Surface a host (system) notification for the mini app — e.g. "your
  /// electricity token has arrived". Title is prefixed with the mini-app name
  /// so users always know the source.
  Future<Map<String, dynamic>> _handleNotifyRequest(
    Map<String, dynamic> payload,
  ) async {
    final title = payload['title']?.toString().trim() ?? '';
    if (title.isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Missing notification title.',
      };
    }
    final body = payload['body']?.toString().trim();
    await AppNotificationService().showLocal(
      title: '${widget.definition.title}: $title',
      body: body,
    );
    return const <String, dynamic>{'ok': true};
  }

  /// Execute a cross-chain swap/bridge requested by a mini app (e.g. cash-in's
  /// sell-any-token saga). The mini app supplies the provider (Relay) steps it
  /// got from its backend; we sign+broadcast them via the same path the wallet's
  /// own Bridge tab uses.
  ///
  /// SECURITY NOTE: like `requestWalletTransfer`, this signs transactions the
  /// mini app supplies, gated only by the user confirmation below — there is no
  /// per-step native-value bound here (the host has no quote to check against),
  /// so only first-party mini apps should advertise/use this capability.
  Future<Map<String, dynamic>> _handleCrossChainSwapRequest(
    Map<String, dynamic> payload,
  ) async {
    final steps = BridgeService.parseSteps(payload['relaySteps']);
    if (steps.isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'No swap steps to execute.',
      };
    }

    final fromSymbol = payload['fromAssetSymbol']?.toString() ?? '';
    final toSymbol = payload['toAssetSymbol']?.toString() ?? 'USDC';
    final fromAmount = payload['fromAmountDisplay']?.toString() ?? '';
    final toAmount = payload['toAmountDisplay']?.toString() ?? '';

    final confirmed = await _confirmCrossChainSwap(
      fromLabel: fromAmount.isEmpty ? fromSymbol : '$fromAmount $fromSymbol',
      toLabel: toAmount.isEmpty ? toSymbol : '$toAmount $toSymbol',
    );
    if (confirmed != true) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Swap was cancelled.',
      };
    }

    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.generic,
    );
    if (mounted) {
      unawaited(
        Navigator.of(context).pushNamed(
          '/transaction-processing',
          arguments: TransactionProcessingArguments(controller: controller),
        ),
      );
    }
    controller.setPreparing();
    controller.setSwapSubmitting();

    final bridgeService = BridgeService();
    final blockchain = context.read<BlockchainService>();
    String? firstTxHash;

    try {
      for (final step in steps) {
        if (step.isSolana) {
          final solanaContext = await bridgeService.getSolanaContext(
            lookupTableAddresses: step.lookupTableAddresses,
          );
          if (solanaContext == null) {
            final msg = bridgeService.lastError ??
                'Unable to prepare the Solana transaction.';
            controller.setError(msg);
            return <String, dynamic>{'ok': false, 'error': msg};
          }
          final solanaAddress = await _walletService.getWalletAddressForFamily(
            ChainFamily.solana,
          );
          if (solanaAddress == null || solanaAddress.trim().isEmpty) {
            const msg = 'This wallet does not support Solana.';
            controller.setError(msg);
            return const <String, dynamic>{'ok': false, 'error': msg};
          }
          final signedTx =
              await _walletService.buildAndSignSolanaBridgeTransaction(
            address: solanaAddress,
            recentBlockhash: solanaContext.blockhash,
            instructionsJson: step.instructionsJson!,
            lookupTablesJson: solanaContext.lookupTablesJson,
          );
          final signature = await bridgeService.broadcastSolanaTransaction(
            signedTransaction: signedTx,
          );
          if (signature == null) {
            final msg = bridgeService.lastError ??
                'Unable to broadcast the Solana transaction.';
            controller.setError(msg);
            return <String, dynamic>{'ok': false, 'error': msg};
          }
          firstTxHash ??= signature;
          controller.setSwapPending(reference: _shortHash(signature));
        } else {
          final chain = blockchain.allChains.firstWhere(
            (c) => c.chainId == step.chainId,
            orElse: () => blockchain.activeChain,
          );
          final txHash = await _walletService.sendRawTransactionRequest(
            rpcUrl: chain.rpcUrl,
            chainId: step.chainId,
            toAddress: step.to,
            valueInWei: step.value,
            dataHex: step.data,
          );
          firstTxHash ??= txHash;
          controller.setSwapPending(reference: _shortHash(txHash));
        }
      }

      controller.setSuccess(
        reference: firstTxHash != null ? _shortHash(firstTxHash) : null,
      );
      return <String, dynamic>{
        'ok': true,
        'transactionHash': firstTxHash,
        'confirmed': true,
      };
    } catch (e) {
      final msg = 'Swap failed: ${e.toString()}';
      controller.setError(msg);
      return <String, dynamic>{'ok': false, 'error': msg};
    }
  }

  Future<bool?> _confirmCrossChainSwap({
    required String fromLabel,
    required String toLabel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Confirm Swap',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Swap $fromLabel to $toLabel. You will sign the transaction(s) in your wallet to complete it.',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Swap',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmHiddenSettlementTransfer({
    required String reference,
    required String amountDisplay,
    required String assetSymbol,
    required String nativeSymbol,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Confirm Withdrawal',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Send $amountDisplay for withdrawal request $reference. Owllet will route the settlement address internally.${nativeSymbol.isEmpty ? '' : '\n\nNetwork fees are paid in $nativeSymbol.'}',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Send $assetSymbol',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _sendBridgeTransfer({
    required String networkKey,
    required ChainFamily family,
    required String fromAddress,
    required String toAddress,
    required BigInt amountBaseUnits,
    required Token token,
  }) async {
    final isNative =
        token.contractAddress == null || token.contractAddress!.isEmpty;
    switch (family) {
      case ChainFamily.solana:
        return _walletService.sendSolanaTransaction(
          fromAddress: fromAddress,
          toAddress: toAddress,
          amountLamports: amountBaseUnits,
          tokenMint: isNative ? null : token.contractAddress,
        );
      case ChainFamily.tron:
        return _walletService.sendTronTransaction(
          fromAddress: fromAddress,
          toAddress: toAddress,
          amount: amountBaseUnits,
          tokenContract: isNative ? null : token.contractAddress,
        );
      case ChainFamily.evm:
        final blockchain = context.read<BlockchainService>();
        final chain = _evmChainForNetwork(blockchain, networkKey);
        if (isNative) {
          return _walletService.sendNativeTransaction(
            toAddress: toAddress,
            amountInBaseUnits: amountBaseUnits,
            rpcUrl: chain.rpcUrl,
            chainId: chain.chainId,
          );
        }
        return _walletService.sendTokenTransaction(
          tokenAddress: token.contractAddress!,
          toAddress: toAddress,
          amountInBaseUnits: amountBaseUnits,
          rpcUrl: chain.rpcUrl,
          chainId: chain.chainId,
        );
    }
  }

  /// Turn a raw wallet-transfer failure into an actionable, chain-aware message.
  ///
  /// The crypto leg pays gas in the chain's native coin (e.g. BNB on BNB Smart
  /// Chain), so a wallet that holds the stablecoin but no native coin fails to
  /// broadcast. web3dart surfaces that as an `RPCError`, which the generic
  /// mapper collapses to "Wallet transfer failed" — hiding the real cause. Map
  /// the common gas/revert signatures explicitly before falling back.
  String _bridgeTransferErrorMessage(
    Object error, {
    required String nativeSymbol,
  }) {
    final lowered = error.toString().toLowerCase();
    final native = nativeSymbol.trim().isEmpty
        ? 'the network fee coin'
        : nativeSymbol.trim();

    final insufficientGas =
        lowered.contains('insufficient funds') ||
        lowered.contains('insufficient balance') ||
        lowered.contains('gas required exceeds') ||
        lowered.contains('cannot afford') ||
        (lowered.contains('not enough') && lowered.contains('gas'));
    if (insufficientGas) {
      return 'Not enough $native to pay the network fee. Add $native to this '
          'wallet to cover gas, then try the withdrawal again.';
    }

    if (lowered.contains('execution reverted') ||
        lowered.contains('transfer amount exceeds balance') ||
        lowered.contains('reverted')) {
      return 'The network rejected the transfer. Make sure you hold enough of '
          'the token plus $native for gas, then try again.';
    }

    return AppErrorUtils.userMessage(
      error,
      fallback: 'Wallet transfer failed. Please try again.',
    );
  }

  EvmChain _evmChainForNetwork(
    BlockchainService blockchain,
    String networkKey,
  ) {
    final chainId =
        NetworkKey.evmChainIdOf(networkKey) ?? blockchain.activeChain.chainId;
    return blockchain.allChains.firstWhere(
      (chain) => chain.chainId == chainId,
      orElse: () => blockchain.activeChain,
    );
  }

  bool _isValidAddressForFamily(String address, ChainFamily family) {
    switch (family) {
      case ChainFamily.evm:
        return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address);
      case ChainFamily.solana:
        return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address);
      case ChainFamily.tron:
        return RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(address);
    }
  }

  String? _transactionDetailsUrl(String hash, String networkKey) {
    switch (NetworkKey.familyOf(networkKey)) {
      case ChainFamily.solana:
        if (!RegExp(r'^[1-9A-HJ-NP-Za-km-z]{80,90}$').hasMatch(hash)) {
          return null;
        }
        return 'https://explorer.solana.com/tx/$hash';
      case ChainFamily.tron:
        if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) return null;
        return 'https://tronscan.org/#/transaction/$hash';
      case ChainFamily.evm:
        if (!RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(hash)) return null;
        final blockchain = context.read<BlockchainService>();
        final explorerUrl = _evmChainForNetwork(
          blockchain,
          networkKey,
        ).explorerUrl?.trim();
        if (explorerUrl == null || explorerUrl.isEmpty) return null;
        final normalized = explorerUrl.endsWith('/')
            ? explorerUrl.substring(0, explorerUrl.length - 1)
            : explorerUrl;
        return '$normalized/tx/$hash';
    }
  }

  String _shortHash(String hash) {
    if (hash.length <= 10) {
      return hash;
    }
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  /// Ensure the OS-level camera permission is held before granting the
  /// WebView's getUserMedia request. flutter_inappwebview grants the web origin
  /// but never requests the Android runtime permission, so we prompt natively.
  /// iOS/macOS WKWebView surfaces its own prompt (gated by the Info.plist
  /// NSCameraUsageDescription), so no runtime request is needed there.
  Future<bool> _ensureNativeCameraPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final granted = await _cameraPermissionChannel.invokeMethod<bool>(
        'ensureCameraPermission',
      );
      return granted ?? false;
    } catch (error) {
      debugPrint('[MiniAppHost] camera permission request failed: $error');
      return false;
    }
  }

  bool _isTrustedOrigin(Uri uri) {
    if (!isSupportedDiscoverWebUri(uri)) {
      return false;
    }
    final origin = normalizeOriginFromUri(uri);
    return _trustedOrigins.contains(origin);
  }

  /// Whether the webview's currently-loaded top-level URL is a trusted mini-app
  /// origin. Used as a fallback for camera permission when the permission
  /// request's own origin is empty/unreliable on some Android WebView builds —
  /// safe because shouldOverrideUrlLoading already guarantees only a trusted
  /// origin can be the top-level document.
  Future<bool> _isCurrentPageTrusted() async {
    final controller = _controller;
    if (controller == null) {
      return false;
    }
    try {
      final current = await controller.getUrl();
      return current != null && _isTrustedOrigin(current);
    } catch (_) {
      return false;
    }
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
