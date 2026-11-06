import 'dart:async';
import '../../widgets/bitcoin_capability_gate.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../config/app_environment.dart';
import '../../models/chain.dart';
import '../../models/wallet_account.dart';
import '../../models/network_entry.dart';
import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../services/auth_service.dart';
import '../../services/app_store_service.dart';
import '../../services/cashin_profile_auth_service.dart';
import '../../services/wallet_backend_auth_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/bitcoin/bitcoin_offramp_api.dart';
import '../../services/bitcoin/bitcoin_offramp_service.dart';
import '../../services/bitcoin/bitcoin_bill_api.dart';
import '../../services/bitcoin/bitcoin_bill_funding_service.dart';
import '../../services/bitcoin/bitcoin_broadcast_service.dart';
import '../../services/bitcoin/bitcoin_post_transaction_refresh.dart';
import '../../models/bitcoin_account_state.dart';
import '../../utils/bitcoin_amount_utils.dart';
import '../../services/wallet_vault_service.dart';
import '../../screens/wallet/bitcoin_transfer_confirmation_screen.dart';
import '../../utils/wallet_unlock_navigation.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../services/bridge_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/http_client_service.dart';
import '../../services/runtime_config_service.dart';
import '../../services/system_picker_guard.dart';
import '../../services/transaction_monitor.dart';
import '../../services/wallet_service.dart';
import '../../services/wallet_history_service.dart';
import '../../services/zerox_gasless_executor.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/in_app_link_router.dart';
import '../../utils/token_visibility_utils.dart';
import '../../services/token_visibility_service.dart';
import '../../screens/transaction/transaction_processing_screen.dart';
import '../discover/discover_url_utils.dart';
import 'mini_app_definition.dart';
import 'mini_app_registry.dart';
import 'burst_sign_in.dart';
import 'burst_account_session.dart';
import 'widgets/mini_app_identity_title.dart';

@visibleForTesting
bool bitcoinCashoutBridgeActionAllowed(String miniAppId, String type) =>
    OwlletMiniApps.isOwlletPayId(miniAppId) &&
    const {
      'close',
      'ready',
      'request_wallet_transfer',
      'request_bitcoin_bill_payment',
      'get_bitcoin_bill_payment_status',
      'get_balances',
      'get_network_balances',
      'request_switch_network',
    }.contains(type);

@visibleForTesting
bool cashinExecutionPlanIsUsable(
  Map<String, dynamic> plan, {
  required DateTime now,
  bool allowExpiredForSubmittedSteps = false,
}) {
  final expiresAt = DateTime.tryParse(plan['expiresAt']?.toString() ?? '');
  if (expiresAt == null) return false;
  if (expiresAt.isAfter(now.toUtc())) return true;
  if (!allowExpiredForSubmittedSteps) return false;
  return (plan['steps'] as List?)?.any(
        (step) => step is Map && step['status'] == 'submitted',
      ) ==
      true;
}

@visibleForTesting
bool cashinExecutionPlanIsTransfer(Map<String, dynamic> plan) {
  return plan['routeType']?.toString() == 'direct_settlement';
}

@visibleForTesting
Map<String, dynamic>? cashinInitialPreflightStep(
  List<Map<String, dynamic>> steps,
) {
  for (final step in steps) {
    // A submitted swap can have spent the input already. Confirm it before
    // checking the balance for any later settlement transfer.
    if (step['status'] == 'submitted') return null;
    final kind = step['kind']?.toString();
    if (kind == 'transaction' ||
        (kind == 'typedData' &&
            (step['payload'] as Map?)?['purpose'] == 'trade')) {
      return step;
    }
  }
  return null;
}

@visibleForTesting
(String, BigInt)? cashinPreflightTokenSpend(Map<String, dynamic> step) {
  final kind = step['kind']?.toString();
  final payload = step['payload'];
  if (payload is! Map) return null;
  final transfer = payload['type'] == 'erc20Transfer';
  final swap =
      (kind == 'transaction' && payload['transaction'] is Map) ||
      (kind == 'typedData' && payload['purpose'] == 'trade');
  if (!transfer && !swap) return null;

  final token =
      (transfer ? payload['token'] : payload['sellToken'])
          ?.toString()
          .trim()
          .toLowerCase() ??
      '';
  final amount = BigInt.tryParse(
    (transfer ? payload['amount'] : payload['sellAmount'])?.toString() ?? '',
  );
  final ceiling = BigInt.tryParse(step['amountCeiling']?.toString() ?? '');
  if (amount == null ||
      amount <= BigInt.zero ||
      ceiling == null ||
      ceiling < amount) {
    throw const FormatException('Invalid token spend limit in execution plan.');
  }
  if (transfer && step['expectedToken']?.toString().toLowerCase() != token) {
    throw const FormatException('Invalid token transfer plan.');
  }
  if (token == '0x0000000000000000000000000000000000000000' ||
      token == '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee') {
    return null;
  }
  if (!RegExp(r'^0x[0-9a-f]{40}$').hasMatch(token)) {
    throw const FormatException('Invalid token address in execution plan.');
  }
  return (token, ceiling);
}

@visibleForTesting
bool burstOperationAllowsSelector(String operation, String selector) {
  final normalized = selector.toLowerCase();
  return switch (operation) {
    'approve' => const {'095ea7b3', 'a22cb465'}.contains(normalized),
    'create' => const {'a4be8afd', 'fc50ee32'}.contains(normalized),
    'push' => const {'9ad88796', 'c78a7f37'}.contains(normalized),
    'set_root' => normalized == '7cb64759',
    _ => false,
  };
}

class _CashinExecutionPlanExpired implements Exception {
  const _CashinExecutionPlanExpired();
}

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

class MiniAppHostScreen extends StatelessWidget {
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
      _ => const MiniAppHostArguments(miniAppId: 'owllet_pay'),
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
  Widget build(BuildContext context) {
    final blockchain = context.watch<BlockchainService>();
    if (OwlletMiniApps.isOwlletPayId(definition.id) &&
        blockchain.activeNetworkKey == 'bitcoin:mainnet' &&
        blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet') &&
        blockchain.enabledFamilies.contains(ChainFamily.bitcoin) &&
        blockchain.activeWalletSupportedFamilies.contains(
          ChainFamily.bitcoin,
        )) {
      return _SupportedMiniAppHostScreen(
        definition: definition,
        launchSource: launchSource,
        initialUrl: initialUrl,
      );
    }
    return BitcoinCapabilityGate(
      feature: 'Mini apps and payments',
      builder: (_) => _SupportedMiniAppHostScreen(
        definition: definition,
        launchSource: launchSource,
        initialUrl: initialUrl,
      ),
    );
  }
}

class _SupportedMiniAppHostScreen extends StatefulWidget {
  final MiniAppDefinition definition;
  final String launchSource;
  final String? initialUrl;
  const _SupportedMiniAppHostScreen({
    required this.definition,
    required this.launchSource,
    this.initialUrl,
  });
  @override
  State<_SupportedMiniAppHostScreen> createState() => _MiniAppHostScreenState();
}

/// Build-time opt-in to expose the mini-app webview to remote inspectors on a
/// release build (debug builds are always inspectable). Set with
/// `--dart-define=OWLLET_WEBVIEW_INSPECTABLE=true` when you need to debug the
/// hosted website in a release artifact; defaults to false for production.
const bool _webviewInspectable = bool.fromEnvironment(
  'OWLLET_WEBVIEW_INSPECTABLE',
);

class _MiniAppHostScreenState extends State<_SupportedMiniAppHostScreen> {
  static const String _handlerName = 'owlletMiniAppBridge';
  static const String _scriptGroup = 'owllet-mini-app';
  static const MethodChannel _cameraPermissionChannel = MethodChannel(
    'owllet/camera_permission',
  );
  static const MethodChannel _receiptFilesChannel = MethodChannel(
    'owllet/receipt_files',
  );

