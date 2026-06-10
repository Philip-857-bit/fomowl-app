import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/chain.dart';
import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_backend_auth_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/transaction_monitor.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/in_app_link_router.dart';
import '../../screens/transaction/transaction_processing_screen.dart';
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

class _MiniAppHostScreenState extends State<MiniAppHostScreen> {
  static const String _handlerName = 'owlletMiniAppBridge';
  static const String _scriptGroup = 'owllet-mini-app';

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
          'requestSignMessage': true,
          'notify': true,
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
    requestWalletTransfer: function(payload) {
      return callHost({ type: 'request_wallet_transfer', payload: payload || {} });
    },
    requestSignMessage: function(payload) {
      return callHost({ type: 'request_sign_message', payload: payload || {} });
    },
    notify: function(payload) {
      return callHost({ type: 'notify', payload: payload || {} });
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
      default:
        return <String, dynamic>{
          'ok': false,
          'error': 'Unsupported bridge action: $type',
        };
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
            'Automatic conversion is not available in this app version. Select USDT or USDC and try again.',
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
      final message = AppErrorUtils.userMessage(
        error,
        fallback: 'Wallet transfer failed. Please try again.',
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

    final walletAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.evm,
    );
    if (walletAddress == null || walletAddress.trim().isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'No EVM wallet is available in this Owllet account.',
      };
    }

    // When the mini app pinned an address, it must match the host wallet —
    // otherwise the backend nonce wouldn't verify anyway.
    final requestedAddress = payload['address']?.toString().trim() ?? '';
    if (requestedAddress.isNotEmpty &&
        requestedAddress.toLowerCase() != walletAddress.toLowerCase()) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'The requested address does not match this Owllet wallet.',
      };
    }

    final approved = await _confirmSignMessage(message: message);
    if (approved != true) {
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

  Future<bool?> _confirmSignMessage({required String message}) {
    final preview = message.length > 280
        ? '${message.substring(0, 280)}…'
        : message;
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
