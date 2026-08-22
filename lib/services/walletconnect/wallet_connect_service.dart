import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:reown_walletkit/reown_walletkit.dart' hide RpcService;

import '../../app/app_navigator.dart';
import '../../config/app_environment.dart';
import '../../models/chain.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/walletconnect/wallet_connect_proposal_modal.dart';
import '../../widgets/walletconnect/wallet_connect_request_modal.dart';
import '../blockchain/blockchain_catalog.dart';
import '../rpc_service.dart';
import '../wallet_service.dart';
import '../wallet_history_service.dart';
import 'wallet_connect_models.dart';
import 'wallet_connect_policy.dart';
import 'wallet_connect_solana_codec.dart';

class WalletConnectService extends ChangeNotifier {
  WalletConnectService({
    WalletService? walletService,
    RpcService? rpcService,
    WalletHistoryService? walletHistoryService,
  }) : _walletService = walletService ?? WalletService(),
       _rpcService = rpcService ?? RpcService(),
       _walletHistoryService = walletHistoryService ?? WalletHistoryService();

  static final WalletConnectService instance = WalletConnectService();

  final WalletService _walletService;
  final RpcService _rpcService;
  final WalletHistoryService _walletHistoryService;

  ReownWalletKit? _walletKit;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  bool get isInitialized => _isInitialized;
  ReownWalletKit? get client => _walletKit;

  /// Initialize the Reown Web3Wallet client
  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final projectId = AppEnvironment.walletConnectProjectId;
      if (projectId.isEmpty) {
        debugPrint('[WalletConnect] No project ID configured.');
        return;
      }

      final metadata = PairingMetadata(
        name: 'Owllet',
        description: 'FOMOwl Multi-Chain Self-Custody Crypto Wallet',
        url: 'https://owlletapp.com',
        icons: ['https://owlletapp.com/owllet-app-logo.png'],
        redirect: const Redirect(native: 'owllet://'),
      );

      final walletKit = await ReownWalletKit.createInstance(
        projectId: projectId,
        metadata: metadata,
      );

      _walletKit = walletKit;
      await walletKit.init();

