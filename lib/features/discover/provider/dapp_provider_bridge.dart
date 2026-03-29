import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../models/chain.dart';
import '../../../services/blockchain_service.dart';
import '../../../services/rpc_service.dart';
import '../../../services/wallet_service.dart';
import '../browser/browser_session_controller.dart';
import '../permissions/dapp_permission_service.dart';
import 'discover_provider_approval_request.dart';

class DappProviderBridge {
  DappProviderBridge({
    required this.sessionController,
    required this.permissionService,
    WalletService? walletService,
    DiscoverProviderApprovalHandler? approvalHandler,
  }) : _walletService = walletService ?? WalletService(),
       _approvalHandler = approvalHandler;

  final BrowserSessionController sessionController;
  final DappPermissionService permissionService;
  final WalletService _walletService;
  final DiscoverProviderApprovalHandler? _approvalHandler;

  static const String handlerName = 'owlletProvider';

  static String providerInjectionScript() =>
      '''
(function() {
  if (window.__owlletProviderInstalled) return;
  window.__owlletProviderInstalled = true;
  class OwlletProvider {
    constructor() {
      this.isOwllet = true;
      this.isMetaMask = false;
      this._events = {};
      this.selectedAddress = null;
    }
    async request(args) {
      const payload = {
        method: args && args.method ? args.method : '',
        params: Array.isArray(args && args.params) ? args.params : []
      };
      const response = await window.flutter_inappwebview.callHandler('$handlerName', payload);
      if (response && response.error) {
        const error = new Error(response.error.message || 'Provider request failed');
        error.code = response.error.code;
        throw error;
      }
      const result = response ? response.result : null;
      if (payload.method === 'eth_requestAccounts' || payload.method === 'eth_accounts') {
        this.selectedAddress = Array.isArray(result) && result.length > 0 ? result[0] : null;
      }
      if (payload.method === 'wallet_switchEthereumChain' && payload.params && payload.params[0]) {
        this._emit('chainChanged', [payload.params[0].chainId]);
      }
      return result;
    }
    on(eventName, listener) {
      this._events[eventName] = this._events[eventName] || [];
      this._events[eventName].push(listener);
    }
    removeListener(eventName, listener) {
      this._events[eventName] = (this._events[eventName] || []).filter((item) => item !== listener);
    }
    enable() {
      return this.request({ method: 'eth_requestAccounts', params: [] });
    }
    isConnected() { return true; }
    _emit(eventName, payload) {
      (this._events[eventName] || []).forEach((listener) => {
        try { listener.apply(null, payload || []); } catch (_) {}
      });
    }
  }
  window.ethereum = new OwlletProvider();
  window.dispatchEvent(new Event('ethereum#initialized'));
})();
''';

  Future<Map<String, dynamic>> handleRequest({
    required BuildContext context,
    required String origin,
    required Map<String, dynamic> payload,
    required Future<void> Function(String source) evaluateJavaScript,
  }) async {
    try {
      final method = payload['method']?.toString() ?? '';
      final params = payload['params'] is List<dynamic>
          ? (payload['params'] as List<dynamic>)
          : const <dynamic>[];

      switch (method) {
        case 'eth_chainId':
          return _result(
            _hexQuantity(context.read<BlockchainService>().activeChain.chainId),
          );
        case 'net_version':
          return _result(
            '${context.read<BlockchainService>().activeChain.chainId}',
          );
        case 'eth_accounts':
          return _result(await _ethAccounts(origin));
        case 'eth_requestAccounts':
          return _result(
            await _ethRequestAccounts(context, origin, evaluateJavaScript),
          );
        case 'wallet_getPermissions':
          return _result(await _walletGetPermissions(origin));
        case 'wallet_requestPermissions':
          return _result(
            await _walletRequestPermissions(
              context,
              origin,
              params,
              evaluateJavaScript,
            ),
          );
        case 'wallet_switchEthereumChain':
          await _walletSwitchEthereumChain(context, params, evaluateJavaScript);
          return _result(null);
        case 'wallet_addEthereumChain':
          await _walletAddEthereumChain(context, params);
          return _result(null);
        case 'personal_sign':
          return _result(await _personalSign(context, params));
        case 'eth_signTypedData_v4':
          return _result(await _signTypedData(context, params));
        case 'eth_sendTransaction':
          return _result(await _sendTransaction(context, params));
        default:
          return _error(4200, 'Unsupported provider method: $method');
      }
    } on _ProviderBridgeException catch (error) {
      return _error(error.code, error.message);
    } catch (error) {
      return _error(-32603, error.toString());
    }
  }