  final AuthService _authService = AuthService();
  final WalletBackendAuthService _walletBackendAuthService =
      WalletBackendAuthService();
  final WalletService _walletService = WalletService();
  final WalletHistoryService _walletHistoryService = WalletHistoryService();
  final TransactionMonitor _transactionMonitor = TransactionMonitor();
  final RuntimeConfigService _runtimeConfig = RuntimeConfigService.instance;
  InAppWebViewController? _controller;
  int _progress = 0;
  bool _canGoBack = false;
  bool _loadingContext = true;
  bool _switchNetworkRequestInFlight = false;
  bool _bitcoinCashoutInFlight = false;
  bool _burstSessionFlowBusy = false;
  late final BurstAccountSessionService _burstAccountSession =
      BurstAccountSessionService(
        client: HttpClientService().client,
        api: AppEnvironment.api,
        readAccountToken: _authService.getToken,
        readIdentity: _readBurstIdentity,
        confirm: _confirmBurstConnection,
        authenticate: () async =>
            mounted &&
            await SensitiveAccessGuard.verify(
              context,
              reason: 'Connect this wallet to your Owllet account.',
            ),
        signMessage: _walletService.signMessageForAddress,
      );
  final BitcoinPostTransactionRefresh _bitcoinCashoutRefresh =
      BitcoinPostTransactionRefresh();
  late final BitcoinOfframpApi _bitcoinOfframpApi = BitcoinOfframpApi();
  late final BitcoinOfframpService _bitcoinOfframp = BitcoinOfframpService(
    fetchIntent: _bitcoinOfframpApi.fetchIntent,
    acknowledge: _bitcoinOfframpApi.acknowledge,
  );
  late final BitcoinBillApi _bitcoinBillApi = BitcoinBillApi();
  late final BitcoinBillFundingService _bitcoinBillFunding =
      BitcoinBillFundingService(
        fetchIntent: _bitcoinBillApi.fetchIntent,
        acknowledge: _bitcoinBillApi.acknowledge,
        acknowledgeReadOnly: _bitcoinBillApi.acknowledgeReadOnly,
      );
  Map<String, dynamic> _bridgeContext = const <String, dynamic>{};
  BlockchainService? _blockchain;
  String _publishedWalletAddress = '';
  String _publishedNetworkKey = '';
  bool _walletContextRefreshInFlight = false;
  bool _walletContextRefreshQueued = false;

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
    _runtimeConfig.addListener(_handleRuntimeConfigChanged);
    _prepareBridgeContext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = context.read<BlockchainService>();
    if (!identical(blockchain, _blockchain)) {
      _blockchain?.removeListener(_handleActiveWalletChange);
      _blockchain = blockchain;
      _blockchain?.addListener(_handleActiveWalletChange);
    }
  }

  @override
  void dispose() {
    _bitcoinCashoutRefresh.dispose();
    _blockchain?.removeListener(_handleActiveWalletChange);
    _runtimeConfig.removeListener(_handleRuntimeConfigChanged);
    // Don't leave the lock-on-background suppressed once the user leaves the
    // mini app; the guard is only meant to cover an in-flight capture here.
    SystemPickerGuard.clear();
    super.dispose();
  }

  void _handleRuntimeConfigChanged() {
    unawaited(
      _prepareBridgeContext().then((_) async {
        await _publishBridgeContext();
        await _publishRuntimeConfigChanged();
      }),
    );
  }

  void _handleActiveWalletChange() {
    if (!mounted) {
      return;
    }
    final nextAddress =
        _blockchain?.activeWalletAddress.trim().toLowerCase() ?? '';
    final nextNetworkKey = _blockchain?.activeNetworkKey ?? '';
    if (nextAddress.isEmpty ||
        (nextAddress == _publishedWalletAddress.toLowerCase() &&
            nextNetworkKey == _publishedNetworkKey)) {
      return;
    }
    unawaited(_refreshBridgeContextForActiveWallet());
  }

  Future<void> _refreshBridgeContextForActiveWallet() async {
    if (_walletContextRefreshInFlight) {
      _walletContextRefreshQueued = true;
      return;
    }
    _walletContextRefreshInFlight = true;
    try {
      do {
        _walletContextRefreshQueued = false;
        await _prepareBridgeContext();
        await _publishBridgeContext();
      } while (_walletContextRefreshQueued && mounted);
    } finally {
      _walletContextRefreshInFlight = false;
    }
  }

  Future<void> _prepareBridgeContext() async {
    final profile = await _authService.getCachedProfile();
    final isLoggedIn = await _authService.isLoggedIn();

    // Resolve the EVM wallet address from the wallet itself first â€” the most
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

    // The user's Solana address â€” needed by cross-chain flows (e.g. cash-in's
    // sell-any-token saga uses it as the USDC refund address). Best-effort.
    String? solanaWalletAddress;
    try {
      solanaWalletAddress = await _walletService.getWalletAddressForFamily(
        ChainFamily.solana,
      );
    } catch (_) {
      solanaWalletAddress = null;
    }
    String? tronWalletAddress;
    try {
      tronWalletAddress = await _walletService.getWalletAddressForFamily(
        ChainFamily.tron,
      );
    } catch (_) {
      tronWalletAddress = null;
    }

    // Surface the wallet-auth (ws_) session token to the mini-app so it can call
    // wallet-scoped backend endpoints (e.g. the affiliate dashboard) as the user.
    // For mini apps that require it we mint a session (signing silently with the
    // wallet key); otherwise we only surface a cached token to keep open fast.
    String? walletSessionToken;
    if (walletAddress != null &&
        !OwlletMiniApps.isOwlletPayId(widget.definition.id) &&
        widget.definition.id != 'burst') {
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
    var availableNetworks = const <Map<String, dynamic>>[];
    try {
      final blockchain = context.read<BlockchainService>();
      activeNetworkKey = blockchain.activeNetworkKey;
      availableNetworks = blockchain.networkEntries
          .map(
            (entry) => <String, dynamic>{
              'networkKey': entry.networkKey,
              'name': entry.name,
              'symbol': entry.identitySymbol,
              'logoUrl': entry.logoUrl,
              'chainFamily': entry.family.wireValue,
            },
          )
          .toList(growable: false);
      // networkKey is "<family>:<rest>" â€” e.g. "evm:56", "tron:mainnet".
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
      availableNetworks = const <Map<String, dynamic>>[];
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
    _publishedWalletAddress = walletAddress?.trim().toLowerCase() ?? '';
    _publishedNetworkKey = activeNetworkKey ?? '';
    setState(() {
      _bridgeContext = <String, dynamic>{
        'host': 'owllet-mobile',
        'hostInfo': <String, dynamic>{
          'name': 'owllet-mobile',
          'version': '1.1',
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
        'availableNetworks': availableNetworks,
        // Keep the wallet available at the context root as well as inside
        // profile/session. Older mini-app SDKs do not reliably expose nested
        // profile fields, while OwlletPay needs the EVM recipient for quotes.
        'walletAddress': walletAddress,
        'evmWalletAddress': walletAddress,
        'solanaWalletAddress': solanaWalletAddress,
        'tronWalletAddress': tronWalletAddress,
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
        'runtimePolicy': <String, dynamic>{
          'maintenanceMode': _runtimeConfig.snapshot.maintenanceMode,
          'portfolioEnabled': _runtimeConfig.snapshot.portfolioEnabled,
          'portfolioUiEnabled': _runtimeConfig.snapshot.portfolioUiEnabled,
          'scopedBalancesEnabled':
              _runtimeConfig.snapshot.scopedBalancesEnabled,
          'legacyAggregateEnabled':
              _runtimeConfig.snapshot.legacyAggregateEnabled,
          'refreshOnTransaction': _runtimeConfig.snapshot.refreshOnTransaction,
          'transfersEnabled': _runtimeConfig.snapshot.transfersEnabled,
          'swapsEnabled': _runtimeConfig.snapshot.swapsEnabled,
          'bridgesEnabled': _runtimeConfig.snapshot.bridgesEnabled,
          'miniAppsEnabled': _runtimeConfig.snapshot.miniAppsEnabled,
          'cashInEnabled': _runtimeConfig.snapshot.cashInEnabled,
          'cashOutEnabled': _runtimeConfig.snapshot.cashOutEnabled,
          'billsEnabled': _runtimeConfig.snapshot.billsEnabled,
          'shopEnabled': _runtimeConfig.snapshot.shopEnabled,
        },
        'tokenLogos': const <String, String>{
          'USDT':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xdAC17F958D2ee523a2206206994597C13D831ec7/logo.png',
          'USDC':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png',
          'ETH':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
          'BNB':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/smartchain/info/logo.png',
          'MATIC':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/polygon/info/logo.png',
          'POL':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/polygon/info/logo.png',
          'SOL':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/info/logo.png',
          'TRX':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/tron/info/logo.png',
          'BTC':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/binance/assets/BTCB-1DE/logo.png',
          'DAI':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x6B175474E89094C44Da98b954EedeAC495271d0F/logo.png',
          'AVAX':
              'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/avalanchec/info/logo.png',
        },
        'capabilities': <String, dynamic>{
          'getBitcoinBillPaymentStatus':
              OwlletMiniApps.isOwlletPayId(widget.definition.id) &&
              activeNetworkKey == 'bitcoin:mainnet',
          'requestBitcoinBillPayment':
              OwlletMiniApps.isOwlletPayId(widget.definition.id) &&
              activeNetworkKey == 'bitcoin:mainnet' &&
              _blockchain?.isBitcoinNetworkAvailable('bitcoin:mainnet') ==
                  true &&
              _blockchain?.enabledFamilies.contains(ChainFamily.bitcoin) ==
                  true &&
              _blockchain?.activeWalletSupportedFamilies.contains(
                    ChainFamily.bitcoin,
                  ) ==
                  true &&
              _runtimeConfig.snapshot.billsEnabled &&
              _runtimeConfig.snapshot.miniAppsEnabled &&
              _runtimeConfig.snapshot.transfersEnabled,
          'requestBitcoinCashout':
              OwlletMiniApps.isOwlletPayId(widget.definition.id) &&
              activeNetworkKey == 'bitcoin:mainnet' &&
              _blockchain?.isBitcoinNetworkAvailable('bitcoin:mainnet') ==
                  true &&
              _blockchain?.activeWalletSupportedFamilies.contains(
                    ChainFamily.bitcoin,
                  ) ==
                  true &&
              _blockchain?.enabledFamilies.contains(ChainFamily.bitcoin) ==
                  true &&
              _runtimeConfig.snapshot.miniAppsEnabled &&
              _runtimeConfig.snapshot.transfersEnabled,
          'ready': true,
          'close': true,
          'openExternal': true,
          'getContext': true,
          'requestWalletTransfer':
              _runtimeConfig.snapshot.miniAppsEnabled &&
              _runtimeConfig.snapshot.transfersEnabled,
          'requestSwapThenTransfer': false,
          'requestCrossChainSwap':
              activeChainFamily != 'bitcoin' &&
              _runtimeConfig.snapshot.miniAppsEnabled &&
              _runtimeConfig.snapshot.swapsEnabled &&
              _runtimeConfig.snapshot.bridgesEnabled,
          'requestContractTransaction':
              _runtimeConfig.snapshot.miniAppsEnabled &&
              _runtimeConfig.snapshot.transfersEnabled &&
              widget.definition.id == 'burst',
          'requestSignMessage': OwlletMiniApps.isOwlletPayId(widget.definition.id),
          'requestBurstSession': widget.definition.id == 'burst',
          'disconnectBurstSession': widget.definition.id == 'burst',
          'notify': true,
          'getBalances':
              _runtimeConfig.snapshot.portfolioEnabled &&
              _runtimeConfig.snapshot.scopedBalancesEnabled,
          'getNetworkBalances':
              _runtimeConfig.snapshot.portfolioEnabled &&
              _runtimeConfig.snapshot.scopedBalancesEnabled,
          'switchNetwork': true,
          'saveReceiptImage': true,
          'shareReceiptImage': true,
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
            _buildChrome(),
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
                  // (e.g. OwlletPay KYC selfie). Some Android WebView builds report
                  // an empty/null permission-request origin, which previously
                  // tripped the trust check and silently denied getUserMedia
                  // (NotAllowedError) even with the OS camera permission granted.
                  // Fall back to the CURRENTLY-LOADED page origin â€” that URL is
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
                  if (!_runtimeAllowsMiniAppUrl(next)) {
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

  Widget _buildChrome() {
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
                child: MiniAppIdentityTitle(
                  definition: widget.definition,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
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
  let context = $encodedContext;
  const callHost = function(payload) {
    return window.flutter_inappwebview.callHandler('$_handlerName', payload);
  };
  window.OwlletMiniApp = {
    version: '1.2',
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
    requestBitcoinBillPayment: function(payload) {
      return callHost({ type: 'request_bitcoin_bill_payment', payload: payload || {} });
    },
    getBitcoinBillPaymentStatus: function(payload) {
      return callHost({ type: 'get_bitcoin_bill_payment_status', payload: payload || {} });
    },
    requestCrossChainSwap: function(payload) {
      return callHost({ type: 'request_cross_chain_swap', payload: payload || {} });
    },
    requestContractTransaction: function(payload) {
      return callHost({ type: 'request_contract_transaction', payload: payload || {} });
    },
    requestSignMessage: function(payload) {
      return callHost({ type: 'request_sign_message', payload: payload || {} });
    },
    requestBurstSession: function(payload) {
      return callHost({ type: 'request_burst_session', payload: payload || {} });
    },
    disconnectBurstSession: function() {
      return callHost({ type: 'disconnect_burst_session' });
    },
    saveReceiptImage: function(payload) {
      return callHost({ type: 'save_receipt_image', payload: payload || {} });
    },
    shareReceiptImage: function(payload) {
      return callHost({ type: 'share_receipt_image', payload: payload || {} });
    },
    notify: function(payload) {
      return callHost({ type: 'notify', payload: payload || {} });
    },
    getBalances: function() {
      return callHost({ type: 'get_balances' });
    },
    getNetworkBalances: function(networkKey) {
      return callHost({ type: 'get_network_balances', payload: { networkKey: networkKey } });
    },
    switchNetwork: function(networkKey) {
      return callHost({ type: 'request_switch_network', payload: { networkKey: networkKey } });
    },
    __updateContext: function(nextContext) {
      context = nextContext || context;
      window.dispatchEvent(new CustomEvent('owllet:miniapp:context-changed', { detail: context }));
      window.dispatchEvent(new CustomEvent('owllet:miniapp:network-changed', { detail: context.activeNetworkKey }));
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
    final bitcoinCashoutAction = bitcoinCashoutBridgeActionAllowed(
      widget.definition.id,
      type,
    );
    if (!bitcoinCashoutAction &&
        type != 'close' &&
        (_blockchain?.activeFamily == ChainFamily.bitcoin ||
            raw['networkKey']?.toString().startsWith('bitcoin:') == true)) {
      return const {
        'ok': false,
        'error': 'Bitcoin mini app operations are not supported yet.',
      };
    }
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
        final storeUrl = AppStoreService.resolveOwlletStoreUrl(uri);
        if (storeUrl != null) {
          try {
            if (await launchUrl(
              storeUrl,
              mode: LaunchMode.externalApplication,
            )) {
              return const <String, dynamic>{'ok': true};
            }
          } catch (error) {
            debugPrint('[MiniAppHost] Could not open Google Play: $error');
          }
          return const <String, dynamic>{
            'ok': false,
            'error': 'Could not open Google Play on this device.',
          };
        }
        await _openExternal(uri);
        return const <String, dynamic>{'ok': true};
      case 'ready':
        return <String, dynamic>{'ok': true, 'context': _bridgeContext};
      case 'request_burst_session':
        final payload = raw['payload'];
        if (payload is! Map) {
          return const {
            'ok': false,
            'error': 'Invalid wallet connection request.',
          };
        }
        return _handleBurstSessionRequest(payload.cast<String, dynamic>());
      case 'disconnect_burst_session':
        if (widget.definition.id != 'burst' || !await _isCurrentPageTrusted()) {
          return const {
            'ok': false,
            'error': 'Wallet connection is unavailable.',
          };
        }
        try {
          await _burstAccountSession.disconnect();
          return const {'ok': true};
        } catch (error) {
          return {'ok': false, 'error': AppErrorUtils.userMessage(error)};
        }
      case 'request_wallet_transfer':
        if (!await _runtimeFeatureEnabled('transfer')) {
          return _runtimeFeatureDisabledResponse();
        }
        final payload = raw['payload'];
        if (payload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid wallet transfer request.',
          };
        }
        return _handleWalletTransferRequest(payload.cast<String, dynamic>());
      case 'request_bitcoin_bill_payment':
        if (!OwlletMiniApps.isOwlletPayId(widget.definition.id) ||
            !_runtimeConfig.snapshot.billsEnabled ||
            !await _runtimeFeatureEnabled('transfer')) {
          return _runtimeFeatureDisabledResponse();
        }
        final billPayload = raw['payload'];
        if (billPayload is! Map ||
            billPayload.length != 1 ||
            billPayload['reference'] is! String) {
          return const {
            'ok': false,
            'error': 'Invalid Bitcoin bill reference.',
          };
        }
        return _handleBitcoinBillPaymentRequest(
          billPayload.cast<String, dynamic>(),
        );
      case 'get_bitcoin_bill_payment_status':
        final statusPayload = raw['payload'];
        if (!OwlletMiniApps.isOwlletPayId(widget.definition.id) ||
            statusPayload is! Map ||
            statusPayload.length != 1 ||
            statusPayload['reference'] is! String) {
          return const {
            'ok': false,
            'error': 'Invalid Bitcoin bill reference.',
          };
        }
        return _handleBitcoinBillPaymentStatus(
          statusPayload['reference'] as String,
        );
      case 'request_cross_chain_swap':
        if (!await _runtimeFeatureEnabled('bridge')) {
          return _runtimeFeatureDisabledResponse();
        }
        final swapPayload = raw['payload'];
        if (swapPayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid cross-chain swap request.',
          };
        }
        return _handleCrossChainSwapRequest(
          swapPayload.cast<String, dynamic>(),
        );
      case 'request_contract_transaction':
        if (!await _runtimeFeatureEnabled('transfer')) {
          return _runtimeFeatureDisabledResponse();
        }
        final transactionPayload = raw['payload'];
        if (transactionPayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid contract transaction request.',
          };
        }
        return _handleContractTransactionRequest(
          transactionPayload.cast<String, dynamic>(),
        );
      case 'request_sign_message':
        final signPayload = raw['payload'];
        if (signPayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid sign-message request.',
          };
        }
        return _handleSignMessageRequest(signPayload.cast<String, dynamic>());
      case 'save_receipt_image':
      case 'share_receipt_image':
        final receiptPayload = raw['payload'];
        if (receiptPayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid receipt image request.',
          };
        }
        return _handleReceiptImageRequest(
          type == 'save_receipt_image'
              ? 'saveReceiptImage'
              : 'shareReceiptImage',
          receiptPayload.cast<String, dynamic>(),
        );
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
      case 'get_network_balances':
        final balancePayload = raw['payload'];
        if (balancePayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid network balances request.',
          };
        }
        return _handleGetNetworkBalancesRequest(
          balancePayload.cast<String, dynamic>(),
        );
      case 'request_switch_network':
        final switchPayload = raw['payload'];
        if (switchPayload is! Map) {
          return const <String, dynamic>{
            'ok': false,
            'error': 'Invalid switch-network request.',
          };
        }
        return _handleSwitchNetworkRequest(
          switchPayload.cast<String, dynamic>(),
        );
      default:
        return <String, dynamic>{
          'ok': false,
          'error': 'Unsupported bridge action: $type',
        };
    }
  }

  Future<bool> _runtimeFeatureEnabled(String feature) async {
    await _runtimeConfig.refresh();
    final policy = _runtimeConfig.snapshot;
    if (policy.fullMaintenance || policy.readOnly || !policy.miniAppsEnabled) {
      return false;
    }
    return switch (feature) {
      'transfer' => policy.transfersEnabled,
      'swap' => policy.swapsEnabled,
      'bridge' => policy.swapsEnabled && policy.bridgesEnabled,
      _ => false,
    };
  }

  Map<String, dynamic> _runtimeFeatureDisabledResponse() =>
      const <String, dynamic>{
        'ok': false,
        'error': 'This transaction feature is temporarily unavailable.',
      };

  /// Handles a `request_switch_network` bridge call from a mini-app.
  ///
  /// Shows a native confirmation sheet so the user is always in control.
  /// On approval the active network is updated globally, the bridge context
  /// is refreshed, and `{ ok: true, networkKey }` is returned to the caller.
  Future<Map<String, dynamic>> _handleSwitchNetworkRequest(
    Map<String, dynamic> payload,
  ) async {
    final networkKey = payload['networkKey']?.toString().trim() ?? '';
    if (networkKey.isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'networkKey is required.',
      };
    }

    if (!mounted) {
      return const <String, dynamic>{'ok': false, 'error': 'Host closed.'};
    }

    final blockchain = context.read<BlockchainService>();
    final requestedNetwork = blockchain.availableNetworkEntryForKey(networkKey);
    if (requestedNetwork == null) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'This network is not available for the active wallet.',
      };
    }
    if (_switchNetworkRequestInFlight) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'A network switch is already in progress.',
      };
    }
    if (blockchain.activeNetworkKey == requestedNetwork.networkKey) {
      return <String, dynamic>{
        'ok': true,
        'networkKey': requestedNetwork.networkKey,
      };
    }

    _switchNetworkRequestInFlight = true;
    try {
      // Show a native confirmation dialog â€” the user must explicitly approve.
      final approved = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _SwitchNetworkSheet(
          networkLabel: requestedNetwork.name,
          appName: widget.definition.title,
        ),
      );

      if (approved != true) {
        return const <String, dynamic>{'ok': false, 'error': 'User rejected.'};
      }

      if (!mounted) {
        return const <String, dynamic>{'ok': false, 'error': 'Host closed.'};
      }

      final switched = blockchain.trySetActiveNetworkKey(
        requestedNetwork.networkKey,
      );
      if (!switched) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'The wallet could not switch to that network.',
        };
      }

      // Refresh both Flutter's context and the already-running JS bridge.
      await _prepareBridgeContext();
      await _publishBridgeContext();

      return <String, dynamic>{
        'ok': true,
        'networkKey': blockchain.activeNetworkKey,
      };
    } catch (_) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'The network switch could not be completed.',
      };
    } finally {
      _switchNetworkRequestInFlight = false;
    }
  }

  Future<void> _publishBridgeContext() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final currentUri = (await controller.getUrl())?.uriValue;
    if (currentUri == null || !_isTrustedOrigin(currentUri)) {
      return;
    }
    final encodedContext = jsonEncode(_bridgeContext);
    await controller.evaluateJavascript(
      source: '''window.OwlletMiniApp?.__updateContext?.($encodedContext);''',
    );
  }

  Future<void> _publishRuntimeConfigChanged() async {
    if (!mounted) return;
    final detail = jsonEncode({
      'eventVersion': 1,
      'contextGeneration': _runtimeConfig.snapshot.revision,
      'policy': _bridgeContext['runtimePolicy'],
    });
    try {
      await _controller?.evaluateJavascript(
        source:
            'window.dispatchEvent(new CustomEvent("owllet:miniapp:runtime-config-changed", {detail: $detail}));',
      );
    } catch (_) {
      // The page may have navigated while policy propagation completed.
    }
  }

  /// Legacy balance bridge, intentionally limited to the active network. Older
  /// mini apps keep their response shape without triggering unrelated chain or
  /// aggregate portfolio discovery.
  Future<Map<String, dynamic>> _handleGetBalancesRequest() async {
    if (!_runtimeConfig.snapshot.portfolioEnabled ||
        !_runtimeConfig.snapshot.scopedBalancesEnabled) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Balances are currently disabled.',
        'balances': <Map<String, dynamic>>[],
      };
    }
    final activeNetworkKey =
        _bridgeContext['activeNetworkKey']?.toString() ?? '';
    if (activeNetworkKey.isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'The active network is unavailable.',
        'balances': <Map<String, dynamic>>[],
      };
    }
    final activeFamily = NetworkKey.familyOf(activeNetworkKey);
    final activeEvmChainId = NetworkKey.evmChainIdOf(activeNetworkKey);
    final activeSnapshot =
        activeFamily == ChainFamily.evm && activeEvmChainId != null
        ? await _fetchActiveEvmBridgeBalances(activeEvmChainId)
        : await _fetchNetworkBridgeBalances(activeFamily, activeNetworkKey);
    await _publishBalancesProgress(
      activeSnapshot.balances,
      walletAddress: activeSnapshot.walletAddress,
      networkKey: activeNetworkKey,
      complete: activeSnapshot.complete,
    );
    return <String, dynamic>{
      'ok': activeSnapshot.complete || activeSnapshot.balances.isNotEmpty,
      if (!activeSnapshot.complete)
        'error': 'Balances are temporarily unavailable.',
      'complete': activeSnapshot.complete,
      'balances': activeSnapshot.balances,
    };
  }

  /// Returns balances for exactly one host-approved network. This additive
  /// bridge method lets current mini apps avoid the legacy all-chain discovery
  /// path while older mini apps continue to use `getBalances` unchanged.
  Future<Map<String, dynamic>> _handleGetNetworkBalancesRequest(
    Map<String, dynamic> payload,
  ) async {
    if (!_runtimeConfig.snapshot.portfolioEnabled ||
        !_runtimeConfig.snapshot.scopedBalancesEnabled) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Scoped balances are currently disabled.',
        'balances': <Map<String, dynamic>>[],
      };
    }
    final networkKey = payload['networkKey']?.toString().trim() ?? '';
    final blockchain = context.read<BlockchainService>();
    if (networkKey.isEmpty ||
        blockchain.availableNetworkEntryForKey(networkKey) == null) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'This network is not available for the active wallet.',
        'balances': <Map<String, dynamic>>[],
      };
    }

    final family = NetworkKey.familyOf(networkKey);
    final chainId = NetworkKey.evmChainIdOf(networkKey);
    final snapshot = family == ChainFamily.evm && chainId != null
        ? await _fetchActiveEvmBridgeBalances(chainId)
        : await _fetchNetworkBridgeBalances(family, networkKey);
    await _publishBalancesProgress(
      snapshot.balances,
      walletAddress: snapshot.walletAddress,
      networkKey: networkKey,
      complete: snapshot.complete,
    );
    return <String, dynamic>{
      'ok': snapshot.complete || snapshot.balances.isNotEmpty,
      if (!snapshot.complete) 'error': 'Balances are temporarily unavailable.',
      'complete': snapshot.complete,
      'networkKey': networkKey,
      'balances': snapshot.balances,
    };
  }

  Future<
    ({
      String? walletAddress,
      List<Map<String, dynamic>> balances,
      bool complete,
    })
  >
  _fetchActiveEvmBridgeBalances(int chainId) async {
    final networkKey = 'evm:$chainId';
    final directSnapshot = await _fetchNetworkBridgeBalances(
      ChainFamily.evm,
      networkKey,
    );
    if (directSnapshot.balances.isEmpty) return directSnapshot;

    final hiddenTokens = await TokenVisibilityService().loadHiddenTokens(
      chainId,
    );
    if (hiddenTokens.isEmpty) return directSnapshot;
    final balances = directSnapshot.balances.where((balance) {
      final token = Token(
        symbol: balance['symbol']?.toString() ?? '',
        name: balance['name']?.toString() ?? '',
        contractAddress: balance['contractAddress']?.toString(),
        balance: (balance['balance'] as num?)?.toDouble() ?? 0,
        valueUsd: (balance['valueUsd'] as num?)?.toDouble() ?? 0,
        priceUsd: (balance['priceUsd'] as num?)?.toDouble() ?? 0,
        changePercent24h: 0,
        decimals: (balance['decimals'] as num?)?.toInt() ?? 18,
        isCertified: balance['isCertified'] == true,
        networkKey: networkKey,
      );
      return !TokenVisibilityUtils.contains(hiddenTokens, token);
    }).toList();
    return (
      walletAddress: directSnapshot.walletAddress,
      balances: balances,
      complete: directSnapshot.complete,
    );
  }

  Future<void> _publishBalancesProgress(
    List<Map<String, dynamic>> balances, {
    required String? walletAddress,
    String? networkKey,
    required bool complete,
  }) async {
    if (!mounted) {
      return;
    }
    final detailPayload = <String, dynamic>{
      'walletAddress': walletAddress,
      'balances': balances,
      'eventVersion': 1,
      'contextGeneration': _runtimeConfig.snapshot.revision,
      'complete': complete,
      'replacement': complete,
      'scope': {'walletAddress': walletAddress, 'networkKey': networkKey},
    };
    if (networkKey != null) {
      detailPayload['networkKey'] = networkKey;
    }
    final detail = jsonEncode(detailPayload);
    try {
      await _controller?.evaluateJavascript(
        source:
            'window.dispatchEvent(new CustomEvent("owllet:balances-progress", {detail: $detail}));'
            'window.dispatchEvent(new CustomEvent("owllet:miniapp:balances-changed", {detail: $detail}));',
      );
    } catch (_) {
      // The page may have navigated while the background refresh completed.
    }
  }

  /// Fetch one network's wallet token balances statelessly via the
  /// backend network-key wallet-tokens endpoint, normalized to the same shape
  /// as the EVM balances above. Best-effort: returns empty on any failure.
  Future<
    ({
      String? walletAddress,
      List<Map<String, dynamic>> balances,
      bool complete,
    })
  >
  _fetchNetworkBridgeBalances(ChainFamily family, String networkKey) async {
    if (family == ChainFamily.bitcoin) {
      final blockchain = _blockchain;
      final identity =
          blockchain?.activeWalletAddress.trim().toLowerCase() ?? '';
      bool current() =>
          mounted &&
          blockchain != null &&
          identity.isNotEmpty &&
          OwlletMiniApps.isOwlletPayId(widget.definition.id) &&
          networkKey == 'bitcoin:mainnet' &&
          blockchain.activeNetworkKey == networkKey &&
          blockchain.activeWalletAddress.trim().toLowerCase() == identity &&
          blockchain.isBitcoinNetworkAvailable(networkKey) &&
          blockchain.enabledFamilies.contains(ChainFamily.bitcoin) &&
          blockchain.activeWalletSupportedFamilies.contains(
            ChainFamily.bitcoin,
          ) &&
          _runtimeConfig.snapshot.miniAppsEnabled &&
          _runtimeConfig.snapshot.portfolioEnabled &&
          _runtimeConfig.snapshot.scopedBalancesEnabled;
      try {
        if (!current()) throw StateError('Bitcoin context unavailable');
        final snapshot = await _bitcoinOfframp.planner.wallet.refresh(
          identity,
          BitcoinProductNetwork.mainnet,
          isCurrent: current,
        );
        if (!current()) throw StateError('Bitcoin context changed');
        // SDK-compatible floating display value; exact sats remain authoritative.
        final balance = double.parse(
          BitcoinAmountUtils.format(snapshot.totalSats),
        );
        var price = 0.0;
        for (final token in blockchain!.tokens) {
          if (token.symbol == 'BTC' && token.unitPriceUsd > 0) {
            price = token.unitPriceUsd;
            break;
          }
        }
        return (
          walletAddress: identity,
          complete: true,
          balances: <Map<String, dynamic>>[
            {
              'networkKey': networkKey,
              'chainFamily': 'bitcoin',
              'symbol': 'BTC',
              'name': 'Bitcoin',
              'decimals': 8,
              'contractAddress': null,
              'balance': balance,
              'balanceBaseUnits': snapshot.totalSats.toString(),
              'priceUsd': price,
              'valueUsd': balance * price,
            },
          ],
        );
      } catch (_) {
        return (
          walletAddress: identity,
          complete: false,
          balances: const <Map<String, dynamic>>[],
        );
      }
    }
    final address = await _walletService.getWalletAddressForFamily(family);
    if (address == null || address.trim().isEmpty) {
      return (
        walletAddress: address,
        balances: const <Map<String, dynamic>>[],
        complete: false,
      );
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
        return (
          walletAddress: address,
          balances: const <Map<String, dynamic>>[],
          complete: false,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return (
          walletAddress: address,
          balances: const <Map<String, dynamic>>[],
          complete: false,
        );
      }
      final rawTokens = decoded['tokens'];
      if (rawTokens is! List) {
        return (
          walletAddress: address,
          balances: const <Map<String, dynamic>>[],
          complete: false,
        );
      }
      final defaultDecimals = family == ChainFamily.solana
          ? 9
          : family == ChainFamily.tron
          ? 6
          : 18;
      final result = <Map<String, dynamic>>[];
      for (final raw in rawTokens) {
        if (raw is! Map) continue;
        final token = raw.map((key, value) => MapEntry('$key', value));
        final symbol = (token['symbol'] as String?)?.trim() ?? '';
        final balance = (token['balance'] as num?)?.toDouble() ?? 0;
        if (symbol.isEmpty || balance <= 0) continue;
        final contractAddress = token['contractAddress'] as String?;
        final isCertified = token['isCertified'] == true;
        final valueUsd = (token['valueUsd'] as num?)?.toDouble() ?? 0;
        // The backend is the canonical spam filter. Price outages must not
        // erase a positive token balance from OwlletPay.
        result.add(<String, dynamic>{
          'symbol': symbol,
          'name': (token['name'] as String?) ?? symbol,
          'networkKey': networkKey,
          'chainFamily': family.wireValue,
          'contractAddress': contractAddress,
          'decimals': (token['decimals'] as num?)?.toInt() ?? defaultDecimals,
          'balance': balance,
          'valueUsd': valueUsd,
          'priceUsd': (token['priceUsd'] as num?)?.toDouble() ?? 0,
          'isCertified': isCertified,
          'imageUrl':
              (token['imageUrl'] as String?) ?? (token['logoUrl'] as String?),
          'logoUrl':
              (token['logoUrl'] as String?) ?? (token['imageUrl'] as String?),
        });
      }
      final snapshot = decoded['snapshot'];
      final discovery = decoded['discovery'];
      final completeness = snapshot is Map
          ? snapshot['completeness']?.toString()
          : null;
      final partialFailure =
          discovery is Map && discovery['partialFailure'] == true;
      return (
        walletAddress: address,
        balances: result,
        complete: completeness != 'partial' && !partialFailure,
      );
    } catch (error) {
      debugPrint('Mini-app getBalances: $networkKey fetch failed: $error');
      return (
        walletAddress: address,
        balances: const <Map<String, dynamic>>[],
        complete: false,
      );
    }
  }

  Future<Map<String, dynamic>> _handleContractTransactionRequest(
    Map<String, dynamic> payload,
  ) async {
    if (widget.definition.id != 'burst') {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Contract transactions are not enabled for this mini app.',
      };
    }
    final executionReference =
        payload['executionReference']?.toString().trim() ?? '';
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(executionReference)) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Invalid Burst execution reference.',
      };
    }
    final walletAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.evm,
    );
    if (walletAddress == null || walletAddress.trim().isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'This wallet does not support EVM transactions.',
      };
    }

    String? transactionHash;
    try {
      final preview = await _fetchBurstExecutionPlan(
        executionReference: executionReference,
        walletAddress: walletAddress,
      );
      final persistedStatus = preview['status']?.toString();
      final persistedHash = preview['transactionHash']?.toString() ?? '';
      if (persistedStatus == 'submitted' || persistedStatus == 'confirmed') {
        if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(persistedHash)) {
          throw const FormatException(
            'The submitted Burst transaction hash is invalid.',
          );
        }
        if (persistedStatus == 'confirmed') {
          return <String, dynamic>{
            'ok': true,
            'transactionHash': persistedHash,
            'confirmed': true,
            'pending': false,
          };
        }
        final transaction = _stringKeyedMap(preview['transaction']);
        final backendConfirmed = await _confirmBurstTransactionWithBackend(
          campaignId: preview['campaignId']!.toString(),
          operation: transaction['operation']!.toString(),
          transactionHash: persistedHash,
          walletAddress: walletAddress,
        );
        return <String, dynamic>{
          'ok': true,
          'transactionHash': persistedHash,
          'confirmed': backendConfirmed,
          'pending': !backendConfirmed,
        };
      }
      final previewTransaction = _validateBurstExecutionPlan(
        preview,
        executionReference: executionReference,
        walletAddress: walletAddress,
      );
      final approved = await _confirmBurstContractTransaction(
        campaignTitle: preview['campaignTitle']?.toString() ?? 'Burst campaign',
        assetSymbol: preview['assetSymbol']?.toString() ?? '',
        operation: previewTransaction['operation']!.toString(),
        valueBaseUnits: previewTransaction['valueBaseUnits']!.toString(),
        chainId: _requiredInt(previewTransaction, 'chainId'),
      );
      if (approved != true) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Burst transaction was cancelled.',
        };
      }
      if (!mounted) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Mini-app was closed before the transaction could start.',
        };
      }
      if (!await _runtimeFeatureEnabled('transfer')) {
        return _runtimeFeatureDisabledResponse();
      }

      // The user may leave the confirmation sheet open until the short-lived
      // plan expires. Reload it immediately before signing.
      final plan = await _fetchBurstExecutionPlan(
        executionReference: executionReference,
        walletAddress: walletAddress,
      );
      final transaction = _validateBurstExecutionPlan(
        plan,
        executionReference: executionReference,
        walletAddress: walletAddress,
      );
      if (!mounted) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Mini-app was closed before the transaction could start.',
        };
      }
      final chainId = _requiredInt(transaction, 'chainId');
      final blockchain = context.read<BlockchainService>();
      final chain = blockchain.allChains
          .where(
            (candidate) =>
                candidate.chainId == chainId &&
                candidate.family == ChainFamily.evm,
          )
          .firstOrNull;
      if (chain == null) {
        throw FormatException(
          'Required EVM network $chainId is not configured.',
        );
      }
      transactionHash = await _walletService.sendRawTransactionRequest(
        rpcUrl: chain.rpcUrl,
        chainId: chainId,
        expectedFromAddress: walletAddress,
        toAddress: transaction['toAddress']!.toString(),
        valueInWei: _parseBaseUnitValue(transaction['valueBaseUnits']),
        dataHex: transaction['calldata']!.toString(),
      );
      await _recordBurstTransaction(
        campaignId: plan['campaignId']!.toString(),
        operation: transaction['operation']!.toString(),
        transactionHash: transactionHash,
        walletAddress: walletAddress,
        confirm: false,
      );

      final confirmation = await _transactionMonitor.waitForConfirmation(
        txHash: transactionHash,
        blockchain: blockchain,
        networkKey: NetworkKey.evm(chainId),
        evmChain: chain,
      );
      if (confirmation == TransactionConfirmationStatus.failed) {
        return <String, dynamic>{
          'ok': false,
          'transactionHash': transactionHash,
          'error': 'The Burst transaction failed on-chain.',
        };
      }
      if (confirmation == TransactionConfirmationStatus.pending) {
        return <String, dynamic>{
          'ok': true,
          'transactionHash': transactionHash,
          'confirmed': false,
          'pending': true,
        };
      }

      final operation = transaction['operation']!.toString();
      final backendConfirmed = await _confirmBurstTransactionWithBackend(
        campaignId: plan['campaignId']!.toString(),
        operation: operation,
        transactionHash: transactionHash,
        walletAddress: walletAddress,
      );
      return <String, dynamic>{
        'ok': true,
        'transactionHash': transactionHash,
        'confirmed': backendConfirmed,
        'pending': !backendConfirmed,
      };
    } catch (error) {
      final message = AppErrorUtils.userMessage(error);
      if (transactionHash != null) {
        return <String, dynamic>{
          'ok': true,
          'transactionHash': transactionHash,
          'confirmed': false,
          'pending': true,
          'error': message,
        };
      }
      return <String, dynamic>{'ok': false, 'error': message};
    }
  }

  Future<Map<String, dynamic>> _fetchBurstExecutionPlan({
    required String executionReference,
    required String walletAddress,
  }) async {
    final auth = WalletBackendAuthService(walletService: _walletService);
    final response = await auth
        .sendAuthorized(
          walletAddress,
          (headers) => HttpClientService().client.get(
            AppEnvironment.api(
              '/burst/transactions/${Uri.encodeComponent(executionReference)}/execution',
            ),
            headers: headers,
          ),
          const <String, String>{'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeBackendBody(response.body);
    if (response.statusCode != 200) {
      throw FormatException(
        body['message']?.toString() ?? 'Burst transaction plan unavailable.',
      );
    }
    final data = body['data'];
    return data is Map ? _stringKeyedMap(data) : body;
  }

  Map<String, dynamic> _validateBurstExecutionPlan(
    Map<String, dynamic> plan, {
    required String executionReference,
    required String walletAddress,
  }) {
    if (plan['walletAddress']?.toString().toLowerCase() !=
        walletAddress.toLowerCase()) {
      throw const FormatException(
        'The Burst plan belongs to a different wallet.',
      );
    }
    final transaction = _stringKeyedMap(plan['transaction']);
    if (transaction['reference']?.toString() != executionReference) {
      throw const FormatException('The Burst execution reference changed.');
    }
    final expiresAt = DateTime.tryParse(
      transaction['expiresAt']?.toString() ?? '',
    );
    if (expiresAt == null ||
        !expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      throw const FormatException('The Burst transaction plan has expired.');
    }
    final chainId = _requiredInt(transaction, 'chainId');
    if (chainId <= 0) {
      throw const FormatException('Burst requires a valid EVM chain ID.');
    }
    final operation = transaction['operation']?.toString() ?? '';
    final toAddress = transaction['toAddress']?.toString() ?? '';
    final calldata = transaction['calldata']?.toString() ?? '';
    if (!_isEvmAddress(toAddress) ||
        !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(calldata) ||
        calldata.length.isOdd ||
        calldata.length < 10 ||
        !burstOperationAllowsSelector(operation, calldata.substring(2, 10))) {
      throw const FormatException('The Burst transaction plan is malformed.');
    }
    final value = _parseBaseUnitValue(transaction['valueBaseUnits']);
    if (value.bitLength > 256) {
      throw const FormatException('The Burst transaction value is too large.');
    }
    return transaction;
  }

  Future<void> _recordBurstTransaction({
    required String campaignId,
    required String operation,
    required String transactionHash,
    required String walletAddress,
    required bool confirm,
  }) async {
    final auth = _burstAccountSession;
    final response = await auth
        .sendAuthorized(
          walletAddress,
          (headers) => HttpClientService().client.post(
            AppEnvironment.api(
              '/burst/campaigns/${Uri.encodeComponent(campaignId)}/transactions/${Uri.encodeComponent(operation)}/${confirm ? 'confirm' : 'submit'}',
            ),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'transactionHash': transactionHash,
            }),
          ),
          const <String, String>{'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _decodeBackendBody(response.body);
      throw FormatException(
        body['message']?.toString() ?? 'Unable to update Burst transaction.',
      );
    }
  }

  Future<bool> _confirmBurstTransactionWithBackend({
    required String campaignId,
    required String operation,
    required String transactionHash,
    required String walletAddress,
  }) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final auth = _burstAccountSession;
      final response = await auth
          .sendAuthorized(
            walletAddress,
            (headers) => HttpClientService().client.post(
              AppEnvironment.api(
                '/burst/campaigns/${Uri.encodeComponent(campaignId)}/transactions/${Uri.encodeComponent(operation)}/confirm',
              ),
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode(<String, dynamic>{
                'transactionHash': transactionHash,
              }),
            ),
            const <String, String>{'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) return true;
      if (response.statusCode != 202) {
        final body = _decodeBackendBody(response.body);
        throw FormatException(
          body['message']?.toString() ?? 'Unable to confirm Burst transaction.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    return false;
  }

  Future<bool?> _confirmBurstContractTransaction({
    required String campaignTitle,
    required String assetSymbol,
    required String operation,
    required String valueBaseUnits,
    required int chainId,
  }) {
    final action = switch (operation) {
      'approve' => 'Approve token spending',
      'create' => 'Create Burst campaign',
      'push' => 'Deposit NFT inventory',
      'set_root' => 'Publish participant allocation',
      _ => 'Submit Burst transaction',
    };
    final valueLine = valueBaseUnits == '0'
        ? ''
        : '\n\nContract value: $valueBaseUnits wei';
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          action,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '$campaignTitle${assetSymbol.isEmpty ? '' : ' Â· $assetSymbol'}\nEVM network: $chainId$valueLine\n\nOwllet verified this transaction with the Burst backend. Review it before signing.',
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Review & sign'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _handleWalletTransferRequest(
    Map<String, dynamic> payload,
  ) async {
    if (_blockchain?.activeFamily == ChainFamily.bitcoin ||
        payload['networkKey']?.toString().startsWith('bitcoin:') == true) {
      return _handleBitcoinOfframpRequest(payload);
    }
    final requestedReference = payload['reference']?.toString().trim() ?? '';
    Map<String, dynamic> request = payload;
    if ((payload['toAddress']?.toString().trim() ?? '').isEmpty &&
        requestedReference.isNotEmpty) {
      try {
        request = await _fetchWithdrawalTransferPlan(requestedReference);
      } catch (error) {
        return <String, dynamic>{
          'ok': false,
          'error': AppErrorUtils.userMessage(error),
        };
      }
    }
    final reference = request['reference']?.toString().trim() ?? '';
    final action = request['action']?.toString().trim().toLowerCase();
    final networkKey = request['networkKey']?.toString().trim() ?? '';
    final symbol =
        request['assetSymbol']?.toString().trim().toUpperCase() ?? '';
    final assetName = request['assetName']?.toString().trim() ?? symbol;
    final toAddress = request['toAddress']?.toString().trim() ?? '';
    final amountDisplay = request['amountDisplay']?.toString().trim() ?? '';
    final nativeSymbol = request['nativeSymbol']?.toString().trim() ?? '';
    final amountBaseUnits = BigInt.tryParse(
      request['amountBaseUnits']?.toString() ?? '',
    );
    final decimals = int.tryParse(request['decimals']?.toString() ?? '') ?? 18;
    final tokenContract = request['tokenContract']?.toString().trim();

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
    if (!await _runtimeFeatureEnabled('transfer')) {
      return _runtimeFeatureDisabledResponse();
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
              ChainFamily.bitcoin => throw UnsupportedError(
                'Bitcoin is unavailable for this operation.',
              ),
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
      final confirmation = await _transactionMonitor.waitForConfirmation(
        txHash: txHash,
        blockchain: blockchain,
        networkKey: networkKey,
        evmChain: family == ChainFamily.evm
            ? _evmChainForNetwork(blockchain, networkKey)
            : null,
      );
      if (confirmation == TransactionConfirmationStatus.confirmed) {
        if (!OwlletMiniApps.isOwlletPayId(widget.definition.id)) {
          final historyChainId = switch (family) {
            ChainFamily.bitcoin => throw UnsupportedError(
              'Bitcoin is unavailable for this operation.',
            ),
            ChainFamily.solana => BridgeService.relaySolanaChainId,
            ChainFamily.tron => BridgeService.tronBridgeChainId,
            ChainFamily.evm => NetworkKey.evmChainIdOf(networkKey) ?? 0,
          };
          final historyNetworkName = switch (family) {
            ChainFamily.bitcoin => throw UnsupportedError(
              'Bitcoin is unavailable for this operation.',
            ),
            ChainFamily.solana => 'Solana',
            ChainFamily.tron => 'TRON',
            ChainFamily.evm =>
              blockchain.allChains
                  .firstWhere(
                    (chain) => chain.chainId == historyChainId,
                    orElse: () => blockchain.activeChain,
                  )
                  .name,
          };
          await _walletHistoryService.recordDappConfirmed(
            walletAddress: fromAddress,
            txHash: txHash,
            chainId: historyChainId,
            networkName: historyNetworkName,
            networkKey: networkKey,
            miniAppName: widget.definition.title,
            tokenName: assetName,
            tokenSymbol: symbol,
            amountText: amountDisplay,
            toAddress: toAddress,
          );
        }
        controller.setSuccess(
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
      } else if (confirmation == TransactionConfirmationStatus.failed) {
        controller.setError(
          'The transaction was confirmed as failed by the network.',
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
      }

      return <String, dynamic>{
        'ok': true,
        'transactionHash': txHash,
        'confirmed': confirmation == TransactionConfirmationStatus.confirmed,
        'pending': confirmation == TransactionConfirmationStatus.pending,
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

  Future<Map<String, dynamic>> _handleBitcoinOfframpRequest(
    Map<String, dynamic> payload,
  ) async {
    final blockchain = _blockchain;
    final identity = blockchain?.activeWalletAddress.trim().toLowerCase() ?? '';
    bool current() =>
        mounted &&
        blockchain != null &&
        OwlletMiniApps.isOwlletPayId(widget.definition.id) &&
        blockchain.activeNetworkKey == 'bitcoin:mainnet' &&
        blockchain.activeWalletAddress.trim().toLowerCase() == identity &&
        identity.isNotEmpty &&
        _runtimeConfig.snapshot.miniAppsEnabled &&
        _runtimeConfig.snapshot.transfersEnabled &&
        !_runtimeConfig.snapshot.fullMaintenance &&
        !_runtimeConfig.snapshot.readOnly &&
        blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet') &&
        blockchain.enabledFamilies.contains(ChainFamily.bitcoin) &&
        blockchain.activeWalletSupportedFamilies.contains(ChainFamily.bitcoin);
    if (!current() || _bitcoinCashoutInFlight) {
      return const {
        'ok': false,
        'error': 'Bitcoin cash-out is unavailable or already being reviewed.',
      };
    }
    _bitcoinCashoutInFlight = true;
    try {
      // Mini-app supplied destination, amount and network are never used to sign.
      final reference = payload['reference'] is String
          ? payload['reference'] as String
          : '';
      final prepared = await _bitcoinOfframp.prepare(
        identity,
        reference,
        isCurrent: current,
      );
      if (!mounted || !current()) {
        throw StateError('Bitcoin wallet context changed');
      }
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (confirmationContext) => BitcoinTransferConfirmationScreen(
            transfer: prepared.transfer,
            onConfirm: (_) async {
              final payment = await _bitcoinOfframp.execute(
                prepared,
                isCurrent: current,
                authenticate: () async {
                  await WalletVaultService.lockAll();
                  if (!current() || !confirmationContext.mounted) return false;
                  return await requestWalletUnlock(confirmationContext) &&
                      current();
                },
              );
              if (!confirmationContext.mounted) return;
              if (payment.outcome.status == BitcoinSubmissionStatus.accepted &&
                  current()) {
                _bitcoinCashoutRefresh.schedule(
                  isCurrent: current,
                  refresh: () =>
                      blockchain!.refreshBitcoinAccountAfterTransaction(
                        identity,
                        prepared.intent.network,
                        isCurrent: current,
                      ),
                );
                try {
                  await _walletHistoryService.recordBitcoinSend(
                    walletIdentity: identity,
                    txid: payment.outcome.txid,
                    network: prepared.intent.network,
                    amountSats: prepared.intent.amountSat,
                    recipient: prepared.intent.destination,
                  );
                } catch (_) {
                  // An optional history write never retries a submitted payment.
                }
              }
              if (!confirmationContext.mounted) return;
              Navigator.of(confirmationContext).pop(<String, dynamic>{
                'ok': true,
                'transactionHash': payment.outcome.txid,
                'submitted':
                    payment.outcome.status == BitcoinSubmissionStatus.accepted,
                'pending': true,
                'confirmed': false,
                'submissionUnknown':
                    payment.outcome.status == BitcoinSubmissionStatus.unknown,
                'backendAcknowledged': payment.backendAcknowledged,
                'fiatPayoutConfirmed': false,
              });
            },
          ),
        ),
      );
      return result ??
          const {
            'ok': false,
            'cancelled': true,
            'error': 'Transfer cancelled.',
          };
    } on BitcoinOfframpAlreadySubmitted catch (existing) {
      try {
        final recovery = await _bitcoinOfframp.recover(
          identity,
          existing.submission.intent.reference,
          isCurrent: current,
        );
        return {
          'ok': true,
          'transactionHash': recovery.submission.txid,
          'resolvedTransactionHash': recovery.observedTxid,
          'submitted': recovery.submission.accepted || recovery.status.found,
          'pending': !recovery.status.confirmed,
          'confirmed': recovery.status.confirmed,
          'submissionUnknown':
              !recovery.submission.accepted && !recovery.status.found,
          'backendAcknowledged': recovery.backendAcknowledged,
          'alreadySubmitted': true,
          'fiatPayoutConfirmed': false,
        };
      } catch (_) {
        // Observation failure cannot authorize another payment or erase its guard.
      }
      return {
        'ok': true,
        'transactionHash': existing.submission.txid,
        'submitted': existing.submission.accepted,
        'pending': true,
        'confirmed': false,
        'submissionUnknown': !existing.submission.accepted,
        'alreadySubmitted': true,
        'fiatPayoutConfirmed': false,
      };
    } catch (_) {
      return const {
        'ok': false,
        'error':
            'Unable to prepare Bitcoin cash-out. Check its saved payment status before trying again.',
      };
    } finally {
      _bitcoinCashoutInFlight = false;
    }
  }

  Future<Map<String, dynamic>> _handleBitcoinBillPaymentStatus(
    String reference,
  ) async {
    final blockchain = _blockchain;
    final identity = blockchain?.activeWalletAddress.trim().toLowerCase() ?? '';
    bool current() =>
        mounted &&
        blockchain != null &&
        identity.isNotEmpty &&
        OwlletMiniApps.isOwlletPayId(widget.definition.id) &&
        blockchain.activeNetworkKey == 'bitcoin:mainnet' &&
        blockchain.activeWalletAddress.trim().toLowerCase() == identity;
    if (!current()) {
      return const {'ok': false, 'error': 'Bitcoin wallet context changed.'};
    }
    try {
      // Observation and idempotent acknowledgement only. This never plans,
      // authenticates a signer, broadcasts, or releases an uncertain payment.
      final result = await _bitcoinBillFunding.recover(
        identity,
        reference,
        isCurrent: current,
      );
      return {
        'ok': true,
        'transactionHash': result.observedTxid,
        'confirmed': result.status.confirmed,
        'backendAcknowledged': result.backendAcknowledged,
      };
    } catch (_) {
      return const {
        'ok': false,
        'error': 'No confirmed saved bill payment is available.',
      };
    }
  }

  Future<Map<String, dynamic>> _handleBitcoinBillPaymentRequest(
    Map<String, dynamic> payload,
  ) async {
    final blockchain = _blockchain;
    final identity = blockchain?.activeWalletAddress.trim().toLowerCase() ?? '';
    bool current() =>
        mounted &&
        blockchain != null &&
        OwlletMiniApps.isOwlletPayId(widget.definition.id) &&
        blockchain.activeNetworkKey == 'bitcoin:mainnet' &&
        blockchain.activeWalletAddress.trim().toLowerCase() == identity &&
        identity.isNotEmpty &&
        _runtimeConfig.snapshot.billsEnabled &&
        _runtimeConfig.snapshot.miniAppsEnabled &&
        _runtimeConfig.snapshot.transfersEnabled &&
        !_runtimeConfig.snapshot.fullMaintenance &&
        !_runtimeConfig.snapshot.readOnly &&
        blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet') &&
        blockchain.enabledFamilies.contains(ChainFamily.bitcoin) &&
        blockchain.activeWalletSupportedFamilies.contains(ChainFamily.bitcoin);
    if (!current() || _bitcoinCashoutInFlight) {
      return const {
        'ok': false,
        'error':
            'Bitcoin bill payment is unavailable or already being reviewed.',
      };
    }
    _bitcoinCashoutInFlight = true;
    try {
      // Mini-app supplied destination, amount and network are never used to sign.
      final reference = payload['reference'] is String
          ? payload['reference'] as String
          : '';
      final prepared = await _bitcoinBillFunding.prepare(
        identity,
        reference,
        isCurrent: current,
      );
      if (!mounted || !current()) {
        throw StateError('Bitcoin wallet context changed');
      }
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (confirmationContext) => BitcoinTransferConfirmationScreen(
            transfer: prepared.transfer,
            billInvoice: prepared.intent,
            onConfirm: (_) async {
              final payment = await _bitcoinBillFunding.execute(
                prepared,
                isCurrent: current,
                authenticate: () async {
                  await WalletVaultService.lockAll();
                  if (!current() || !confirmationContext.mounted) return false;
                  return await requestWalletUnlock(confirmationContext) &&
                      current();
                },
              );
              if (!confirmationContext.mounted) return;
              if (payment.outcome.status == BitcoinSubmissionStatus.accepted &&
                  current()) {
                _bitcoinCashoutRefresh.schedule(
                  isCurrent: current,
                  refresh: () =>
                      blockchain!.refreshBitcoinAccountAfterTransaction(
                        identity,
                        prepared.intent.network,
                        isCurrent: current,
                      ),
                );
                try {
                  await _walletHistoryService.recordBitcoinSend(
                    walletIdentity: identity,
                    txid: payment.outcome.txid,
                    network: prepared.intent.network,
                    amountSats: prepared.intent.amountSat,
                    recipient: prepared.intent.destination,
                  );
                } catch (_) {
                  // An optional history write never retries a submitted payment.
                }
              }
              if (!confirmationContext.mounted) return;
              Navigator.of(confirmationContext).pop(<String, dynamic>{
                'ok': true,
                'transactionHash': payment.outcome.txid,
                'submitted':
                    payment.outcome.status == BitcoinSubmissionStatus.accepted,
                'pending': true,
                'confirmed': false,
                'submissionUnknown':
                    payment.outcome.status == BitcoinSubmissionStatus.unknown,
                'backendAcknowledged': payment.backendAcknowledged,
                'billDelivered': false,
              });
            },
          ),
        ),
      );
      return result ??
          const {
            'ok': false,
            'cancelled': true,
            'error': 'Transfer cancelled.',
          };
    } on BitcoinBillFundingAlreadySubmitted catch (existing) {
      try {
        final recovery = await _bitcoinBillFunding.recover(
          identity,
          existing.submission.intent.reference,
          isCurrent: current,
        );
        return {
          'ok': true,
          'transactionHash': recovery.submission.txid,
          'resolvedTransactionHash': recovery.observedTxid,
          'submitted': recovery.submission.accepted || recovery.status.found,
          'pending': !recovery.status.confirmed,
          'confirmed': recovery.status.confirmed,
          'submissionUnknown':
              !recovery.submission.accepted && !recovery.status.found,
          'backendAcknowledged': recovery.backendAcknowledged,
          'alreadySubmitted': true,
          'billDelivered': false,
        };
      } catch (_) {
        // Observation failure cannot authorize another payment or erase its guard.
      }
      return {
        'ok': true,
        'transactionHash': existing.submission.txid,
        'submitted': existing.submission.accepted,
        'pending': true,
        'confirmed': false,
        'submissionUnknown': !existing.submission.accepted,
        'alreadySubmitted': true,
        'billDelivered': false,
      };
    } catch (_) {
      return const {
        'ok': false,
        'error':
            'Unable to prepare Bitcoin bill payment. Check its saved payment status before trying again.',
      };
    } finally {
      _bitcoinCashoutInFlight = false;
    }
  }

  Future<Map<String, dynamic>> _fetchWithdrawalTransferPlan(
    String reference,
  ) async {
    final walletAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.evm,
    );
    if (walletAddress == null || walletAddress.trim().isEmpty) {
      throw const FormatException('Unable to authenticate this withdrawal.');
    }
    final auth = WalletBackendAuthService(walletService: _walletService);
    final response = await auth
        .sendAuthorized(
          walletAddress,
          (headers) => HttpClientService().client.get(
            AppEnvironment.api(
              '/cash-in/withdrawals/${Uri.encodeComponent(reference)}/wallet-transfer-plan',
            ),
            headers: headers,
          ),
          const <String, String>{'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeBackendBody(response.body);
    if (response.statusCode != 200) {
      throw FormatException(
        body['message']?.toString() ?? 'Unable to prepare this transfer.',
      );
    }
    final plan = _stringKeyedMap(body['data']);
    if (plan['reference']?.toString() != reference) {
      throw const FormatException('Withdrawal transfer reference mismatch.');
    }
    return plan;
  }

  /// OwlletPay SIWE compatibility: strict first-party scope and user approval.
  Future<Map<String, dynamic>> _handleSignMessageRequest(
    Map<String, dynamic> payload,
  ) async {
    // Only OwlletPay's trusted first-party page may request a SIWE signature.
    // Burst deliberately uses its separate account-bound native flow.
    if (!OwlletMiniApps.isOwlletPayId(widget.definition.id) ||
        !await _isCurrentPageTrusted()) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Wallet signing is unavailable for this mini app.',
      };
    }
    if (payload.keys.any((key) => !{'message', 'address'}.contains(key)) ||
        payload['message'] is! String ||
        (payload.containsKey('address') && payload['address'] is! String)) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Invalid wallet sign-in request.',
      };
    }
    final message = payload['message'] as String;
    if (!message.startsWith(
          'fomowl.app wants you to sign in with your Ethereum account:\n',
        ) ||
        !message.contains('Sign in to OwlletPay.') ||
        !message.contains('\nNonce: ') ||
        !message.contains('\nIssued At: ')) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Only OwlletPay sign-in challenges can be signed here.',
      };
    }
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

  Future<BurstSignInIdentity> _readBurstIdentity() async {
    final uri = await _controller?.getUrl();
    if (!mounted || uri == null || !_isTrustedOrigin(uri)) {
      throw const BurstConnectionFailure(
        'CONTEXT_CHANGED',
        'Burst is no longer on its trusted page.',
      );
    }
    final network = context.read<BlockchainService>().activeNetworkKey;
    final profile = await _authService.getCachedProfile();
    final wallet = await _walletService.getWalletAddressForFamily(
      ChainFamily.evm,
    );
    if (!network.startsWith('evm:') || wallet == null) {
      throw const BurstConnectionFailure(
        'EVM_REQUIRED',
        'Choose an EVM wallet and network in Owllet.',
      );
    }
    return BurstSignInIdentity(
      address: wallet,
      networkKey: network,
      origin: normalizeOriginFromUri(uri),
      profileId: profile?['id'] is String ? profile!['id'] as String : '',
    );
  }

  Future<bool> _confirmBurstConnection(String message, String address) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: const Text('Connect wallet to Burst'),
            content: SingleChildScrollView(
              child: Text(
                'Connect $address to your existing Owllet account. Your account stays the same when you change wallets. No transaction or gas fee.\n\n$message',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Connect'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _ensureBurstAccount({
    required bool interactive,
    required bool register,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      var token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        if (!interactive || !mounted) {
          throw const BurstConnectionFailure(
            'ACCOUNT_REQUIRED',
            'Sign in to your Owllet account.',
          );
        }
        final result = await Navigator.pushNamed(
          context,
          register ? '/profile-register' : '/profile-login',
        );
        if (result != true) {
          throw const BurstConnectionFailure(
            'ACCOUNT_REQUIRED',
            'Sign in to your Owllet account.',
          );
        }
        token = await _authService.getToken();
      }
      if (token == null || token.isEmpty) break;
      final response = await HttpClientService().client
          .get(
            AppEnvironment.profile('/me'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401) {
        await _authService.logout();
        if (!interactive) break;
        continue;
      }
      if (response.statusCode != 200) {
        throw const BurstConnectionFailure(
          'ACCOUNT_UNAVAILABLE',
          'Your Owllet account could not be verified. Try again.',
        );
      }
      final body = jsonDecode(response.body);
      final profile = body is Map ? (body['data'] ?? body) : null;
      if (profile is! Map<String, dynamic> || profile['id'] is! String) {
        throw const BurstConnectionFailure(
          'ACCOUNT_UNAVAILABLE',
          'Your Owllet account could not be verified.',
        );
      }
      await _authService.saveProfile(profile);
      return;
    }
    throw const BurstConnectionFailure(
      'ACCOUNT_REQUIRED',
      'Sign in to your Owllet account again.',
    );
  }

  Future<Map<String, dynamic>> _handleBurstSessionRequest(
    Map<String, dynamic> payload,
  ) async {
    if (widget.definition.id != 'burst' || !await _isCurrentPageTrusted()) {
      return const {
        'ok': false,
        'code': 'HOST_UNAVAILABLE',
        'error': 'Wallet connection is unavailable.',
      };
    }
    if (_burstSessionFlowBusy) {
      return const {
        'ok': false,
        'code': 'REQUEST_PENDING',
        'error': 'A wallet connection is already open.',
      };
    }
    if (payload.keys.any(
          (key) => !['interactive', 'selectWallet', 'register'].contains(key),
        ) ||
        payload.values.any((value) => value is! bool)) {
      return const {
        'ok': false,
        'code': 'INVALID_REQUEST',
        'error': 'Invalid wallet connection request.',
      };
    }
    _burstSessionFlowBusy = true;
    try {
      final interactive = payload['interactive'] == true;
      await _ensureBurstAccount(
        interactive: interactive,
        register: payload['register'] == true,
      );
      if (interactive && payload['selectWallet'] == true) {
        await _burstAccountSession.disconnect();
        if (!mounted) {
          throw const BurstConnectionFailure(
            'CONTEXT_CHANGED',
            'Burst was closed.',
          );
        }
        await Navigator.pushNamed(context, '/wallets');
      }
      if (!mounted) {
        throw const BurstConnectionFailure(
          'CONTEXT_CHANGED',
          'Burst was closed.',
        );
      }
      await _prepareBridgeContext();
      await _publishBridgeContext();
      final session = await _burstAccountSession.connect(
        interactive: interactive,
      );
      await _prepareBridgeContext();
      await _publishBridgeContext();
      return {'ok': true, ...session};
    } on BurstConnectionFailure catch (error) {
      if (mounted) {
        await _prepareBridgeContext();
        await _publishBridgeContext();
      }
      return {'ok': false, 'code': error.code, 'error': error.message};
    } catch (error) {
      return {
        'ok': false,
        'code': 'CONNECTION_FAILED',
        'error': AppErrorUtils.userMessage(error),
      };
    } finally {
      _burstSessionFlowBusy = false;
    }
  }

  /// Surface a host (system) notification for the mini app â€” e.g. "your
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

  /// Execute a cash-in route. New EVM sagas pass only an opaque execution
  /// reference; the native wallet fetches the authenticated plan itself. Legacy
  /// Relay steps remain available for existing and non-EVM sagas.
  Future<Map<String, dynamic>> _handleCrossChainSwapRequest(
    Map<String, dynamic> payload,
  ) async {
    final reference = payload['reference']?.toString().trim() ?? '';
    final executionReference =
        payload['executionReference']?.toString().trim() ?? '';
    if (reference.isNotEmpty && executionReference.isNotEmpty) {
      return _executeCashinExecutionPlan(
        payload: payload,
        reference: reference,
        executionReference: executionReference,
      );
    }

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

    final sameAsset =
        fromSymbol.trim().toUpperCase() == toSymbol.trim().toUpperCase();
    final confirmed = await _confirmCrossChainSwap(
      fromLabel: fromAmount.isEmpty ? fromSymbol : '$fromAmount $fromSymbol',
      toLabel: toAmount.isEmpty ? toSymbol : '$toAmount $toSymbol',
      reference: reference,
      stepCount: steps.length,
      isTransfer: sameAsset,
    );
    if (confirmed != true) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Swap was cancelled.',
      };
    }
    if (!await _runtimeFeatureEnabled('bridge')) {
      return _runtimeFeatureDisabledResponse();
    }
    if (!mounted) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Mini-app was closed before the swap could start.',
      };
    }

    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.generic,
    );
    unawaited(
      Navigator.of(context).pushNamed(
        '/transaction-processing',
        arguments: TransactionProcessingArguments(controller: controller),
      ),
    );
    controller.setPreparing();
    controller.setSwapSubmitting();

    final bridgeService = BridgeService();
    final blockchain = context.read<BlockchainService>();
    final requestId = payload['requestId']?.toString().trim() ?? '';
    String? firstTxHash;

    try {
      for (final step in steps) {
        if (step.isSolanaTransfer) {
          final solanaAddress = await _walletService.getWalletAddressForFamily(
            ChainFamily.solana,
          );
          if (solanaAddress == null || solanaAddress.trim().isEmpty) {
            const msg = 'This wallet does not support Solana.';
            controller.setError(msg);
            return const <String, dynamic>{'ok': false, 'error': msg};
          }
          final signature = await _walletService.sendSolanaTransaction(
            fromAddress: solanaAddress,
            toAddress: step.solanaTransferTo!,
            amountLamports: step.solanaTransferAmount!,
            tokenMint: step.solanaTokenMint,
          );
          firstTxHash ??= signature;
          controller.setSwapPending(reference: _shortHash(signature));
        } else if (step.isSolana) {
          final solanaContext = await bridgeService.getSolanaContext(
            lookupTableAddresses: step.lookupTableAddresses,
          );
          if (solanaContext == null) {
            final msg =
                bridgeService.lastError ??
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
          final signedTx = await _walletService
              .buildAndSignSolanaBridgeTransaction(
                address: solanaAddress,
                recentBlockhash: solanaContext.blockhash,
                instructionsJson: step.instructionsJson!,
                lookupTablesJson: solanaContext.lookupTablesJson,
              );
          final signature = await bridgeService.broadcastSolanaTransaction(
            signedTransaction: signedTx,
          );
          if (signature == null) {
            final msg =
                bridgeService.lastError ??
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

      if (requestId.startsWith('near:') && firstTxHash != null) {
        final notified = await bridgeService.submitNearDeposit(
          requestId: requestId,
          txHash: firstTxHash,
        );
        if (!notified) {
          final msg =
              bridgeService.lastError ??
              'Your deposit was sent, but Owllet could not continue delivery yet.';
          controller.setError(msg);
          return <String, dynamic>{
            'ok': false,
            'error': msg,
            'transactionHash': firstTxHash,
          };
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

  Future<Map<String, dynamic>> _executeCashinExecutionPlan({
    required Map<String, dynamic> payload,
    required String reference,
    required String executionReference,
  }) async {
    final walletAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.evm,
    );
    if (walletAddress == null || walletAddress.trim().isEmpty) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'This wallet does not support EVM transactions.',
      };
    }

    TransactionProgressController? progressController;
    try {
      var activeExecutionReference = executionReference;
      final previewPlan = await _fetchCashinExecutionPlan(
        reference: reference,
        executionReference: executionReference,
        walletAddress: walletAddress,
        // A broadcast ERC-20 approval can remain pending after its quote TTL.
        // It is safe to reload the plan only to wait for that submitted step;
        // the loop still rejects expired calldata before each new broadcast.
        allowExpiredForSubmittedSteps: true,
      );
      final rawSteps = previewPlan['steps'];
      if (rawSteps is! List || rawSteps.isEmpty) {
        throw const FormatException('The execution plan has no wallet steps.');
      }
      final previewSteps = rawSteps.map(_stringKeyedMap).toList(growable: false)
        ..sort(
          (a, b) => _requiredInt(
            a,
            'sequence',
          ).compareTo(_requiredInt(b, 'sequence')),
        );
      final actionablePreviewSteps = previewSteps
          .where(
            (step) =>
                step['status'] != 'confirmed' && step['status'] != 'skipped',
          )
          .toList(growable: false);
      if (actionablePreviewSteps.isEmpty) {
        return <String, dynamic>{
          'ok': true,
          'transactionHash': executionReference,
          'confirmed': true,
        };
      }

      for (final step in actionablePreviewSteps) {
        final kind = step['kind']?.toString();
        if (kind == 'approval' || kind == 'transaction') {
          _transactionForExecutionStep(step);
        }
      }

      if (!mounted) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Mini-app was closed before the balance check could start.',
        };
      }
      final blockchain = context.read<BlockchainService>();
      final initialSpendStep = cashinInitialPreflightStep(
        actionablePreviewSteps,
      );
      if (initialSpendStep != null) {
        await _preflightCashinExecutionBalance(
          blockchain: blockchain,
          walletAddress: walletAddress,
          steps: [initialSpendStep],
        );
      }
      if (!mounted) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Mini-app was closed before the swap could start.',
        };
      }

      // The authenticated execution plan is authoritative. A direct-settlement
      // route is a token transfer even if an older mini-app supplied stale or
      // mismatched display labels.
      final isDirectTransfer = cashinExecutionPlanIsTransfer(previewPlan);
      final confirmed = await _confirmCrossChainSwap(
        fromLabel: _swapLabel(payload, 'from'),
        toLabel: _swapLabel(payload, 'to'),
        reference: reference,
        stepCount: actionablePreviewSteps
            .where((step) => step['kind'] != 'providerSubmit')
            .length,
        isTransfer: isDirectTransfer,
      );
      if (confirmed != true) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Swap was cancelled.',
        };
      }
      if (!await _runtimeFeatureEnabled('bridge')) {
        return _runtimeFeatureDisabledResponse();
      }
      if (!mounted) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Mini-app was closed before the swap could start.',
        };
      }

      // The confirmation dialog is user-controlled and may remain open beyond
      // the short route TTL. Fetch a new authoritative plan after confirmation
      // and before any signing or broadcast.
      late final Map<String, dynamic> plan;
      try {
        plan = await _fetchCashinExecutionPlan(
          reference: reference,
          executionReference: activeExecutionReference,
          walletAddress: walletAddress,
        );
      } on _CashinExecutionPlanExpired {
        final refreshed = await _refreshCashinExecutionPlan(
          reference: reference,
          walletAddress: walletAddress,
        );
        activeExecutionReference = refreshed.$1;
        plan = refreshed.$2;
      }
      final refreshedRawSteps = plan['steps'];
      if (refreshedRawSteps is! List || refreshedRawSteps.isEmpty) {
        throw const FormatException('The execution plan has no wallet steps.');
      }
      final allSteps =
          refreshedRawSteps.map(_stringKeyedMap).toList(growable: false)..sort(
            (a, b) => _requiredInt(
              a,
              'sequence',
            ).compareTo(_requiredInt(b, 'sequence')),
          );
      final steps = allSteps
          .where(
            (step) =>
                step['status'] != 'confirmed' && step['status'] != 'skipped',
          )
          .toList(growable: false);
      if (steps.isEmpty) {
        return <String, dynamic>{
          'ok': true,
          'transactionHash': activeExecutionReference,
          'confirmed': true,
        };
      }
      if (!mounted) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Mini-app was closed before the swap could start.',
        };
      }

      final controller = TransactionProgressController(
        flow: TransactionProgressFlow.generic,
      );
      progressController = controller;
      unawaited(
        Navigator.of(context).pushNamed(
          '/transaction-processing',
          arguments: TransactionProcessingArguments(controller: controller),
        ),
      );
      controller.setPreparing();
      controller.setSwapSubmitting();

      ZeroXGaslessSignedOrder? gaslessOrder;
      // Re-sign the typed data after an app restart when the provider-submit
      // step is still pending. Signatures are deliberately never persisted.
      final typedSteps = allSteps
          .where((step) => step['kind'] == 'typedData')
          .toList(growable: false);
      if (typedSteps.isNotEmpty) {
        final approvalStep = typedSteps
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (step) => _stepPayload(step!)['purpose'] == 'approval',
              orElse: () => null,
            );
        final tradeStep = typedSteps.cast<Map<String, dynamic>?>().firstWhere(
          (step) => _stepPayload(step!)['purpose'] == 'trade',
          orElse: () => null,
        );
        if (tradeStep == null) {
          throw const FormatException('The gasless trade step is missing.');
        }
        final quoteData = <String, dynamic>{
          'trade': _gaslessSource(_stepPayload(tradeStep)),
        };
        if (approvalStep != null) {
          quoteData['approval'] = _gaslessSource(_stepPayload(approvalStep));
        }
        gaslessOrder = await ZeroXGaslessExecutor(walletService: _walletService)
            .signOrder(
              quoteData: quoteData,
              chainId: _requiredInt(tradeStep, 'chainId'),
            );
      }

      String? firstTxHash;
      for (final plannedStep in steps) {
        final stepId = plannedStep['stepId']?.toString() ?? '';
        var persistedStatus = plannedStep['status']?.toString();
        if (persistedStatus == 'failed') {
          throw const FormatException(
            'A previous wallet transaction failed. Refresh the execution plan before trying again.',
          );
        }
        if (persistedStatus == 'submitted') {
          await _waitForCashinExecutionStepConfirmation(
            reference: reference,
            executionReference: activeExecutionReference,
            walletAddress: walletAddress,
            stepId: stepId,
          );
          continue;
        }
        // Previous steps may take long enough to consume the plan TTL. Reload
        // immediately before every new wallet action so stale calldata is
        // never signed or broadcast.
        final currentPlan = await _fetchCashinExecutionPlan(
          reference: reference,
          executionReference: activeExecutionReference,
          walletAddress: walletAddress,
        );
        final currentSteps = currentPlan['steps'];
        if (currentSteps is! List) {
          throw const FormatException(
            'The execution plan has no wallet steps.',
          );
        }
        final step = currentSteps
            .map(_stringKeyedMap)
            .where((candidate) => candidate['stepId']?.toString() == stepId)
            .firstOrNull;
        if (step == null) {
          throw const FormatException(
            'The execution step is no longer available. Refresh the plan.',
          );
        }
        persistedStatus = step['status']?.toString();
        if (persistedStatus == 'confirmed' || persistedStatus == 'skipped') {
          continue;
        }
        if (persistedStatus == 'submitted') {
          await _waitForCashinExecutionStepConfirmation(
            reference: reference,
            executionReference: activeExecutionReference,
            walletAddress: walletAddress,
            stepId: stepId,
          );
          continue;
        }
        if (persistedStatus == 'failed') {
          throw const FormatException(
            'A previous wallet transaction failed. Refresh the execution plan before trying again.',
          );
        }
        final kind = step['kind']?.toString();
        final chainId = _requiredInt(step, 'chainId');
        String? transactionHash;
        String? signedPayload;
        if (kind == 'approval' ||
            kind == 'transaction' ||
            kind == 'typedData') {
          await _preflightCashinExecutionBalance(
            blockchain: blockchain,
            walletAddress: walletAddress,
            steps: [step],
          );
        }
        if (kind == 'approval' || kind == 'transaction') {
          final chain = blockchain.allChains
              .where((candidate) => candidate.chainId == chainId)
              .firstOrNull;
          if (chain == null || chain.family != ChainFamily.evm) {
            throw FormatException(
              'Required EVM network $chainId is not configured.',
            );
          }
          final tx = _transactionForExecutionStep(step);
          transactionHash = await _walletService.sendRawTransactionRequest(
            rpcUrl: chain.rpcUrl,
            chainId: chainId,
            toAddress: tx.$1,
            valueInWei: tx.$2,
            dataHex: tx.$3,
          );
          firstTxHash ??= transactionHash;
          controller.setSwapPending(reference: _shortHash(transactionHash));
        } else if (kind == 'typedData') {
          final purpose = _stepPayload(step)['purpose']?.toString();
          final signature = purpose == 'approval'
              ? gaslessOrder?.approvalSignature
              : gaslessOrder?.tradeSignature;
          if (signature == null) {
            throw FormatException(
              'Missing signature for gasless $purpose step.',
            );
          }
          signedPayload = jsonEncode(<String, dynamic>{'signature': signature});
        } else if (kind == 'providerSubmit') {
          if (gaslessOrder == null) {
            throw const FormatException('The gasless order was not signed.');
          }
          signedPayload = jsonEncode(gaslessOrder.payload);
        } else if (kind == 'waitForConfirmation') {
          continue;
        } else {
          throw FormatException('Unsupported execution step: $kind.');
        }
        await _submitCashinExecutionStep(
          reference: reference,
          walletAddress: walletAddress,
          step: step,
          transactionHash: transactionHash,
          signedPayload: signedPayload,
        );
        if (kind == 'approval' || kind == 'transaction') {
          await _waitForCashinExecutionStepConfirmation(
            reference: reference,
            executionReference: activeExecutionReference,
            walletAddress: walletAddress,
            stepId: stepId,
          );
        }
      }

      controller.setSuccess(
        reference: firstTxHash == null ? reference : _shortHash(firstTxHash),
      );
      return <String, dynamic>{
        'ok': true,
        'transactionHash': firstTxHash ?? activeExecutionReference,
        'confirmed': true,
      };
    } catch (error) {
      final message = 'Swap failed: ${AppErrorUtils.userMessage(error)}';
      progressController?.setError(message);
      return <String, dynamic>{'ok': false, 'error': message};
    }
  }

  Future<Map<String, dynamic>> _fetchCashinExecutionPlan({
    required String reference,
    required String executionReference,
    required String walletAddress,
    bool allowExpiredForSubmittedSteps = false,
  }) async {
    // Cash-in endpoints require the profile JWT (not the ws_ settings token).
    final auth = CashinProfileAuthService(walletService: _walletService);
    final response = await auth
        .sendAuthorized(
          walletAddress,
          (headers) => HttpClientService().client.get(
            AppEnvironment.api(
              '/cash-in/cashin/execution/${Uri.encodeComponent(reference)}',
            ),
            headers: headers,
          ),
          const <String, String>{'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeBackendBody(response.body);
    if (response.statusCode != 200) {
      throw FormatException(
        body['message']?.toString() ?? 'Execution plan unavailable.',
      );
    }
    final data = _stringKeyedMap(body['data']);
    final execution = _stringKeyedMap(data['execution']);
    final plan = _stringKeyedMap(execution['plan']);
    if (plan['routeId']?.toString() != executionReference ||
        execution['reference']?.toString() != executionReference) {
      throw const FormatException(
        'The execution reference does not match the saga.',
      );
    }
    if (!cashinExecutionPlanIsUsable(
      plan,
      now: DateTime.now().toUtc(),
      allowExpiredForSubmittedSteps: allowExpiredForSubmittedSteps,
    )) {
      throw const _CashinExecutionPlanExpired();
    }
    return plan;
  }

  Future<(String, Map<String, dynamic>)> _refreshCashinExecutionPlan({
    required String reference,
    required String walletAddress,
  }) async {
    // Cash-in endpoints require the profile JWT (not the ws_ settings token).
    final auth = CashinProfileAuthService(walletService: _walletService);
    final response = await auth
        .sendAuthorized(
          walletAddress,
          (headers) => HttpClientService().client.post(
            AppEnvironment.api(
              '/cash-in/cashin/execution/${Uri.encodeComponent(reference)}/refresh',
            ),
            headers: headers,
          ),
          const <String, String>{'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    final body = _decodeBackendBody(response.body);
    if (response.statusCode != 200) {
      throw FormatException(
        body['message']?.toString() ?? 'Unable to refresh the execution plan.',
      );
    }
    final data = _stringKeyedMap(body['data']);
    final execution = _stringKeyedMap(data['execution']);
    final plan = _stringKeyedMap(execution['plan']);
    final executionReference = execution['reference']?.toString() ?? '';
    if (executionReference.isEmpty ||
        plan['routeId']?.toString() != executionReference ||
        !cashinExecutionPlanIsUsable(plan, now: DateTime.now().toUtc())) {
      throw const FormatException(
        'The refreshed execution plan is invalid or already expired.',
      );
    }
    debugPrint('[MiniAppHost] refreshed expired cash-in execution plan');
    return (executionReference, plan);
  }

  Future<void> _waitForCashinExecutionStepConfirmation({
    required String reference,
    required String executionReference,
    required String walletAddress,
    required String stepId,
  }) async {
    if (stepId.isEmpty) {
      throw const FormatException('The execution step reference is missing.');
    }
    for (var attempt = 0; attempt < 60; attempt++) {
      final plan = await _fetchCashinExecutionPlan(
        reference: reference,
        executionReference: executionReference,
        walletAddress: walletAddress,
        allowExpiredForSubmittedSteps: true,
      );
      final rawSteps = plan['steps'];
      if (rawSteps is! List) {
        throw const FormatException('The execution plan has no wallet steps.');
      }
      final current = rawSteps
          .map(_stringKeyedMap)
          .where((step) => step['stepId']?.toString() == stepId)
          .firstOrNull;
      final status = current?['status']?.toString();
      if (status == 'confirmed' || status == 'skipped') return;
      if (status == 'failed') {
        throw const FormatException(
          'The wallet transaction failed. Refresh the execution plan and try again.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw const FormatException(
      'The wallet transaction is still confirming. You can safely reopen this request later.',
    );
  }

  Future<void> _submitCashinExecutionStep({
    required String reference,
    required String walletAddress,
    required Map<String, dynamic> step,
    String? transactionHash,
    String? signedPayload,
  }) async {
    final payload = <String, dynamic>{
      'stepId': step['stepId'],
      'walletAddress': walletAddress,
      'chainId': _requiredInt(step, 'chainId'),
      if (step['expectedTransactionTo'] != null)
        'transactionTo': step['expectedTransactionTo'],
      if (step['expectedRecipient'] != null)
        'recipient': step['expectedRecipient'],
      if (step['expectedToken'] != null) 'token': step['expectedToken'],
      if (step['amountCeiling'] != null) 'amount': step['amountCeiling'],
      if (step['approvalSpender'] != null)
        'approvalSpender': step['approvalSpender'],
      if (step['maxTransactionValue'] != null)
        'transactionValue': step['maxTransactionValue'],
    };
    if (transactionHash != null) {
      payload['transactionHash'] = transactionHash;
    }
    if (signedPayload != null) {
      payload['signedPayload'] = signedPayload;
    }
    // Cash-in endpoints require the profile JWT (not the ws_ settings token).
    final auth = CashinProfileAuthService(walletService: _walletService);
    final response = await auth
        .sendAuthorized(
          walletAddress,
          (headers) => HttpClientService().client.post(
            AppEnvironment.api(
              '/cash-in/cashin/execution/${Uri.encodeComponent(reference)}/submit',
            ),
            headers: headers,
            body: jsonEncode(payload),
          ),
          const <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _decodeBackendBody(response.body);
      throw FormatException(
        body['message']?.toString() ?? 'Step submission failed.',
      );
    }
  }

  Future<void> _preflightCashinExecutionBalance({
    required BlockchainService blockchain,
    required String walletAddress,
    required List<Map<String, dynamic>> steps,
  }) async {
    final onActiveChain = steps.where(
      (step) => _requiredInt(step, 'chainId') == blockchain.activeChain.chainId,
    );
    final tokenRequirements = <String, BigInt>{};
    var nativeRequired = BigInt.zero;
    for (final step in onActiveChain) {
      final spend = cashinPreflightTokenSpend(step);
      if (spend != null) {
        final key = spend.$1;
        final current = tokenRequirements[key] ?? BigInt.zero;
        if (spend.$2 > current) tokenRequirements[key] = spend.$2;
      }
      final value = BigInt.tryParse(
        step['maxTransactionValue']?.toString() ?? '',
      );
      if (value != null && value > nativeRequired) nativeRequired = value;
    }

    for (final requirement in tokenRequirements.entries) {
      final available = await blockchain.getTokenBalanceBaseUnits(
        walletAddress,
        requirement.key,
      );
      if (available < requirement.value) {
        throw const FormatException(
          'Insufficient token balance for this OwlletPay withdrawal. Lower the amount or top up before continuing.',
        );
      }
    }
    if (nativeRequired > BigInt.zero) {
      final available = await blockchain.getNativeBalanceBaseUnits(
        walletAddress,
      );
      if (available < nativeRequired) {
        throw FormatException(
          'Insufficient ${blockchain.activeNetworkSymbol} balance for this OwlletPay withdrawal and network fees.',
        );
      }
    }
  }

  (String, BigInt, String) _transactionForExecutionStep(
    Map<String, dynamic> step,
  ) {
    final payload = _stepPayload(step);
    final expectedTo = step['expectedTransactionTo']?.toString() ?? '';
    if (payload['type'] == 'erc20Transfer') {
      final recipient = payload['recipient']?.toString() ?? '';
      final amount = BigInt.tryParse(payload['amount']?.toString() ?? '');
      if (!_isEvmAddress(expectedTo) ||
          !_isEvmAddress(recipient) ||
          amount == null) {
        throw const FormatException('Invalid token transfer plan.');
      }
      return (
        expectedTo,
        BigInt.zero,
        _erc20Call('a9059cbb', recipient, amount),
      );
    }
    if (payload['type'] == 'erc20Approval') {
      final spender = payload['spender']?.toString() ?? '';
      final amount = BigInt.tryParse(payload['amount']?.toString() ?? '');
      if (!_isEvmAddress(expectedTo) ||
          !_isEvmAddress(spender) ||
          amount == null) {
        throw const FormatException('Invalid token approval plan.');
      }
      return (expectedTo, BigInt.zero, _erc20Call('095ea7b3', spender, amount));
    }
    final tx = _stringKeyedMap(payload['transaction']);
    final to = tx['to']?.toString() ?? '';
    final data = tx['data']?.toString() ?? '';
    final value = _parseBaseUnitValue(tx['value']);
    if (!_isEvmAddress(to) ||
        !_isEvmAddress(expectedTo) ||
        to.toLowerCase() != expectedTo.toLowerCase() ||
        !RegExp(r'^0x[0-9a-fA-F]*$').hasMatch(data)) {
      throw const FormatException('Invalid provider transaction plan.');
    }
    final ceiling = _parseBaseUnitValue(step['maxTransactionValue']);
    if (value > ceiling) {
      throw const FormatException(
        'Provider transaction value exceeds the route limit.',
      );
    }
    return (to, value, data);
  }

  static String _erc20Call(String selector, String address, BigInt amount) {
    if (amount.isNegative || amount.bitLength > 256) {
      throw const FormatException(
        'Token amount exceeds the EVM uint256 limit.',
      );
    }
    final addressWord = address.substring(2).toLowerCase().padLeft(64, '0');
    final amountWord = amount.toRadixString(16).padLeft(64, '0');
    return '0x$selector$addressWord$amountWord';
  }

  static BigInt _parseBaseUnitValue(dynamic value) {
    final text = value?.toString() ?? '0';
    final parsed = text.startsWith('0x')
        ? BigInt.tryParse(text.substring(2), radix: 16)
        : BigInt.tryParse(text);
    if (parsed == null || parsed.isNegative) {
      throw const FormatException(
        'Invalid transaction value in execution plan.',
      );
    }
    return parsed;
  }

  static Map<String, dynamic> _gaslessSource(Map<String, dynamic> payload) => {
    if (payload['type'] != null) 'type': payload['type'],
    'eip712': _stringKeyedMap(payload['typedData']),
  };

  static Map<String, dynamic> _stepPayload(Map<String, dynamic> step) =>
      _stringKeyedMap(step['payload']);

  static Map<String, dynamic> _decodeBackendBody(String body) {
    final decoded = jsonDecode(body);
    return _stringKeyedMap(decoded);
  }

  static Map<String, dynamic> _stringKeyedMap(dynamic value) {
    if (value is! Map) throw const FormatException('Malformed execution plan.');
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }

  static int _requiredInt(Map<String, dynamic> value, String key) {
    final parsed =
        (value[key] as num?)?.toInt() ?? int.tryParse('${value[key]}');
    if (parsed == null) {
      throw FormatException('Missing $key in execution plan.');
    }
    return parsed;
  }

  static bool _isEvmAddress(String value) =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value);

  static String _swapLabel(Map<String, dynamic> payload, String prefix) {
    final amount = payload['${prefix}AmountDisplay']?.toString() ?? '';
    final symbol = payload['${prefix}AssetSymbol']?.toString() ?? '';
    return amount.isEmpty ? symbol : '$amount $symbol';
  }

  Future<bool?> _confirmCrossChainSwap({
    required String fromLabel,
    required String toLabel,
    required String reference,
    required int stepCount,
    bool isTransfer = false,
  }) {
    final txLabel = stepCount == 1 ? 'transaction' : 'transactions';
    final refText = reference.trim().isEmpty ? '' : '\n\nReference: $reference';
    // When the sold asset already settles as-is (e.g. USDC â†’ USDC), nothing is
    // swapped on-chain â€” it is a plain transfer to the settlement address.
    final title = isTransfer ? 'Confirm transfer' : 'Sign swap transaction';
    final body = isTransfer
        ? 'Send $fromLabel to OwlletPay.\n\nOwllet will sign and submit '
              '$stepCount $txLabel from this wallet.$refText'
        : 'Swap $fromLabel to $toLabel.\n\nOwllet will sign and submit '
              '$stepCount $txLabel from this wallet.$refText';
    final actionLabel = isTransfer ? 'Confirm & send' : 'Sign and swap';
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
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            body,
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
                actionLabel,
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
            'Send $amountDisplay for withdrawal request $reference.${nativeSymbol.isEmpty ? '' : '\n\nNetwork fees are paid in $nativeSymbol.'}',
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

  Future<Map<String, dynamic>> _handleReceiptImageRequest(
    String method,
    Map<String, dynamic> payload,
  ) async {
    final dataUrl = payload['dataUrl']?.toString() ?? '';
    final filename = payload['filename']?.toString() ?? 'owllet-receipt';
    final text = payload['text']?.toString() ?? '';
    if (!dataUrl.startsWith('data:image/png;base64,')) {
      return const <String, dynamic>{
        'ok': false,
        'code': 'RECEIPT_INVALID_IMAGE',
        'error': 'Receipt image must be a PNG data URL.',
      };
    }
    // A 640px receipt is normally well below 1 MB. Bound the untrusted
    // WebView payload before it crosses the platform channel or is decoded by
    // Android, where an oversized Base64 string could otherwise exhaust memory.
    const maxReceiptDataUrlCharacters = 6 * 1024 * 1024;
    if (dataUrl.length > maxReceiptDataUrlCharacters) {
      return const <String, dynamic>{
        'ok': false,
        'code': 'RECEIPT_IMAGE_TOO_LARGE',
        'error': 'The receipt image is too large to save or share.',
      };
    }
    try {
      final result = await _receiptFilesChannel
          .invokeMethod<Map<dynamic, dynamic>>(method, <String, dynamic>{
            'filename': filename,
            'dataUrl': dataUrl,
            'text': text,
          });
      if (result == null) {
        return const <String, dynamic>{
          'ok': false,
          'error': 'Receipt action was not available on this device.',
        };
      }
      return result.map((key, value) => MapEntry(key.toString(), value));
    } on PlatformException catch (error) {
      debugPrint(
        'Receipt host action failed: method=$method code=${error.code} '
        'message=${error.message}',
      );
      return <String, dynamic>{
        'ok': false,
        'code': 'RECEIPT_HOST_UNAVAILABLE',
        'error': 'The receipt action is unavailable. Please try again.',
      };
    } catch (error) {
      debugPrint('Receipt host action failed: method=$method error=$error');
      return <String, dynamic>{
        'ok': false,
        'code': 'RECEIPT_ACTION_FAILED',
        'error': 'The receipt action failed. Please try again.',
      };
    }
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
      case ChainFamily.bitcoin:
        throw UnsupportedError('Bitcoin is unavailable for this operation.');
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
          networkKey: networkKey,
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
  /// mapper collapses to "Wallet transfer failed" â€” hiding the real cause. Map
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
      case ChainFamily.bitcoin:
        return false;
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
      case ChainFamily.bitcoin:
        return null;
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

  bool _runtimeAllowsMiniAppUrl(Uri uri) {
    final feature = runtimeFeatureForMiniAppLaunch(
      widget.definition.id,
      uri.toString(),
    );
    return _runtimeConfig.snapshot.allows(feature);
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
  /// request's own origin is empty/unreliable on some Android WebView builds â€”
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

/// Native confirmation bottom sheet shown when a mini-app requests a network
/// switch via `OwlletMiniApp.switchNetwork()`. The user must explicitly approve
/// â€” rejection returns `{ ok: false }` to the caller without any chain change.
class _SwitchNetworkSheet extends StatelessWidget {
  const _SwitchNetworkSheet({
    required this.networkLabel,
    required this.appName,
  });

  final String networkLabel;
  final String appName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Network icon placeholder
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0c8f66).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0c8f66).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF50D199),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Switch Network',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$appName wants to switch your active network to $networkLabel.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This will change your active wallet network in the Owllet app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // Approve button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0c8f66),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Switch to $networkLabel'),
            ),
          ),
          const SizedBox(height: 10),
          // Reject button
          SizedBox(
            height: 48,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