      _registerEventHandlers(walletKit);
      _isInitialized = true;
      notifyListeners();
      debugPrint('[WalletConnect] Initialized successfully.');
    } catch (error, stackTrace) {
      _walletKit = null;
      _isInitialized = false;
      debugPrint('[WalletConnect] Initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _initializationFuture = null;
    }
  }

  void _registerEventHandlers(ReownWalletKit walletKit) {
    walletKit.onSessionProposal.subscribe(_handleSessionProposal);
    walletKit.onSessionRequest.subscribe(_handleSessionRequest);
    walletKit.onSessionDelete.subscribe(_handleSessionDelete);
  }

  /// Pair with a WalletConnect URI (e.g. wc:...)
  Future<bool> pair(String rawUri) async {
    if (!_isInitialized) {
      await initialize();
    }

    final kit = _walletKit;
    if (kit == null) {
      ToastUtils.showError('WalletConnect is not available.');
      return false;
    }

    try {
      final uri = Uri.parse(rawUri.trim());
      if (uri.scheme.toLowerCase() != 'wc' ||
          uri.path.isEmpty ||
          !uri.queryParameters.containsKey('symKey')) {
        throw const FormatException('Invalid WalletConnect pairing URI');
      }
      debugPrint(
        '[WalletConnect] Pairing ${WalletConnectPolicy.redactedPairingLog(uri)}',
      );
      await kit.pair(uri: uri);
      return true;
    } catch (error) {
      debugPrint('[WalletConnect] Pairing failed: $error');
      ToastUtils.showError('Failed to connect: Invalid QR or pairing link.');
      return false;
    }
  }

  /// Handle incoming Session Proposal
  Future<void> _handleSessionProposal(SessionProposalEvent? event) async {
    if (event == null) return;
    final kit = _walletKit;
    if (kit == null) return;

    final proposal = event.params;
    final proposer = proposal.proposer;
    final dappName = proposer.metadata.name;
    final dappUrl = proposer.metadata.url;
    final dappIcon = proposer.metadata.icons.isNotEmpty
        ? proposer.metadata.icons.first
        : null;

    if (event.verifyContext?.validation.scam ?? false) {
      debugPrint('[WalletConnect] Blocked a Verify-classified scam proposal.');
      await kit.rejectSession(
        id: event.id,
        reason: Errors.getSdkError(Errors.USER_REJECTED).toSignError(),
      );
      ToastUtils.showError('Connection blocked because this DApp is unsafe.');
      return;
    }
    if (proposal.requests?.authentication?.isNotEmpty ?? false) {
      debugPrint(
        '[WalletConnect] Rejected unsupported authentication proposal.',
      );
      await kit.rejectSession(
        id: event.id,
        reason: Errors.getSdkError(Errors.UNSUPPORTED_METHODS).toSignError(),
      );
      ToastUtils.showError(
        'This DApp requested an authentication method Owllet does not support.',
      );
      return;
    }

    final requestedChains = <String>{};
    final requestedMethods = <String>{};
    final requestedEvents = <String>{};

    for (final entry in proposal.requiredNamespaces.entries) {
      if (entry.value.chains != null) {
        requestedChains.addAll(entry.value.chains!);
      }
      requestedMethods.addAll(entry.value.methods);
      requestedEvents.addAll(entry.value.events);
    }
    for (final entry in proposal.optionalNamespaces.entries) {
      if (entry.value.chains != null) {
        requestedChains.addAll(entry.value.chains!);
      }
      requestedMethods.addAll(entry.value.methods);
      requestedEvents.addAll(entry.value.events);
    }

    final evmAddress = await _walletService.getCurrentWalletAddress();
    final solanaAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.solana,
    );
    final tronAddress = await _walletService.getWalletAddressForFamily(
      ChainFamily.tron,
    );

    late final Map<String, Namespace> namespaces;
    try {
      namespaces = _buildApprovedNamespaces(
        requiredNamespaces: proposal.requiredNamespaces,
        optionalNamespaces: proposal.optionalNamespaces,
        evmAddress: evmAddress,
        solanaAddress: solanaAddress,
        tronAddress: tronAddress,
      );
    } on WalletConnectPolicyException catch (error) {
      debugPrint('[WalletConnect] Unsupported proposal: ${error.message}');
      await kit.rejectSession(
        id: event.id,
        reason: Errors.getSdkError(Errors.UNSUPPORTED_METHODS).toSignError(),
      );
      return;
    }

    final displayAddress = _firstApprovedAddress(namespaces);
    if (displayAddress == null) {
      await kit.rejectSession(
        id: event.id,
        reason: Errors.getSdkError(Errors.UNSUPPORTED_ACCOUNTS).toSignError(),
      );
      return;
    }

    final proposalModel = WcSessionProposalModel(
      id: event.id,
      dappName: dappName.isNotEmpty ? dappName : 'Unknown DApp',
      dappUrl: dappUrl,
      dappDescription: proposer.metadata.description,
      dappIcon: dappIcon,
      requestedChains: requestedChains.toList(),
      requestedMethods: requestedMethods.toList(),
      requestedEvents: requestedEvents.toList(),
      isVerified: event.verifyContext?.validation.valid ?? false,
    );

    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      await kit.rejectSession(
        id: event.id,
        reason: Errors.getSdkError(Errors.USER_REJECTED).toSignError(),
      );
      return;
    }

    final approved = await WalletConnectProposalModal.show(
      context,
      proposal: proposalModel,
      walletAddress: displayAddress,
    );

    if (!approved) {
      await kit.rejectSession(
        id: event.id,
        reason: Errors.getSdkError(Errors.USER_REJECTED).toSignError(),
      );
      return;
    }

    try {
      await kit.approveSession(
        id: event.id,
        namespaces: namespaces,
        sessionProperties: WalletConnectPolicy.approvedSessionProperties(
          requested: proposal.sessionProperties,
          namespaceKeys: namespaces.keys,
        ),
      );
      notifyListeners();
      ToastUtils.showSuccess('Connected to $dappName');
    } catch (error) {
      debugPrint('[WalletConnect] Approve session error: $error');
      ToastUtils.showError('Could not establish the WalletConnect session.');
    }
  }

  Map<String, Namespace> _buildApprovedNamespaces({
    required Map<String, RequiredNamespace> requiredNamespaces,
    required Map<String, RequiredNamespace> optionalNamespaces,
    required String? evmAddress,
    required String? solanaAddress,
    required String? tronAddress,
  }) {
    final evmChains = BlockchainCatalog.builtInChains
        .where((chain) => chain.family == ChainFamily.evm)
        .map((chain) => 'eip155:${chain.chainId}')
        .toSet();
    final availableChains = <String, Set<String>>{
      'eip155': evmChains,
      'solana': {WalletConnectPolicy.solanaMainnetChain},
      'tron': {WalletConnectPolicy.tronMainnetChain},
    };
    final addresses = <String, String?>{
      'eip155': evmAddress,
      'solana': solanaAddress,
      'tron': tronAddress,
    };
    const methods = <String, Set<String>>{
      'eip155': WalletConnectPolicy.evmMethods,
      'solana': WalletConnectPolicy.solanaMethods,
      'tron': WalletConnectPolicy.tronMethods,
    };
    const events = <String, Set<String>>{
      'eip155': WalletConnectPolicy.evmEvents,
      'solana': <String>{},
      'tron': <String>{},
    };

    final result = <String, Namespace>{};
    void addRequested(
      Map<String, RequiredNamespace> requested, {
      required bool required,
    }) {
      for (final entry in requested.entries) {
        final namespaceName = entry.key.split(':').first;
        final supportedChains = availableChains[namespaceName];
        final supportedMethods = methods[namespaceName];
        final supportedEvents = events[namespaceName];
        final address = addresses[namespaceName]?.trim();
        if (supportedChains == null ||
            supportedMethods == null ||
            supportedEvents == null ||
            address == null ||
            address.isEmpty) {
          if (required) {
            throw const WalletConnectPolicyException(
              5100,
              'A required WalletConnect namespace is unavailable.',
            );
          }
          continue;
        }

        final requestedChains =
            entry.value.chains?.toSet() ??
            (entry.key.contains(':') ? <String>{entry.key} : supportedChains);
        final approvedChains = requestedChains.intersection(supportedChains);
        final approvedMethods = entry.value.methods
            .where(supportedMethods.contains)
            .toSet();
        final approvedEvents = entry.value.events
            .where(supportedEvents.contains)
            .toSet();

        if (required &&
            (approvedChains.length != requestedChains.length ||
                approvedMethods.length != entry.value.methods.toSet().length ||
                approvedEvents.length != entry.value.events.toSet().length)) {
          throw const WalletConnectPolicyException(
            5100,
            'The DApp requires a chain, method, or event Owllet does not support.',
          );
        }
        if (approvedChains.isEmpty) {
          if (required) {
            throw const WalletConnectPolicyException(
              5100,
              'The DApp requires an unsupported chain.',
            );
          }
          continue;
        }

        final candidate = Namespace(
          chains: approvedChains.toList(),
          accounts: approvedChains.map((chain) => '$chain:$address').toList(),
          methods: approvedMethods.toList(),
          events: approvedEvents.toList(),
        );
        result[entry.key] = _mergeNamespace(result[entry.key], candidate);
      }
    }

    addRequested(requiredNamespaces, required: true);
    addRequested(optionalNamespaces, required: false);
    return result;
  }

  Namespace _mergeNamespace(Namespace? current, Namespace incoming) {
    if (current == null) return incoming;
    return Namespace(
      chains: {...?current.chains, ...?incoming.chains}.toList(),
      accounts: {...current.accounts, ...incoming.accounts}.toList(),
      methods: {...current.methods, ...incoming.methods}.toList(),
      events: {...current.events, ...incoming.events}.toList(),
    );
  }

  String? _firstApprovedAddress(Map<String, Namespace> namespaces) {
    for (final namespace in namespaces.values) {
      if (namespace.accounts.isEmpty) continue;
      final account = namespace.accounts.first;
      final first = account.indexOf(':');
      final second = first < 0 ? -1 : account.indexOf(':', first + 1);
      if (second > first && account.length > second + 1) {
        return account.substring(second + 1);
      }
    }
    return null;
  }

  /// Handle incoming Session Request (Signing / Transacting)
  Future<void> _handleSessionRequest(SessionRequestEvent? event) async {
    if (event == null) return;
    final kit = _walletKit;
    if (kit == null) return;

    final topic = event.topic;
    final session = kit.getActiveSessions()[topic];
    if (session == null) {
      await _respondError(
        kit,
        topic: topic,
        id: event.id,
        code: 4100,
        message: 'The WalletConnect session is no longer active.',
      );
      return;
    }
    final dappName = session.peer.metadata.name;
    final dappUrl = session.peer.metadata.url;
    final dappIcon = session.peer.metadata.icons.isNotEmpty
        ? session.peer.metadata.icons.first
        : null;

    final method = event.method;
    final params = event.params;
    final chainId = event.chainId;

    late final String approvedAddress;
    try {
      WalletConnectPolicy.validateSessionRequest(
        namespaces: session.namespaces,
        chainId: chainId,
        method: method,
      );
      approvedAddress = WalletConnectPolicy.approvedAddress(
        namespaces: session.namespaces,
        chainId: chainId,
      );
      await _validateActiveAccount(chainId, approvedAddress);
    } on WalletConnectPolicyException catch (error) {
      await _respondError(
        kit,
        topic: topic,
        id: event.id,
        code: error.code,
        message: error.message,
      );
      return;
    }

    final preview = _formatPayloadPreview(method, params);

    final requestModel = WcSessionRequestModel(
      id: event.id,
      topic: topic,
      method: method,
      chainId: chainId,
      dappName: dappName,
      dappUrl: dappUrl,
      dappIcon: dappIcon,
      params: params,
      formattedPreview: preview,
    );

    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      await _respondError(
        kit,
        topic: topic,
        id: event.id,
        code: -32603,
        message: 'Owllet is not ready to review this request.',
      );
      return;
    }

    final approved = await WalletConnectRequestModal.show(
      context,
      request: requestModel,
    );

    if (!approved) {
      await _respondError(
        kit,
        topic: topic,
        id: event.id,
        code: 4001,
        message: 'User rejected the request.',
      );
      return;
    }

    // Require biometric / passcode authentication
    if (!context.mounted) {
      await _respondError(
        kit,
        topic: topic,
        id: event.id,
        code: -32603,
        message: 'Owllet could not complete the request.',
      );
      return;
    }
    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: 'Authenticate to complete $dappName request.',
      requireTwoFactor: false,
    );
    if (!authenticated) {
      await _respondError(
        kit,
        topic: topic,
        id: event.id,
        code: 4001,
        message: 'Authentication was cancelled.',
      );
      return;
    }

    // Execute the requested method
    try {
      final result = await _executeRequest(
        method: method,
        params: params,
        chainId: chainId,
        approvedAddress: approvedAddress,
      );
      await kit.respondSessionRequest(
        topic: topic,
        response: JsonRpcResponse(id: event.id, result: result),
      );
      ToastUtils.showSuccess('Request completed');
    } on WalletConnectPolicyException catch (error) {
      debugPrint('[WalletConnect] Rejected $method: ${error.message}');
      await _respondError(
        kit,
        topic: topic,
        id: event.id,
        code: error.code,
        message: error.message,
      );
      ToastUtils.showError(error.message);
    } catch (error) {
      debugPrint('[WalletConnect] Execution error for $method: $error');
      await _respondError(
        kit,
        topic: topic,
        id: event.id,
        code: -32603,
        message: 'Owllet could not complete this request.',
      );
      ToastUtils.showError(
        'The WalletConnect request failed. Please try again.',
      );
    }
  }

  Future<void> _respondError(
    ReownWalletKit kit, {
    required String topic,
    required int id,
    required int code,
    required String message,
  }) {
    return kit.respondSessionRequest(
      topic: topic,
      response: JsonRpcResponse(
        id: id,
        error: JsonRpcError(code: code, message: message),
      ),
    );
  }

  Future<void> _validateActiveAccount(
    String chainId,
    String approvedAddress,
  ) async {
    final namespace = WalletConnectPolicy.namespaceForChain(chainId);
    final activeAddress = switch (namespace) {
      'eip155' => await _walletService.getCurrentWalletAddress(),
      'solana' => await _walletService.getWalletAddressForFamily(
        ChainFamily.solana,
      ),
      'tron' => await _walletService.getWalletAddressForFamily(
        ChainFamily.tron,
      ),
      _ => null,
    };
    if (activeAddress == null || activeAddress.isEmpty) {
      throw const WalletConnectPolicyException(
        4100,
        'The connected account is no longer available.',
      );
    }
    WalletConnectPolicy.requireMatchingAddress(
      requested: activeAddress,
      approved: approvedAddress,
      caseSensitive: namespace != 'eip155',
    );
  }

  Future<dynamic> _executeRequest({
    required String method,
    required dynamic params,
    required String chainId,
    required String approvedAddress,
  }) async {
    switch (method) {
      case 'personal_sign':
        final rawData = WalletConnectPolicy.extractEvmSigningPayload(
          method: method,
          params: params,
          approvedAddress: approvedAddress,
        );
        final sig = await _walletService.signMessageForAddress(
          approvedAddress,
          rawData,
        );
        return sig.startsWith('0x') ? sig : '0x$sig';

      case 'eth_signTypedData_v4':
        final typedData = WalletConnectPolicy.extractTypedData(
          params: params,
          approvedAddress: approvedAddress,
        );
        final typedJson = typedData is String
            ? typedData
            : jsonEncode(typedData);
        final sig = await _walletService.signTypedDataForAddress(
          approvedAddress,
          typedJson,
        );
        return sig.startsWith('0x') ? sig : '0x$sig';

      case 'eth_sendTransaction':
        final txMap = WalletConnectPolicy.requireTransactionMap(
          params,
          key: '',
        );
        return _sendEvmTransaction(txMap, chainId, approvedAddress);

      case 'solana_signMessage':
        return _signSolanaMessage(params, approvedAddress);

      case 'solana_signTransaction':
        return _signSolanaTransaction(params, approvedAddress);

      case 'solana_signAndSendTransaction':
        final signed = await _signSolanaTransaction(params, approvedAddress);
        final signedTransaction = signed['transaction']?.toString();
        if (signedTransaction == null || signedTransaction.isEmpty) {
          throw const WalletConnectPolicyException(
            -32603,
            'The Solana transaction could not be signed.',
          );
        }
        final txHash = await _walletService.broadcastSignedSolanaTransactionRaw(
          signedTransaction,
        );
        unawaited(
          _walletHistoryService.recordDappInteraction(
            walletAddress: approvedAddress,
            txHash: txHash,
            origin: 'WalletConnect',
            networkName: 'Solana',
            networkKey: 'solana:mainnet',
          ),
        );
        return {'signature': txHash};

      case 'solana_signAllTransactions':
        return _signAllSolanaTransactions(params, approvedAddress);

      case 'tron_signMessage':
        return _signTronMessage(params, approvedAddress);

      case 'tron_signTransaction':
        return _signTronTransaction(params, approvedAddress);

      default:
        throw const WalletConnectPolicyException(
          4200,
          'This WalletConnect method is not supported.',
        );
    }
  }

  Future<String> _sendEvmTransaction(
    Map<String, dynamic> txMap,
    String wcChainId,
    String approvedAddress,
  ) async {
    final parsedChainId = _parseEip155ChainId(wcChainId);
    final matchingChains = BlockchainCatalog.builtInChains.where(
      (chain) =>
          chain.family == ChainFamily.evm && chain.chainId == parsedChainId,
    );
    if (matchingChains.isEmpty) {
      throw const WalletConnectPolicyException(
        4200,
        'The requested EVM network is not supported.',
      );
    }
    final targetChain = matchingChains.first;
    final from = txMap['from']?.toString().trim() ?? '';
    WalletConnectPolicy.requireMatchingAddress(
      requested: from,
      approved: approvedAddress,
      caseSensitive: false,
    );

    final transactionChain = _parseBigIntQuantity(txMap['chainId'])?.toInt();
    if (transactionChain != null && transactionChain != parsedChainId) {
      throw const WalletConnectPolicyException(
        -32602,
        'The transaction chain does not match the approved network.',
      );
    }

    final gasPrice = _parseBigIntQuantity(txMap['gasPrice']);
    final maxFeePerGas = _parseBigIntQuantity(txMap['maxFeePerGas']);
    final maxPriorityFeePerGas = _parseBigIntQuantity(
      txMap['maxPriorityFeePerGas'],
    );
    if (gasPrice != null &&
        (maxFeePerGas != null || maxPriorityFeePerGas != null)) {
      throw const WalletConnectPolicyException(
        -32602,
        'The transaction mixes legacy and EIP-1559 fee fields.',
      );
    }
    if (maxFeePerGas != null &&
        maxPriorityFeePerGas != null &&
        maxPriorityFeePerGas > maxFeePerGas) {
      throw const WalletConnectPolicyException(
        -32602,
        'The transaction priority fee exceeds its maximum fee.',
      );
    }

    final transactionType = _parseBigIntQuantity(txMap['type'])?.toInt();
    if (transactionType != null &&
        transactionType != 0 &&
        transactionType != 2) {
      throw const WalletConnectPolicyException(
        4200,
        'This EVM transaction type is not supported.',
      );
    }
    if (transactionType == 0 &&
        (maxFeePerGas != null || maxPriorityFeePerGas != null)) {
      throw const WalletConnectPolicyException(
        -32602,
        'A legacy transaction cannot contain EIP-1559 fee fields.',
      );
    }
    if (transactionType == 2 && gasPrice != null) {
      throw const WalletConnectPolicyException(
        -32602,
        'An EIP-1559 transaction cannot contain a legacy gas price.',
      );
    }
    final accessList = txMap['accessList'];
    if (accessList != null && (accessList is! List || accessList.isNotEmpty)) {
      throw const WalletConnectPolicyException(
        4200,
        'EVM access-list transactions are not supported.',
      );
    }

    final resolvedRpcUrl = await _rpcService.resolveWorkingRpcUrl(
      chainId: targetChain.chainId,
      primaryRpcUrl: targetChain.rpcUrl,
    );

    final txHash = await _walletService.sendRawTransactionRequest(
      rpcUrl: resolvedRpcUrl,
      chainId: targetChain.chainId,
      toAddress: txMap['to']?.toString().trim(),
      valueInWei: _parseBigIntQuantity(txMap['value']),
      dataHex: txMap['data']?.toString(),
      gasPriceWei: gasPrice,
      maxFeePerGasWei: maxFeePerGas,
      maxPriorityFeePerGasWei: maxPriorityFeePerGas,
      gasLimit: _parseBigIntQuantity(txMap['gas'])?.toInt(),
      nonce: _parseBigIntQuantity(txMap['nonce'])?.toInt(),
    );
    final formattedHash = txHash.startsWith('0x') ? txHash : '0x$txHash';
    final valueWei = _parseBigIntQuantity(txMap['value']);
    final valueEth = valueWei != null
        ? (valueWei / BigInt.from(10).pow(18)).toStringAsFixed(6)
        : '0';

    unawaited(
      _walletHistoryService.recordDappInteraction(
        walletAddress: approvedAddress,
        txHash: formattedHash,
        origin: 'WalletConnect',
        chainId: targetChain.chainId,
        networkName: targetChain.name,
        toAddress: txMap['to']?.toString().trim(),
        valueEth: valueEth,
        networkKey: targetChain.networkKey,
      ),
    );
    return formattedHash;
  }

  int _parseEip155ChainId(String chainId) {
    if (!chainId.startsWith('eip155:')) {
      throw const WalletConnectPolicyException(
        -32602,
        'The request contains an invalid EVM chain identifier.',
      );
    }
    final parsed = int.tryParse(chainId.substring(7));
    if (parsed == null || parsed <= 0) {
      throw const WalletConnectPolicyException(
        -32602,
        'The request contains an invalid EVM chain identifier.',
      );
    }
    return parsed;
  }

  BigInt? _parseBigIntQuantity(Object? value) {
    if (value == null) return null;
    if (value is int) {
      if (value < 0) {
        throw const WalletConnectPolicyException(
          -32602,
          'The transaction contains an invalid numeric value.',
        );
      }
      return BigInt.from(value);
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parsed = text.startsWith('0x')
        ? BigInt.tryParse(text.substring(2), radix: 16)
        : BigInt.tryParse(text);
    if (parsed == null || parsed.isNegative) {
      throw const WalletConnectPolicyException(
        -32602,
        'The transaction contains an invalid numeric value.',
      );
    }
    return parsed;
  }

  Future<Map<String, dynamic>> _signSolanaMessage(
    dynamic params,
    String approvedAddress,
  ) async {
    final request = WalletConnectPolicy.requireTransactionMap(params, key: '');
    _validateOptionalAddress(request, approvedAddress, caseSensitive: true);
    final encoded = request['message']?.toString();
    if (encoded == null || encoded.isEmpty) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana message is missing.',
      );
    }
    final encoding = request['encoding']?.toString().toLowerCase();
    late final Uint8List message;
    try {
      message = encoding == 'base64'
          ? base64Decode(encoded)
          : WalletService.decodeBase58Bytes(encoded);
    } catch (_) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana message encoding is invalid.',
      );
    }
    final signature = await _walletService.signSolanaMessageRaw(
      approvedAddress,
      message,
    );
    return {'signature': signature};
  }

  Future<Map<String, dynamic>> _signSolanaTransaction(
    dynamic params,
    String approvedAddress,
  ) async {
    final request = WalletConnectPolicy.requireTransactionMap(params, key: '');
    _validateOptionalAddress(request, approvedAddress, caseSensitive: true);
    final encoded = request['transaction']?.toString();
    if (encoded == null || encoded.isEmpty) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana transaction is missing.',
      );
    }
    late final Uint8List transaction;
    try {
      transaction = base64Decode(encoded);
    } catch (_) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana transaction encoding is invalid.',
      );
    }
    final message = WalletConnectSolanaCodec.messageBytes(transaction);
    final signatureBase58 = await _walletService.signSolanaMessageRaw(
      approvedAddress,
      message,
    );
    final signature = WalletService.decodeBase58Signature(signatureBase58);
    final signed = WalletConnectSolanaCodec.attachSignature(
      transactionBytes: transaction,
      signerAddress: approvedAddress,
      signature: signature,
    );
    return WalletConnectSolanaCodec.signedTransactionResult(
      signatureBase58: signatureBase58,
      signedTransaction: signed,
    );
  }

  Future<Map<String, dynamic>> _signAllSolanaTransactions(
    dynamic params,
    String approvedAddress,
  ) async {
    final request = WalletConnectPolicy.requireTransactionMap(params, key: '');
    _validateOptionalAddress(request, approvedAddress, caseSensitive: true);
    final transactions = request['transactions'];
    if (transactions is! List ||
        transactions.isEmpty ||
        transactions.length > 20) {
      throw const WalletConnectPolicyException(
        -32602,
        'Provide between 1 and 20 Solana transactions.',
      );
    }
    final signed = <String>[];
    for (final transaction in transactions) {
      final result = await _signSolanaTransaction({
        'transaction': transaction,
      }, approvedAddress);
      signed.add(result['transaction'].toString());
    }
    return {'transactions': signed};
  }

  Future<Map<String, dynamic>> _signTronMessage(
    dynamic params,
    String approvedAddress,
  ) async {
    final request = WalletConnectPolicy.requireTransactionMap(params, key: '');
    _validateOptionalAddress(request, approvedAddress, caseSensitive: true);
    final message = request['message']?.toString();
    if (message == null || message.isEmpty) {
      throw const WalletConnectPolicyException(
        -32602,
        'The TRON message is missing.',
      );
    }
    final signature = await _walletService.signTronMessageRaw(
      approvedAddress,
      message,
    );
    return {'signature': signature};
  }

  Future<Map<String, dynamic>> _signTronTransaction(
    dynamic params,
    String approvedAddress,
  ) async {
    final outer = WalletConnectPolicy.requireTransactionMap(params, key: '');
    _validateOptionalAddress(outer, approvedAddress, caseSensitive: true);
    final transaction = WalletConnectPolicy.tronTransaction(params);
    _validateTronTransactionOwner(transaction, approvedAddress);
    final signed = await _walletService.signTronTransactionRaw(
      approvedAddress,
      transaction,
    );
    return signed;
  }

  void _validateOptionalAddress(
    Map<String, dynamic> request,
    String approvedAddress, {
    required bool caseSensitive,
  }) {
    for (final key in const [
      'address',
      'account',
      'publicKey',
      'pubkey',
      'from',
    ]) {
      final requested = request[key]?.toString().trim();
      if (requested == null || requested.isEmpty) continue;
      WalletConnectPolicy.requireMatchingAddress(
        requested: requested,
        approved: approvedAddress,
        caseSensitive: caseSensitive,
      );
    }
  }

  void _validateTronTransactionOwner(
    Map<String, dynamic> transaction,
    String approvedAddress,
  ) {
    final rawData = transaction['raw_data'] ?? transaction['rawData'];
    final contracts = rawData is Map ? rawData['contract'] : null;
    if (contracts is! List || contracts.isEmpty) {
      throw const WalletConnectPolicyException(
        -32602,
        'The TRON transaction owner could not be verified.',
      );
    }
    final decoded = WalletService.decodeBase58Bytes(approvedAddress);
    if (decoded.length < 21) {
      throw const WalletConnectPolicyException(
        4100,
        'The connected TRON account is invalid.',
      );
    }
    final expectedOwner = decoded
        .sublist(0, 21)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toLowerCase();
    for (final contract in contracts) {
      if (contract is! Map) continue;
      final parameter = contract['parameter'];
      final value = parameter is Map ? parameter['value'] : null;
      final owner = value is Map
          ? (value['owner_address'] ?? value['ownerAddress'])
                ?.toString()
                .toLowerCase()
          : null;
      if (owner == expectedOwner) return;
    }
    throw const WalletConnectPolicyException(
      4100,
      'The TRON transaction does not belong to the connected account.',
    );
  }

  String _formatPayloadPreview(String method, dynamic params) {
    try {
      if (method == 'personal_sign' || method == 'eth_sign') {
        final list = params is List ? params : [params];
        for (final item in list) {
          final s = item.toString();
          if (s.startsWith('0x') && s.length > 2) {
            try {
              final hexClean = s.substring(2);
              final decoded = utf8.decode(
                List.generate(
                  hexClean.length ~/ 2,
                  (i) => int.parse(
                    hexClean.substring(i * 2, i * 2 + 2),
                    radix: 16,
                  ),
                ),
                allowMalformed: true,
              );
              if (decoded.trim().isNotEmpty) return decoded;
            } catch (_) {}
          }
          if (!s.startsWith('0x') && s.length > 4) {
            return s;
          }
        }
      }
      return const JsonEncoder.withIndent('  ').convert(params);
    } catch (_) {
      return params.toString();
    }
  }

  void _handleSessionDelete(dynamic event) {
    notifyListeners();
  }

  /// Get all active WalletConnect sessions
  List<WcActiveSessionModel> getActiveSessions() {
    final kit = _walletKit;
    if (kit == null) return const [];

    final sessions = kit.getActiveSessions();
    return sessions.values.map((session) {
      final chains = <String>[];
      final accounts = <String>[];

      for (final ns in session.namespaces.values) {
        accounts.addAll(ns.accounts);
        if (ns.chains != null) {
          chains.addAll(ns.chains!);
        }
        chains.addAll(WalletConnectPolicy.chainsFromAccounts(ns.accounts));
      }

      return WcActiveSessionModel(
        topic: session.topic,
        pairingTopic: session.pairingTopic,
        dappName: session.peer.metadata.name,
        dappUrl: session.peer.metadata.url,
        dappDescription: session.peer.metadata.description,
        dappIcon: session.peer.metadata.icons.isNotEmpty
            ? session.peer.metadata.icons.first
            : null,
        chains: chains.toSet().toList(),
        accounts: accounts.toSet().toList(),
        expiry: DateTime.fromMillisecondsSinceEpoch(session.expiry * 1000),
      );
    }).toList();
  }

  /// Disconnect an active session
  Future<void> disconnectSession(String topic) async {
    final kit = _walletKit;
    if (kit == null) return;

    try {
      await kit.disconnectSession(
        topic: topic,
        reason: Errors.getSdkError(Errors.USER_DISCONNECTED).toSignError(),
      );
      notifyListeners();
      ToastUtils.showSuccess('Session disconnected');
    } catch (error) {
      debugPrint('[WalletConnect] Disconnect session error: $error');
      ToastUtils.showError('Failed to disconnect: $error');
    }
  }

  /// Disconnect all active sessions
  Future<void> disconnectAll() async {
    final kit = _walletKit;
    if (kit == null) return;

    final sessions = kit.getActiveSessions();
    for (final topic in sessions.keys) {
      try {
        await kit.disconnectSession(
          topic: topic,
          reason: Errors.getSdkError(Errors.USER_DISCONNECTED).toSignError(),
        );
      } catch (_) {}
    }
    notifyListeners();
    ToastUtils.showSuccess('All WalletConnect sessions disconnected');
  }
}