  Future<List<String>> _ethAccounts(String origin) async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      return const <String>[];
    }
    final hasApproval = await permissionService.hasConnectionApproval(
      origin,
      walletAddress,
    );
    if (!hasApproval) {
      return const <String>[];
    }
    return <String>[walletAddress];
  }

  Future<List<String>> _ethRequestAccounts(
    BuildContext context,
    String origin,
    Future<void> Function(String source) evaluateJavaScript,
  ) async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      throw _ProviderBridgeException(4100, 'No active wallet is available.');
    }

    final hasApproval = await permissionService.hasConnectionApproval(
      origin,
      walletAddress,
    );
    if (!hasApproval) {
      if (!context.mounted) {
        throw _ProviderBridgeException(
          -32603,
          'The request could not be completed.',
        );
      }
      final approved = await _confirmAction(
        context,
        title: 'Connect wallet',
        message:
            '$origin wants access to ${_shortAddress(walletAddress)}. This site will only stay connected to the current wallet.',
        confirmLabel: 'Connect',
      );
      if (!approved) {
        throw _ProviderBridgeException(
          4001,
          'The connection request was rejected.',
        );
      }
      await permissionService.grantConnectionApproval(origin, walletAddress);
    }

    final accounts = <String>[walletAddress];
    await evaluateJavaScript(
      "window.ethereum && window.ethereum._emit('accountsChanged', ${jsonEncode(accounts)});",
    );
    return accounts;
  }

  Future<List<Map<String, dynamic>>> _walletGetPermissions(
    String origin,
  ) async {
    final accounts = await _ethAccounts(origin);
    if (accounts.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    return const <Map<String, dynamic>>[
      <String, dynamic>{'parentCapability': 'eth_accounts'},
    ];
  }

  Future<List<Map<String, dynamic>>> _walletRequestPermissions(
    BuildContext context,
    String origin,
    List<dynamic> params,
    Future<void> Function(String source) evaluateJavaScript,
  ) async {
    final requested = params.isNotEmpty ? params.first : null;
    if (requested is! Map || !requested.containsKey('eth_accounts')) {
      throw _ProviderBridgeException(
        4200,
        'Only eth_accounts permissions are supported.',
      );
    }
    await _ethRequestAccounts(context, origin, evaluateJavaScript);
    return const <Map<String, dynamic>>[
      <String, dynamic>{'parentCapability': 'eth_accounts'},
    ];
  }

  Future<void> _walletSwitchEthereumChain(
    BuildContext context,
    List<dynamic> params,
    Future<void> Function(String source) evaluateJavaScript,
  ) async {
    final requested = params.isNotEmpty ? params.first : null;
    final chainId = _parseChainId(
      requested is Map ? requested['chainId'] : null,
    );
    if (chainId == null) {
      throw _ProviderBridgeException(
        -32602,
        'wallet_switchEthereumChain requires a valid chainId.',
      );
    }
    _ensureChainAllowedForDapp(chainId);

    final blockchain = context.read<BlockchainService>();
    EvmChain? matchingChain;
    for (final chain in blockchain.allChains) {
      if (chain.chainId == chainId) {
        matchingChain = chain;
        break;
      }
    }
    if (matchingChain == null) {
      throw _ProviderBridgeException(
        4902,
        'The requested chain has not been added yet.',
      );
    }

    final approved = await _confirmAction(
      context,
      title: 'Switch network',
      message: 'Switch Owllet to ${matchingChain.name} for this DApp session?',
      confirmLabel: 'Switch',
    );
    if (!approved) {
      throw _ProviderBridgeException(
        4001,
        'The network switch request was rejected.',
      );
    }

    blockchain.setActiveChainByChainId(chainId);
    await evaluateJavaScript(
      "window.ethereum && window.ethereum._emit('chainChanged', ['${_hexQuantity(chainId)}']);",
    );
  }

  Future<void> _walletAddEthereumChain(
    BuildContext context,
    List<dynamic> params,
  ) async {
    final request = params.isNotEmpty ? params.first : null;
    if (request is! Map) {
      throw _ProviderBridgeException(
        -32602,
        'wallet_addEthereumChain requires a request object.',
      );
    }

    final chainId = _parseChainId(request['chainId']);
    if (chainId == null) {
      throw _ProviderBridgeException(
        -32602,
        'The requested chainId is invalid.',
      );
    }
    _ensureChainAllowedForDapp(chainId);

    final chainName = request['chainName']?.toString().trim();
    if (chainName == null || chainName.isEmpty) {
      throw _ProviderBridgeException(
        -32602,
        'The requested chainName is required.',
      );
    }

    final rpcUrls = (request['rpcUrls'] as List<dynamic>? ?? const <dynamic>[])
        .map((value) => value.toString().trim())
        .where((value) => value.startsWith('https://'))
        .toList(growable: false);
    if (rpcUrls.isEmpty) {
      throw _ProviderBridgeException(
        -32602,
        'At least one HTTPS RPC URL is required.',
      );
    }

    final explorerUrls =
        (request['blockExplorerUrls'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
    if (explorerUrls.any((value) => !value.startsWith('https://'))) {
      throw _ProviderBridgeException(
        -32602,
        'Block explorer URLs must use HTTPS.',
      );
    }

    final nativeCurrency =
        request['nativeCurrency'] as Map<dynamic, dynamic>? ??
        const <dynamic, dynamic>{};
    final symbol = nativeCurrency['symbol']?.toString().trim();
    if (symbol == null || symbol.isEmpty) {
      throw _ProviderBridgeException(
        -32602,
        'The native currency symbol is required.',
      );
    }

    final blockchain = context.read<BlockchainService>();
    final rpcService = context.read<RpcService>();
    for (final chain in blockchain.allChains) {
      if (chain.chainId == chainId) {
        return;
      }
    }

    final approved = await _confirmAction(
      context,
      title: 'Add network',
      message:
          'Add $chainName (${_hexQuantity(chainId)}) to Owllet as a global custom network?',
      confirmLabel: 'Add network',
    );
    if (!approved) {
      throw _ProviderBridgeException(
        4001,
        'The add-network request was rejected.',
      );
    }

    String? verifiedRpcUrl;
    for (final rpcUrl in rpcUrls) {
      final rpcChainId = await rpcService.getChainIdForRpcUrl(rpcUrl);
      if (rpcChainId == chainId) {
        verifiedRpcUrl = rpcUrl;
        break;
      }
    }
    if (verifiedRpcUrl == null) {
      throw _ProviderBridgeException(
        -32602,
        'None of the supplied RPC URLs matched the requested chainId.',
      );
    }

    await blockchain.addCustomChain(
      EvmChain(
        name: chainName,
        symbol: symbol.toUpperCase(),
        chainId: chainId,
        rpcUrl: verifiedRpcUrl,
        explorerUrl: explorerUrls.isEmpty ? null : explorerUrls.first,
        isCustom: true,
      ),
    );
  }

  Future<String> _personalSign(
    BuildContext context,
    List<dynamic> params,
  ) async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      throw _ProviderBridgeException(4100, 'No active wallet is available.');
    }

    final resolved = _resolveSignPayload(params, walletAddress);
    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final approved = await _confirmAction(
      context,
      title: 'Sign message',
      message:
          '${sessionController.activeDapp?.title ?? sessionController.activeDapp?.origin ?? 'This DApp'} wants a personal signature.\n\n${resolved.preview}',
      confirmLabel: 'Sign',
    );
    if (!approved) {
      throw _ProviderBridgeException(
        4001,
        'The signature request was rejected.',
      );
    }

    final signature = await _walletService.signMessageForAddress(
      walletAddress,
      resolved.payload,
    );
    return signature.startsWith('0x') ? signature : '0x$signature';
  }

  Future<String> _signTypedData(
    BuildContext context,
    List<dynamic> params,
  ) async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      throw _ProviderBridgeException(4100, 'No active wallet is available.');
    }

    if (params.length < 2) {
      throw _ProviderBridgeException(
        -32602,
        'eth_signTypedData_v4 requires address and typed data.',
      );
    }
    final address = params[0]?.toString().trim() ?? '';
    final jsonData = params[1]?.toString() ?? '';
    if (address.toLowerCase() != walletAddress.toLowerCase() ||
        jsonData.isEmpty) {
      throw _ProviderBridgeException(
        -32602,
        'Invalid typed-data signing request.',
      );
    }

    final summary = _typedDataSummary(jsonData);
    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final approved = await _confirmAction(
      context,
      title: 'Sign typed data',
      message:
          '${sessionController.activeDapp?.title ?? sessionController.activeDapp?.origin ?? 'This DApp'} wants an EIP-712 signature.\n\n$summary',
      confirmLabel: 'Sign',
    );
    if (!approved) {
      throw _ProviderBridgeException(
        4001,
        'The typed-data signature request was rejected.',
      );
    }

    final signature = await _walletService.signTypedDataForAddress(
      walletAddress,
      jsonData,
    );
    return signature.startsWith('0x') ? signature : '0x$signature';
  }

  Future<String> _sendTransaction(
    BuildContext context,
    List<dynamic> params,
  ) async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      throw _ProviderBridgeException(4100, 'No active wallet is available.');
    }
    final request = params.isNotEmpty ? params.first : null;
    if (request is! Map) {
      throw _ProviderBridgeException(
        -32602,
        'eth_sendTransaction requires a transaction object.',
      );
    }

    final from = request['from']?.toString().trim() ?? '';
    if (from.toLowerCase() != walletAddress.toLowerCase()) {
      throw _ProviderBridgeException(
        4100,
        'The transaction must be sent from the active wallet.',
      );
    }

    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final blockchain = context.read<BlockchainService>();
    final activeChain = blockchain.activeChain;
    final to = request['to']?.toString().trim();
    final valueWei = _parseBigIntQuantity(request['value']);
    final gasPriceWei = _parseBigIntQuantity(request['gasPrice']);
    final gasLimit = _parseIntQuantity(request['gas']);
    final nonce = _parseIntQuantity(request['nonce']);
    final dataHex = request['data']?.toString();

    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final approved = await _confirmAction(
      context,
      title: 'Send transaction',
      message:
          'Broadcast a transaction on ${activeChain.name}?\n\nTo: ${to == null || to.isEmpty ? 'Contract creation' : to}\nValue: ${valueWei?.toString() ?? '0'} wei',
      confirmLabel: 'Send',
    );
    if (!approved) {
      throw _ProviderBridgeException(
        4001,
        'The transaction request was rejected.',
      );
    }

    final txHash = await _walletService.sendRawTransactionRequest(
      rpcUrl: activeChain.rpcUrl,
      chainId: activeChain.chainId,
      toAddress: to,
      valueInWei: valueWei,
      dataHex: dataHex,
      gasPriceWei: gasPriceWei,
      gasLimit: gasLimit,
      nonce: nonce,
    );
    return txHash.startsWith('0x') ? txHash : '0x$txHash';
  }

  void _ensureChainAllowedForDapp(int chainId) {
    final supported =
        sessionController.activeDapp?.supportedChainIds ?? const <int>[];
    if (supported.isNotEmpty && !supported.contains(chainId)) {
      throw _ProviderBridgeException(
        4200,
        'This DApp is not approved to use the requested chain.',
      );
    }
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final request = DiscoverProviderApprovalRequest(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
    if (_approvalHandler != null) {
      return _approvalHandler(context, request);
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.cardDark,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  request.message,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentRed,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(request.confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  _ResolvedSignPayload _resolveSignPayload(
    List<dynamic> params,
    String walletAddress,
  ) {
    if (params.length < 2) {
      throw _ProviderBridgeException(
        -32602,
        'personal_sign requires message and address.',
      );
    }
    final first = params[0]?.toString() ?? '';
    final second = params[1]?.toString() ?? '';
    final isFirstAddress = first.toLowerCase() == walletAddress.toLowerCase();
    final payload = isFirstAddress ? second : first;
    final preview = payload.length > 240
        ? '${payload.substring(0, 240)}...'
        : payload;
    return _ResolvedSignPayload(payload: payload, preview: preview);
  }

  String _typedDataSummary(String jsonData) {
    try {
      final decoded = jsonDecode(jsonData);
      if (decoded is! Map<String, dynamic>) {
        return 'Review the requested typed data carefully before signing.';
      }
      final domain = decoded['domain'] as Map<String, dynamic>? ?? const {};
      final primaryType = decoded['primaryType']?.toString() ?? 'Unknown';
      final name = domain['name']?.toString() ?? 'Unknown domain';
      final version = domain['version']?.toString();
      return [
        'Domain: $name${version == null ? '' : ' v$version'}',
        'Primary type: $primaryType',
      ].join('\n');
    } catch (_) {
      return 'Review the requested typed data carefully before signing.';
    }
  }

  Map<String, dynamic> _result(Object? value) => <String, dynamic>{
    'result': value,
  };

  Map<String, dynamic> _error(int code, String message) => <String, dynamic>{
    'error': <String, dynamic>{'code': code, 'message': message},
  };

  String _hexQuantity(int value) => '0x${value.toRadixString(16)}';

  int? _parseChainId(Object? value) {
    final parsed = _parseBigIntQuantity(value);
    return parsed?.toInt();
  }

  int? _parseIntQuantity(Object? value) => _parseBigIntQuantity(value)?.toInt();

  BigInt? _parseBigIntQuantity(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return BigInt.from(value);
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith('0x')) {
      return BigInt.tryParse(text.substring(2), radix: 16);
    }
    return BigInt.tryParse(text);
  }

  String _shortAddress(String address) {
    if (address.length < 10) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

class _ResolvedSignPayload {
  const _ResolvedSignPayload({required this.payload, required this.preview});

  final String payload;
  final String preview;
}

class _ProviderBridgeException implements Exception {
  const _ProviderBridgeException(this.code, this.message);

  final int code;
  final String message;
}
