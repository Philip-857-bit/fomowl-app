import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const String detectorHandlerName = 'owlletDappDetector';
  static const String _walletConnectIconAssetPath =
      'assets/images/launcher_icon.png';
  static const String _fallbackWalletConnectIconDataUri =
      'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96"%3E%3Crect width="96" height="96" rx="24" fill="%23050505"/%3E%3Cpath d="M24 25c0-3.3 2.7-6 6-6h17c15.46 0 28 12.54 28 28v24c0 3.3-2.7 6-6 6H52.5C36.76 77 24 64.24 24 48.5V25zm12 6v17.5C36 57.61 43.39 65 52.5 65H63V47c0-8.84-7.16-16-16-16H36zm11.75 6.5c4.56 0 8.25 3.69 8.25 8.25S52.31 54 47.75 54 39.5 50.31 39.5 45.75s3.69-8.25 8.25-8.25zm0 4.5a3.75 3.75 0 100 7.5 3.75 3.75 0 000-7.5z" fill="%23ff3344"/%3E%3C/svg%3E';
  static const Set<String> _blockedRpcPassthroughMethods = {
    'eth_requestAccounts',
    'eth_accounts',
    'eth_coinbase',
    'eth_sendTransaction',
    'eth_sendRawTransaction',
    'eth_sign',
    'eth_signTransaction',
    'eth_signTypedData',
    'eth_signTypedData_v3',
    'eth_signTypedData_v4',
    'personal_sign',
    'wallet_addEthereumChain',
    'wallet_switchEthereumChain',
    'wallet_requestPermissions',
    'wallet_revokePermissions',
    'wallet_watchAsset',
  };
  static String? _providerInjectionScriptCache;
  static Future<String>? _providerInjectionScriptInFlight;

  Future<String> providerInjectionScript() async {
    final cached = _providerInjectionScriptCache;
    if (cached != null) {
      return cached;
    }

    final loader = _providerInjectionScriptInFlight ??=
        _buildProviderInjectionScript();
    final script = await loader;
    _providerInjectionScriptCache = script;
    if (identical(_providerInjectionScriptInFlight, loader)) {
      _providerInjectionScriptInFlight = null;
    }
    return script;
  }

  static Future<String> _buildProviderInjectionScript() async {
    final iconDataUri = await _loadWalletConnectIconDataUri();
    final iconLiteral = jsonEncode(iconDataUri);
    return '''
(function() {
  const owlletInfo = Object.freeze({
    uuid: 'owllet-mobile-wallet',
    name: 'Owllet',
    icon: $iconLiteral,
    rdns: 'com.fomowl.owllet'
  });
  const OWLLET_PROVIDER_TIMEOUT_MS = 30000;
  const OWLLET_PROVIDER_INTERACTIVE_TIMEOUT_MS = 180000;
  const interactiveMethods = new Set([
    'eth_requestAccounts',
    'wallet_requestPermissions',
    'wallet_switchEthereumChain',
    'wallet_addEthereumChain',
    'personal_sign',
    'eth_signTypedData_v4',
    'eth_sendTransaction',
    'solana_connect',
    'solana_signMessage',
    'solana_signTransaction',
    'solana_signAndSendTransaction',
    'tron_requestAccounts',
    'tron_sign',
    'tron_signTransaction'
  ]);

  function normalizeParams(params) {
    if (Array.isArray(params)) {
      return params;
    }
    if (params === undefined || params === null) {
      return [];
    }
    return [params];
  }

  async function callFlutterHandler(method, payload) {
    const timeoutMs = interactiveMethods.has(method)
      ? OWLLET_PROVIDER_INTERACTIVE_TIMEOUT_MS
      : OWLLET_PROVIDER_TIMEOUT_MS;
    const callPromise = window.flutter_inappwebview.callHandler('$handlerName', payload);
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => {
        const timeoutError = new Error('Provider request timed out.');
        timeoutError.code = -32002;
        reject(timeoutError);
      }, timeoutMs);
    });
    return Promise.race([callPromise, timeoutPromise]);
  }

  if (window.__owlletProviderInstalled && window.__owlletAnnounceProvider) {
    window.__owlletAnnounceProvider();
    try { window.dispatchEvent(new Event('ethereum#initialized')); } catch (_) {}
    return;
  }

  class OwlletProvider {
    constructor() {
      this.isOwllet = true;
      this.isMetaMask = true;
      this.providers = [this];
      this.chainId = null;
      this.networkVersion = null;
      this._events = {};
      this.selectedAddress = null;
      this._connected = true;
      this._hasAnnouncedConnect = false;
      this._metamask = {
        isUnlocked: async () => !!this.selectedAddress
      };
    }
    async request(args) {
      let method = '';
      let params = [];
      if (typeof args === 'string') {
        method = args;
      } else if (args && typeof args === 'object') {
        method = typeof args.method === 'string' ? args.method : '';
        params = normalizeParams(args.params);
      }
      if (!method) {
        const invalidArgsError = new Error('Invalid provider request arguments');
        invalidArgsError.code = -32602;
        throw invalidArgsError;
      }
      const payload = { method: method, params: params };
      let response;
      try {
        response = await callFlutterHandler(method, payload);
      } catch (error) {
        if (error && typeof error === 'object' && Object.prototype.hasOwnProperty.call(error, 'code')) {
          throw error;
        }
        const wrappedError = new Error(error && error.message ? error.message : 'Provider request failed');
        wrappedError.code = -32603;
        throw wrappedError;
      }
      if (response && response.error) {
        const error = new Error(response.error.message || 'Provider request failed');
        error.code = response.error.code;
        throw error;
      }
      const result = response ? response.result : null;
      if (payload.method === 'eth_requestAccounts' || payload.method === 'eth_accounts') {
        this._setAccounts(Array.isArray(result) ? result : []);
      }
      if (payload.method === 'eth_chainId') {
        this._setChainId(typeof result === 'string' ? result : null);
      }
      if (payload.method === 'wallet_switchEthereumChain' || payload.method === 'wallet_addEthereumChain') {
        const nextChainId = payload.params && payload.params[0] ? payload.params[0].chainId : null;
        this._setChainId(typeof nextChainId === 'string' ? nextChainId : null);
      }
      return result;
    }
    send(methodOrPayload, callbackOrParams) {
      if (typeof methodOrPayload === 'string') {
        const promise = this.request({
          method: methodOrPayload,
          params: normalizeParams(callbackOrParams)
        });
        if (typeof callbackOrParams === 'function') {
          promise.then((value) => callbackOrParams(null, value)).catch((error) => callbackOrParams(error, null));
          return;
        }
        return promise;
      }
      if (methodOrPayload && typeof methodOrPayload === 'object') {
        const payload = methodOrPayload;
        const promise = this.request({
          method: payload.method,
          params: normalizeParams(payload.params)
        }).then((result) => ({
          jsonrpc: '2.0',
          id: payload.id ?? null,
          result: result
        }));
        if (typeof callbackOrParams === 'function') {
          promise.then((value) => callbackOrParams(null, value)).catch((error) => callbackOrParams(error, null));
          return;
        }
        return promise;
      }
      return Promise.reject(new Error('Invalid provider request arguments'));
    }
    sendAsync(payload, callback) {
      return this.send(payload, callback);
    }
    on(eventName, listener) {
      this._events[eventName] = this._events[eventName] || [];
      this._events[eventName].push(listener);
    }
    once(eventName, listener) {
      const wrapped = (...args) => {
        this.removeListener(eventName, wrapped);
        listener.apply(null, args);
      };
      this.on(eventName, wrapped);
    }
    removeListener(eventName, listener) {
      this._events[eventName] = (this._events[eventName] || []).filter((item) => item !== listener);
    }
    removeAllListeners(eventName) {
      if (eventName) {
        this._events[eventName] = [];
      } else {
        this._events = {};
      }
    }
    enable() {
      return this.request({ method: 'eth_requestAccounts', params: [] });
    }
    isConnected() { return true; }
    _setAccounts(accounts) {
      const normalized = Array.isArray(accounts) ? accounts : [];
      this.selectedAddress = normalized.length > 0 ? normalized[0] : null;
      this._emit('accountsChanged', [normalized]);
      this._announceConnectIfNeeded();
    }
    _setChainId(chainId) {
      if (typeof chainId !== 'string' || !chainId) return;
      this.chainId = chainId;
      try {
        this.networkVersion = parseInt(chainId, 16).toString();
      } catch (_) {
        this.networkVersion = null;
      }
      this._emit('chainChanged', [chainId]);
      this._announceConnectIfNeeded();
    }
    _announceConnectIfNeeded() {
      if (this._hasAnnouncedConnect || !this.chainId) return;
      this._hasAnnouncedConnect = true;
      this._emit('connect', [{ chainId: this.chainId }]);
    }
    _emit(eventName, payload) {
      (this._events[eventName] || []).forEach((listener) => {
        try { listener.apply(null, payload || []); } catch (_) {}
      });
    }
  }
  const provider = new OwlletProvider();
  provider.info = owlletInfo;
  window.__owlletAnnounceProvider = function() {
    try {
      const detail = Object.freeze({ info: owlletInfo, provider: provider });
      window.dispatchEvent(new CustomEvent('eip6963:announceProvider', { detail: detail }));
      if (typeof document !== 'undefined' && document.dispatchEvent) {
        document.dispatchEvent(new CustomEvent('eip6963:announceProvider', { detail: detail }));
      }
    } catch (_) {}
  };
  window.addEventListener('eip6963:requestProvider', window.__owlletAnnounceProvider);
  window.ethereum = provider;
  window.web3 = window.web3 || {};
  window.web3.currentProvider = provider;
  window.__owlletProvider = provider;
  window.__owlletAnnounceProvider();
  setTimeout(window.__owlletAnnounceProvider, 0);
  setTimeout(window.__owlletAnnounceProvider, 250);
  setTimeout(window.__owlletAnnounceProvider, 1000);
  setTimeout(window.__owlletAnnounceProvider, 3000);
  if (typeof document !== 'undefined') {
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        window.__owlletAnnounceProvider();
      }
    });
    document.addEventListener('DOMContentLoaded', window.__owlletAnnounceProvider);
  }
  window.dispatchEvent(new Event('ethereum#initialized'));

  // ── Solana Provider (Phantom-compatible) ─────────────────────────────────
  class OwlletSolanaProvider {
    constructor() {
      this.isPhantom = true;
      this.isOwllet = true;
      this.publicKey = null;
      this._connected = false;
      this._events = {};
    }
    get connected() { return this._connected; }
    _emit(name, ...args) {
      (this._events[name] || []).forEach(fn => { try { fn(...args); } catch(_) {} });
    }
    on(name, fn) { (this._events[name] = this._events[name] || []).push(fn); return this; }
    off(name, fn) { this._events[name] = (this._events[name] || []).filter(l => l !== fn); return this; }
    removeListener(name, fn) { return this.off(name, fn); }
    async connect(options) {
      const r = await callFlutterHandler('solana_connect', { method: 'solana_connect', params: [{ options: options || {} }] });
      if (r && r.result && r.result.publicKey) {
        const pk = r.result.publicKey;
        this.publicKey = { toBase58() { return pk; }, toString() { return pk; } };
        this._connected = true;
        this._emit('connect', this.publicKey);
      }
      return { publicKey: this.publicKey };
    }
    async disconnect() {
      await callFlutterHandler('solana_disconnect', { method: 'solana_disconnect', params: [] });
      this.publicKey = null;
      this._connected = false;
      this._emit('disconnect');
    }
    _toBase64(bytes) {
      let b64 = '';
      const chunk = 0x8000;
      for (let i = 0; i < bytes.length; i += chunk) {
        b64 += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
      }
      return btoa(b64);
    }
    async signMessage(message, encoding) {
      const bytes = (message instanceof Uint8Array) ? message : new Uint8Array(message);
      const r = await callFlutterHandler('solana_signMessage', { method: 'solana_signMessage', params: [{ message: this._toBase64(bytes), encoding: encoding || 'utf8' }] });
      if (r && r.result) {
        const sigBytes = Uint8Array.from(atob(r.result.signature).split('').map(c => c.charCodeAt(0)));
        return { signature: sigBytes, publicKey: this.publicKey };
      }
      const err = new Error(r && r.error ? r.error.message : 'signMessage failed');
      if (r && r.error) err.code = r.error.code;
      throw err;
    }
    _serializeTx(tx) {
      try { return tx.serialize({ requireAllSignatures: false, verifySignatures: false }); }
      catch(_) { try { return tx.message.serialize(); } catch(e) { throw new Error('Cannot serialize transaction: ' + e.message); } }
    }
    async signTransaction(tx) {
      const r = await callFlutterHandler('solana_signTransaction', { method: 'solana_signTransaction', params: [{ transaction: this._toBase64(this._serializeTx(tx)) }] });
      if (r && r.result && r.result.signedTransaction) {
        try {
          const signed = Uint8Array.from(atob(r.result.signedTransaction).split('').map(c => c.charCodeAt(0)));
          const sig = signed.slice(1, 65);
          if (tx.signatures && tx.signatures.length > 0 && tx.signatures[0]) {
            tx.signatures[0].signature = (typeof Buffer !== 'undefined') ? Buffer.from(sig) : sig;
          }
        } catch(_) {}
        return tx;
      }
      const err = new Error(r && r.error ? r.error.message : 'signTransaction failed');
      if (r && r.error) err.code = r.error.code;
      throw err;
    }
    async signAllTransactions(txs) { return Promise.all(txs.map(tx => this.signTransaction(tx))); }
    async signAndSendTransaction(tx, options) {
      const r = await callFlutterHandler('solana_signAndSendTransaction', { method: 'solana_signAndSendTransaction', params: [{ transaction: this._toBase64(this._serializeTx(tx)), options: options || {} }] });
      if (r && r.result) return { signature: r.result.txHash };
      const err = new Error(r && r.error ? r.error.message : 'signAndSendTransaction failed');
      if (r && r.error) err.code = r.error.code;
      throw err;
    }
  }
  const _owlletSolana = new OwlletSolanaProvider();
  window.solana = _owlletSolana;
  window.phantom = window.phantom || {};
  window.phantom.solana = _owlletSolana;
  try { window.dispatchEvent(new CustomEvent('solana#initialized')); } catch(_) {}

  // ── Tron Provider (TronLink-compatible) ───────────────────────────────────
  const _owlletTronLink = {
    ready: false,
    request: async function(req) {
      const method = (req && req.method) ? req.method : 'tron_requestAccounts';
      const params = (req && req.params) ? req.params : {};
      const r = await callFlutterHandler(method, { method: method, params: [params] });
      if (r && r.error) { const e = new Error(r.error.message); e.code = r.error.code; throw e; }
      return r ? r.result : null;
    }
  };
  const _owlletTronWeb = {
    ready: false,
    defaultAddress: { base58: '', hex: '' },
    sign: async function(msg) {
      const r = await callFlutterHandler('tron_sign', { method: 'tron_sign', params: [{ message: msg }] });
      if (r && r.error) { const e = new Error(r.error.message); e.code = r.error.code; throw e; }
      return r && r.result ? r.result.signature : null;
    },
    trx: {
      sign: async function(tx) {
        const r = await callFlutterHandler('tron_signTransaction', { method: 'tron_signTransaction', params: [{ transaction: tx }] });
        if (r && r.error) { const e = new Error(r.error.message); e.code = r.error.code; throw e; }
        return r && r.result ? r.result.signedTransaction : null;
      }
    }
  };
  _owlletTronLink.tronWeb = _owlletTronWeb;
  window.tronLink = _owlletTronLink;
  window.tronWeb = _owlletTronWeb;

  window.__owlletProviderInstalled = true;
})();
''';
  }

  static Future<String> _loadWalletConnectIconDataUri() async {
    try {
      final bytes = await rootBundle.load(_walletConnectIconAssetPath);
      final buffer = bytes.buffer.asUint8List();
      if (buffer.isEmpty) {
        return _fallbackWalletConnectIconDataUri;
      }
      return 'data:image/png;base64,${base64Encode(buffer)}';
    } catch (_) {
      return _fallbackWalletConnectIconDataUri;
    }
  }

  Future<String> buildProviderStateSyncScript({
    required int chainId,
    required String origin,
  }) async {
    final accounts = await _ethAccounts(origin);
    final solanaAddress =
        await _walletService.getWalletAddressForFamily(ChainFamily.solana) ??
        '';
    final tronAddress =
        await _walletService.getWalletAddressForFamily(ChainFamily.tron) ?? '';
    return '''
(() => {
  if (window.ethereum && window.ethereum.isOwllet) {
    if (typeof window.ethereum._setChainId === 'function') {
      window.ethereum._setChainId('${_hexQuantity(chainId)}');
    }
    if (typeof window.ethereum._setAccounts === 'function') {
      window.ethereum._setAccounts(${jsonEncode(accounts)});
    }
  }
  if (window.solana && window.solana.isOwllet && ${jsonEncode(solanaAddress)}) {
    const pk = ${jsonEncode(solanaAddress)};
    window.solana.publicKey = { toBase58() { return pk; }, toString() { return pk; } };
    window.solana._connected = true;
  }
  if (window.tronWeb && ${jsonEncode(tronAddress)}) {
    window.tronWeb.defaultAddress.base58 = ${jsonEncode(tronAddress)};
    window.tronWeb.ready = true;
    if (window.tronLink) window.tronLink.ready = true;
  }
})();
''';
  }

  static String providerDetectionScript() =>
      '''
(function() {
  if (window.__owlletDappDetectorInstalled) return;
  window.__owlletDappDetectorInstalled = true;

  let reported = false;
  function report(trigger) {
    if (reported) return;
    reported = true;
    try {
      window.flutter_inappwebview.callHandler('$detectorHandlerName', {
        trigger: trigger,
        href: window.location.href
      });
    } catch (_) {}
  }

  function installProbe(name, label) {
    let storedValue;
    Object.defineProperty(window, name, {
      configurable: true,
      enumerable: false,
      get() {
        report(label);
        return storedValue;
      },
      set(value) {
        storedValue = value;
        report(label);
      }
    });
  }

  if (!('ethereum' in window)) {
    installProbe('ethereum', 'window.ethereum');
  }

  if (!('web3' in window)) {
    installProbe('web3', 'window.web3');
  }
})();
''';

  Future<Map<String, dynamic>> handleRequest({
    required BuildContext context,
    required String origin,
    required Map<String, dynamic> payload,
    required Future<void> Function(String source) evaluateJavaScript,
  }) async {
    try {
      final originUri = Uri.tryParse(origin);
      if (originUri == null ||
          !sessionController.canInjectProviderFor(originUri)) {
        return _error(4100, 'Provider is unavailable for this origin.');
      }

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
        case 'eth_coinbase':
          final accounts = await _ethAccounts(origin);
          return _result(accounts.isEmpty ? null : accounts.first);
        case 'eth_requestAccounts':
          return _result(
            await _ethRequestAccounts(context, origin, evaluateJavaScript),
          );
        case 'wallet_getPermissions':
          return _result(await _walletGetPermissions(origin));
        case 'wallet_getCapabilities':
          return _result(await _walletGetCapabilities(origin));
        case 'wallet_requestPermissions':
          return _result(
            await _walletRequestPermissions(
              context,
              origin,
              params,
              evaluateJavaScript,
            ),
          );
        case 'wallet_revokePermissions':
          await _walletRevokePermissions(origin, params, evaluateJavaScript);
          return _result(null);
        case 'wallet_switchEthereumChain':
          await _walletSwitchEthereumChain(context, params, evaluateJavaScript);
          return _result(null);
        case 'wallet_addEthereumChain':
          await _walletAddEthereumChain(context, params);
          return _result(null);
        case 'wallet_watchAsset':
          return _result(await _walletWatchAsset(context, params));
        case 'personal_sign':
          return _result(await _personalSign(context, params));
        case 'eth_signTypedData':
        case 'eth_signTypedData_v3':
        case 'eth_signTypedData_v4':
          return _result(await _signTypedData(context, params));
        case 'eth_sendTransaction':
          return _result(await _sendTransaction(context, params));

        // ── Solana ──────────────────────────────────────────────────────────
        case 'solana_connect':
          return _result(
            await _solanaConnect(context, origin, evaluateJavaScript),
          );
        case 'solana_disconnect':
          await _solanaDisconnect(origin);
          return _result(null);
        case 'solana_signMessage':
          return _result(await _solanaSignMessage(context, origin, params));
        case 'solana_signTransaction':
          return _result(await _solanaSignTransaction(context, origin, params));
        case 'solana_signAndSendTransaction':
          return _result(
            await _solanaSignAndSendTransaction(context, origin, params),
          );

        // ── Tron ────────────────────────────────────────────────────────────
        case 'tron_requestAccounts':
          return _result(
            await _tronRequestAccounts(context, origin, evaluateJavaScript),
          );
        case 'tron_sign':
          return _result(await _tronSign(context, origin, params));
        case 'tron_signTransaction':
          return _result(await _tronSignTransaction(context, origin, params));

        default:
          return _result(await _forwardRpcRequest(context, method, params));
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
      "window.ethereum && typeof window.ethereum._setAccounts === 'function' && window.ethereum._setAccounts(${jsonEncode(accounts)});",
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

  Future<Map<String, dynamic>> _walletGetCapabilities(String origin) async {
    final accounts = await _ethAccounts(origin);
    if (accounts.isEmpty) {
      return const <String, dynamic>{};
    }
    final account = accounts.first.toLowerCase();
    return <String, dynamic>{
      account: const <String, dynamic>{
        'eth_accounts': <String, dynamic>{},
        'eth_sendTransaction': <String, dynamic>{},
        'eth_signTypedData_v4': <String, dynamic>{},
        'personal_sign': <String, dynamic>{},
        'wallet_switchEthereumChain': <String, dynamic>{},
      },
    };
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

  Future<void> _walletRevokePermissions(
    String origin,
    List<dynamic> params,
    Future<void> Function(String source) evaluateJavaScript,
  ) async {
    final requested = params.isNotEmpty ? params.first : null;
    if (requested is Map && !requested.containsKey('eth_accounts')) {
      return;
    }

    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      return;
    }

    await permissionService.revokeConnectionApproval(origin, walletAddress);
    await evaluateJavaScript(
      "window.ethereum && typeof window.ethereum._setAccounts === 'function' && window.ethereum._setAccounts([]);",
    );
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

    if (!context.mounted) {
      throw _ProviderBridgeException(
        4001,
        'The network switch request was rejected.',
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
      "window.ethereum && typeof window.ethereum._setChainId === 'function' && window.ethereum._setChainId('${_hexQuantity(chainId)}');",
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

    if (!context.mounted) {
      throw _ProviderBridgeException(
        4001,
        'The add-network request was rejected.',
      );
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

    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final refreshedBlockchain = context.read<BlockchainService>();
    await refreshedBlockchain.addCustomChain(
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

  Future<bool> _walletWatchAsset(
    BuildContext context,
    List<dynamic> params,
  ) async {
    final request = params.isNotEmpty ? params.first : null;
    if (request is! Map) {
      throw _ProviderBridgeException(
        -32602,
        'wallet_watchAsset requires a request object.',
      );
    }

    final type = request['type']?.toString().trim().toUpperCase();
    if (type != 'ERC20') {
      throw _ProviderBridgeException(
        4200,
        'Only ERC20 assets are supported for wallet_watchAsset.',
      );
    }

    final options = request['options'];
    if (options is! Map) {
      throw _ProviderBridgeException(
        -32602,
        'wallet_watchAsset requires an options object.',
      );
    }

    final address = options['address']?.toString().trim() ?? '';
    final symbol = options['symbol']?.toString().trim() ?? '';
    final name = options['name']?.toString().trim();
    final decimals = int.tryParse(options['decimals']?.toString() ?? '');
    final image = options['image']?.toString().trim();
    if (!address.startsWith('0x') || address.length != 42) {
      throw _ProviderBridgeException(
        -32602,
        'wallet_watchAsset requires a valid token address.',
      );
    }
    if (symbol.isEmpty || decimals == null || decimals < 0) {
      throw _ProviderBridgeException(
        -32602,
        'wallet_watchAsset requires a token symbol and decimals.',
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
    final approved = await _confirmAction(
      context,
      title: 'Add token',
      message: 'Add $symbol to Owllet on ${activeChain.name}?',
      confirmLabel: 'Add token',
    );
    if (!approved) {
      return false;
    }

    final added = await blockchain.addCustomToken(
      chainId: activeChain.chainId,
      token: CustomTokenDefinition(
        symbol: symbol.toUpperCase(),
        name: (name == null || name.isEmpty) ? symbol.toUpperCase() : name,
        address: address,
        decimals: decimals,
        imageUrl: image == null || image.isEmpty ? null : image,
      ),
    );
    return added;
  }

  Future<dynamic> _forwardRpcRequest(
    BuildContext context,
    String method,
    List<dynamic> params,
  ) async {
    if (!_isForwardableRpcMethod(method)) {
      throw _ProviderBridgeException(
        4200,
        'Unsupported provider method: $method',
      );
    }

    final blockchain = context.read<BlockchainService>();
    final rpcService = context.read<RpcService>();
    final activeChain = blockchain.activeChain;
    final resolvedRpcUrl = await rpcService.resolveWorkingRpcUrl(
      chainId: activeChain.chainId,
      primaryRpcUrl: activeChain.rpcUrl,
    );
    final result = await rpcService.rpcCall(
      chainId: activeChain.chainId,
      primaryRpcUrl: resolvedRpcUrl,
      method: method,
      params: params,
    );
    final rpcError = rpcService.lastError;
    if (result == null && rpcError != null) {
      throw _ProviderBridgeException(rpcError.code ?? -32603, rpcError.message);
    }
    return result;
  }

  bool _isForwardableRpcMethod(String method) {
    if (method.isEmpty || _blockedRpcPassthroughMethods.contains(method)) {
      return false;
    }
    if (method.startsWith('wallet_')) {
      return false;
    }
    return method.startsWith('eth_') ||
        method.startsWith('net_') ||
        method.startsWith('web3_');
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
    final jsonData = _normalizeTypedDataPayload(params[1]);
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
    final rpcService = context.read<RpcService>();
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

    late final String txHash;
    try {
      final resolvedRpcUrl = await rpcService.resolveWorkingRpcUrl(
        chainId: activeChain.chainId,
        primaryRpcUrl: activeChain.rpcUrl,
      );
      txHash = await _walletService.sendRawTransactionRequest(
        rpcUrl: resolvedRpcUrl,
        chainId: activeChain.chainId,
        toAddress: to,
        valueInWei: valueWei,
        dataHex: dataHex,
        gasPriceWei: gasPriceWei,
        gasLimit: gasLimit,
        nonce: nonce,
      );
    } on FormatException catch (error) {
      final message = error.message.toString();
      throw _ProviderBridgeException(
        -32602,
        message.isNotEmpty ? message : 'Invalid transaction data.',
      );
    }
    return txHash.startsWith('0x') ? txHash : '0x$txHash';
  }

  // ── Solana handler methods ────────────────────────────────────────────────

  Future<Map<String, dynamic>> _solanaConnect(
    BuildContext context,
    String origin,
    Future<void> Function(String) evaluateJavaScript,
  ) async {
    final address = await _walletService.getWalletAddressForFamily(
      ChainFamily.solana,
    );
    if (address == null || address.isEmpty) {
      throw _ProviderBridgeException(4100, 'No Solana wallet available.');
    }
    final hasApproval = await permissionService.hasConnectionApproval(
      origin,
      address,
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
        title: 'Connect Solana wallet',
        message:
            '$origin wants access to your Solana wallet (${_shortAddress(address)}).',
        confirmLabel: 'Connect',
      );
      if (!approved) {
        throw _ProviderBridgeException(4001, 'Connection rejected.');
      }
      await permissionService.grantConnectionApproval(origin, address);
    }
    await evaluateJavaScript(
      "if (window.solana) { window.solana.publicKey = { toBase58: () => '$address', toString: () => '$address' }; window.solana._connected = true; }",
    );
    return {'publicKey': address};
  }

  Future<void> _solanaDisconnect(String origin) async {
    final address = await _walletService.getWalletAddressForFamily(
      ChainFamily.solana,
    );
    if (address != null && address.isNotEmpty) {
      await permissionService.revokeConnectionApproval(origin, address);
    }
  }

  Future<Map<String, dynamic>> _solanaSignMessage(
    BuildContext context,
    String origin,
    List<dynamic> params,
  ) async {
    final address = await _walletService.getWalletAddressForFamily(
      ChainFamily.solana,
    );
    if (address == null || address.isEmpty) {
      throw _ProviderBridgeException(4100, 'No Solana wallet available.');
    }
    final paramMap = params.isNotEmpty && params.first is Map
        ? params.first as Map
        : null;
    final messageB64 = paramMap?['message']?.toString();
    if (messageB64 == null || messageB64.isEmpty) {
      throw _ProviderBridgeException(
        -32602,
        'solana_signMessage: missing message.',
      );
    }
    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final approved = await _confirmAction(
      context,
      title: 'Sign Solana message',
      message: '$origin wants to sign a message with your Solana wallet.',
      confirmLabel: 'Sign',
    );
    if (!approved) throw _ProviderBridgeException(4001, 'Signature rejected.');
    final messageBytes = base64Decode(messageB64);
    final signatureB58 = await _walletService.signSolanaMessageRaw(
      address,
      messageBytes,
    );
    final sigBytes = WalletService.decodeBase58Signature(signatureB58);
    return {'signature': base64Encode(sigBytes)};
  }

  Future<Map<String, dynamic>> _solanaSignTransaction(
    BuildContext context,
    String origin,
    List<dynamic> params,
  ) async {
    final address = await _walletService.getWalletAddressForFamily(
      ChainFamily.solana,
    );
    if (address == null || address.isEmpty) {
      throw _ProviderBridgeException(4100, 'No Solana wallet available.');
    }
    final paramMap = params.isNotEmpty && params.first is Map
        ? params.first as Map
        : null;
    final txB64 = paramMap?['transaction']?.toString();
    if (txB64 == null || txB64.isEmpty) {
      throw _ProviderBridgeException(
        -32602,
        'solana_signTransaction: missing transaction.',
      );
    }
    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final approved = await _confirmAction(
      context,
      title: 'Sign Solana transaction',
      message: '$origin wants to sign a Solana transaction.',
      confirmLabel: 'Sign',
    );
    if (!approved) {
      throw _ProviderBridgeException(4001, 'Transaction rejected.');
    }
    final signedB64 = await _walletService.signSolanaTransactionRaw(
      address,
      base64Decode(txB64),
    );
    return {'signedTransaction': signedB64};
  }

  Future<Map<String, dynamic>> _solanaSignAndSendTransaction(
    BuildContext context,
    String origin,
    List<dynamic> params,
  ) async {
    final address = await _walletService.getWalletAddressForFamily(
      ChainFamily.solana,
    );
    if (address == null || address.isEmpty) {
      throw _ProviderBridgeException(4100, 'No Solana wallet available.');
    }
    final paramMap = params.isNotEmpty && params.first is Map
        ? params.first as Map
        : null;
    final txB64 = paramMap?['transaction']?.toString();
    if (txB64 == null || txB64.isEmpty) {
      throw _ProviderBridgeException(
        -32602,
        'solana_signAndSendTransaction: missing transaction.',
      );
    }
    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final approved = await _confirmAction(
      context,
      title: 'Send Solana transaction',
      message: '$origin wants to sign and send a Solana transaction.',
      confirmLabel: 'Send',
    );
    if (!approved) {
      throw _ProviderBridgeException(4001, 'Transaction rejected.');
    }
    final txHash = await _walletService.signAndBroadcastSolanaTransactionRaw(
      address,
      base64Decode(txB64),
    );
    return {'txHash': txHash};
  }

  // ── Tron handler methods ──────────────────────────────────────────────────

  Future<List<String>> _tronRequestAccounts(
    BuildContext context,
    String origin,
    Future<void> Function(String) evaluateJavaScript,
  ) async {
    final address = await _walletService.getWalletAddressForFamily(
      ChainFamily.tron,
    );
    if (address == null || address.isEmpty) {
      throw _ProviderBridgeException(4100, 'No Tron wallet available.');
    }
    final hasApproval = await permissionService.hasConnectionApproval(
      origin,
      address,
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
        title: 'Connect Tron wallet',
        message:
            '$origin wants access to your Tron wallet (${_shortAddress(address)}).',
        confirmLabel: 'Connect',
      );
      if (!approved) {
        throw _ProviderBridgeException(4001, 'Connection rejected.');
      }
      await permissionService.grantConnectionApproval(origin, address);
    }
    await evaluateJavaScript(
      "if (window.tronWeb) { window.tronWeb.defaultAddress.base58 = '$address'; window.tronWeb.ready = true; } if (window.tronLink) { window.tronLink.ready = true; }",
    );
    return [address];
  }

  Future<Map<String, dynamic>> _tronSign(
    BuildContext context,
    String origin,
    List<dynamic> params,
  ) async {
    final address = await _walletService.getWalletAddressForFamily(
      ChainFamily.tron,
    );
    if (address == null || address.isEmpty) {
      throw _ProviderBridgeException(4100, 'No Tron wallet available.');
    }
    final paramMap = params.isNotEmpty && params.first is Map
        ? params.first as Map
        : null;
    final messageHex = paramMap?['message']?.toString();
    if (messageHex == null || messageHex.isEmpty) {
      throw _ProviderBridgeException(-32602, 'tron_sign: missing message.');
    }
    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final approved = await _confirmAction(
      context,
      title: 'Sign Tron message',
      message: '$origin wants to sign a message with your Tron wallet.',
      confirmLabel: 'Sign',
    );
    if (!approved) throw _ProviderBridgeException(4001, 'Signature rejected.');
    final signature = await _walletService.signTronMessageRaw(
      address,
      messageHex,
    );
    return {'signature': signature};
  }

  Future<Map<String, dynamic>> _tronSignTransaction(
    BuildContext context,
    String origin,
    List<dynamic> params,
  ) async {
    final address = await _walletService.getWalletAddressForFamily(
      ChainFamily.tron,
    );
    if (address == null || address.isEmpty) {
      throw _ProviderBridgeException(4100, 'No Tron wallet available.');
    }
    final paramMap = params.isNotEmpty && params.first is Map
        ? params.first as Map
        : null;
    final txParam = paramMap?['transaction'];
    if (txParam is! Map) {
      throw _ProviderBridgeException(
        -32602,
        'tron_signTransaction: missing or invalid transaction.',
      );
    }
    if (!context.mounted) {
      throw _ProviderBridgeException(
        -32603,
        'The request could not be completed.',
      );
    }
    final approved = await _confirmAction(
      context,
      title: 'Sign Tron transaction',
      message: '$origin wants to sign a Tron transaction.',
      confirmLabel: 'Sign',
    );
    if (!approved) {
      throw _ProviderBridgeException(4001, 'Transaction rejected.');
    }
    final signedTx = await _walletService.signTronTransactionRaw(
      address,
      Map<String, dynamic>.from(txParam),
    );
    return {'signedTransaction': signedTx};
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
    final originSource =
        sessionController.currentUri?.toString() ??
        sessionController.activeDapp?.origin ??
        '';
    final parsedOrigin = Uri.tryParse(originSource);
    final originHost = parsedOrigin?.host;
    final dappLabel =
        sessionController.activeDapp?.title ??
        ((originHost != null && originHost.isNotEmpty) ? originHost : 'DApp');
    final blockchain = context.read<BlockchainService>();
    final activeChainName = blockchain.activeNetworkName;
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (!context.mounted) {
      return false;
    }
    final walletLabel = walletAddress == null || walletAddress.isEmpty
        ? 'No active wallet'
        : _shortAddress(walletAddress);

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
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(7),
                            child: Image.asset(
                              'assets/images/launcher_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Owllet Wallet',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$dappLabel • $activeChainName',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        request.title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        request.message,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          'Wallet: $walletLabel',
                          style: GoogleFonts.robotoMono(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          'Reject',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          request.confirmLabel,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
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
    final normalizedWallet = walletAddress.toLowerCase();
    final isFirstAddress = first.toLowerCase() == normalizedWallet;
    final isSecondAddress = second.toLowerCase() == normalizedWallet;
    if (!isFirstAddress && !isSecondAddress) {
      throw _ProviderBridgeException(
        -32602,
        'personal_sign requires the active wallet address.',
      );
    }
    final payload = isFirstAddress ? second : first;
    final preview = payload.length > 240
        ? '${payload.substring(0, 240)}...'
        : payload;
    return _ResolvedSignPayload(payload: payload, preview: preview);
  }

  String _normalizeTypedDataPayload(Object? value) {
    final jsonData = switch (value) {
      String stringValue => stringValue.trim(),
      Map<dynamic, dynamic> mapValue => jsonEncode(mapValue),
      List<dynamic> listValue => jsonEncode(listValue),
      null => '',
      _ => value.toString().trim(),
    };
    if (jsonData.isEmpty) {
      return '';
    }
    try {
      final decoded = jsonDecode(jsonData);
      if (decoded is Map<String, dynamic> || decoded is List<dynamic>) {
        return jsonData;
      }
    } catch (_) {}
    throw _ProviderBridgeException(
      -32602,
      'Invalid typed-data signing request.',
    );
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
