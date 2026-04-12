import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';

import '../config/app_environment.dart';
import '../models/token.dart';
import '../utils/app_error_utils.dart';
import 'blockchain_service.dart';
import 'rpc_service.dart';
import 'swap_service.dart'; // Still needed for SwapQuote
import 'wallet_service.dart';
import 'http_client_service.dart';

class SwapExecutionResult {
  final bool success;
  final String? transactionHash;
  final String? tradeHash;
  final String? error;

  const SwapExecutionResult({
    required this.success,
    this.transactionHash,
    this.tradeHash,
    this.error,
  });
}

class SwapExecutionService {
  final WalletService _walletService;
  final HttpClientService _httpClientService = HttpClientService();
  final RpcService _rpcService = RpcService();
  static const int _eip712SignatureType = 2;

  SwapExecutionService({
    WalletService? walletService,
    SwapService? swapService, // Kept constructor sig for compatibility
  }) : _walletService = walletService ?? WalletService();

  Future<String> _resolveRpcUrl(BlockchainService blockchain) {
    return _rpcService.resolveWorkingRpcUrl(
      chainId: blockchain.activeChain.chainId,
      primaryRpcUrl: blockchain.activeChain.rpcUrl,
    );
  }

  /// Builds calldata via backend and broadcasts the swap transaction.
  Future<SwapExecutionResult> execute({
    required SwapQuote quote, // Kept for API compatibility with callers.
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required double expectedToAmount,
    required int slippageBps,
    required BlockchainService blockchain,
    required String recipientAddress,
    required bool isGasless,
  }) async {
    try {
      if (isGasless) {
        return await _executeFusion(
          fromToken: fromToken,
          toToken: toToken,
          fromAmountWei: fromAmountWei,
          slippageBps: slippageBps,
          blockchain: blockchain,
          walletAddress: recipientAddress,
        );
      } else {
        return await _executeStandard(
          fromToken: fromToken,
          toToken: toToken,
          fromAmountWei: fromAmountWei,
          slippageBps: slippageBps,
          blockchain: blockchain,
          walletAddress: recipientAddress,
        );
      }
    } catch (e) {
      debugPrint('Swap execution failed: $e');
      return SwapExecutionResult(
        success: false,
        error: AppErrorUtils.userMessage(
          e,
          fallback: 'Swap execution failed. Please try again.',
        ),
      );
    }
  }

  Future<SwapExecutionResult> _executeStandard({
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required int slippageBps,
    required BlockchainService blockchain,
    required String walletAddress,
  }) async {
    final rpcUrl = await _resolveRpcUrl(blockchain);
    final client = Web3Client(rpcUrl, _httpClientService.client);
    try {
      // Always fetch a fresh firm quote close to broadcast to avoid stale RFQ data.
      final src = fromToken.contractAddress?.isNotEmpty == true
          ? fromToken.contractAddress!
          : '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
      final dst = toToken.contractAddress?.isNotEmpty == true
          ? toToken.contractAddress!
          : '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

      final rawAmountStr = fromAmountWei;

      final url = AppEnvironment.swap('/quote', {
        'chainId': '${blockchain.activeChain.chainId}',
        'src': src,
        'dst': dst,
        'amount': rawAmountStr,
        'taker': walletAddress,
        'slippageBps': '$slippageBps',
      });

      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(
          _extractBackendMessage(
            response.body,
            'Swap execution could not be prepared.',
          ),
        );
      }

      final data = _decodeJsonMap(
        response.body,
        fallback: 'Swap execution response was incomplete. Please try again.',
      );
      final txData = _asMap(data['transaction']) ?? data;

      // 2. Prepare Web3 Transaction
      if (txData['to'] == null) {
        throw Exception(
          'Swap quote was missing executable transaction fields. Please refresh the quote and try again.',
        );
      }
      final toAddress = EthereumAddress.fromHex(txData['to'].toString());

      final gasPriceStr = txData['gasPrice']?.toString();
      final gasPrice = gasPriceStr != null ? _parseBigInt(gasPriceStr) : null;
      if (gasPrice == null) {
        throw Exception(
          'Swap quote was missing executable transaction fields. Please refresh the quote and try again.',
        );
      }

      final dataStr = txData['data']?.toString();
      if (dataStr == null) {
        throw Exception(
          'Swap quote was missing executable transaction fields. Please refresh the quote and try again.',
        );
      }
      final dataBytes = hexToBytes(dataStr.replaceFirst('0x', ''));

      final valueStr = txData['value']?.toString();
      final valueWei = valueStr != null ? _parseBigInt(valueStr) : null;
      if (valueWei == null) {
        throw Exception(
          'Swap quote was missing executable transaction fields. Please refresh the quote and try again.',
        );
      }

      final tx = Transaction(
        to: toAddress,
        data: dataBytes,
        value: EtherAmount.inWei(valueWei),
        gasPrice: EtherAmount.inWei(gasPrice),
        maxGas: _parseInt(txData['gas']?.toString()),
      );

      final credentials = await _walletService.getCredentials();

      // 3. Broadcast
      final txHash = await client.sendTransaction(
        credentials,
        tx,
        chainId: blockchain.activeChain.chainId,
        fetchChainIdFromNetworkId: false,
      );

      return SwapExecutionResult(success: true, transactionHash: txHash);
    } finally {
      // client.dispose() intentionally removed — HttpClient is a shared singleton.
    }
  }

  Future<SwapExecutionResult> _executeFusion({
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required int slippageBps,
    required BlockchainService blockchain,
    required String walletAddress,
  }) async {
    try {
      final src = fromToken.contractAddress?.isNotEmpty == true
          ? fromToken.contractAddress!
          : '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
      final dst = toToken.contractAddress?.isNotEmpty == true
          ? toToken.contractAddress!
          : '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

      final rawAmountStr = fromAmountWei;

      // 1. Get Gasless Quote
      final quoteUrl = AppEnvironment.swap('/fusion/quote', {
        'chainId': '${blockchain.activeChain.chainId}',
        'fromTokenAddress': src,
        'toTokenAddress': dst,
        'amount': rawAmountStr,
        'walletAddress': walletAddress,
        'slippageBps': '$slippageBps',
      });

      final quoteResponse = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(quoteUrl))
          .timeout(const Duration(seconds: 15));
      if (quoteResponse.statusCode != 200) {
        throw Exception(
          _extractBackendMessage(
            quoteResponse.body,
            'Gasless quote request failed.',
          ),
        );
      }

      final quoteData = _decodeJsonMap(
        quoteResponse.body,
        fallback: 'Gasless quote response was incomplete. Please try again.',
      );

      // 0x Gasless Payload Extraction
      final trade = _asMap(quoteData['trade']);
      final approval = _asMap(quoteData['approval']);
      final permit2 = _asMap(quoteData['permit2']);
      Map<String, dynamic>? eip712Data =
          _asMap(trade?['eip712']) ??
          _asMap(permit2?['eip712']) ??
          _asMap(quoteData['eip712']);

      if (eip712Data == null) {
        throw Exception(
          'Backend quote did not contain an EIP-712 signature payload. Check 0x Permit2 response schemas.',
        );
      }

      // 2. Sign EIP-712 Payloads
      String? approvalSignature;
      final approvalEip712 = _asMap(approval?['eip712']);
      if (approvalEip712 != null) {
        try {
          approvalSignature = await _walletService.signTypedData(
            jsonEncode(approvalEip712),
          );
        } catch (e) {
          throw Exception('Failed to sign gasless approval payload: $e');
        }
      }

      String tradeSignature;
      try {
        final eip712JsonString = jsonEncode(eip712Data);
        tradeSignature = await _walletService.signTypedData(eip712JsonString);
      } catch (e) {
        throw Exception('Failed to sign gasless trade payload: $e');
      }

      // 3. Submit Signed Order
      final submitUrl = AppEnvironment.swap(
        '/fusion/order/submit/${blockchain.activeChain.chainId}',
      );

      final submitPayload = _buildFusionSubmitPayload(
        quoteData: quoteData,
        tradeSignature: tradeSignature,
        approvalSignature: approvalSignature,
        chainId: blockchain.activeChain.chainId,
      );

      final submitResponse = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              submitUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(submitPayload),
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (submitResponse.statusCode != 200) {
        throw Exception(
          _extractBackendMessage(
            submitResponse.body,
            'Gasless order submission failed.',
          ),
        );
      }

      final submitData = _decodeJsonMap(
        submitResponse.body,
        fallback: 'Gasless order response was incomplete. Please try again.',
      );
      final String? transactionHash =
          submitData['transactionHash']?.toString() ??
          submitData['txHash']?.toString();
      final String? tradeHash =
          submitData['tradeHash']?.toString() ??
          submitData['hash']?.toString() ??
          submitData['orderHash']?.toString() ??
          submitData['orderId']?.toString();

      if (transactionHash == null && tradeHash == null) {
        throw Exception(
          'Backend submission response did not contain a recognizable hash or ID. Response: ${submitResponse.body}',
        );
      }

      return SwapExecutionResult(
        success: true,
        transactionHash: transactionHash,
        tradeHash: tradeHash,
      );
    } catch (e) {
      debugPrint('Fusion execution failed: $e');
      return SwapExecutionResult(
        success: false,
        error: AppErrorUtils.userMessage(
          e,
          fallback: 'Gasless swap failed. Please try again.',
        ),
      );
    }
  }

  String _extractBackendMessage(String body, String fallback) {
    return AppErrorUtils.backendMessage(body, fallback: fallback);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return null;
  }

  Map<String, dynamic> _decodeJsonMap(String body, {required String fallback}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception(fallback);
    }

    try {
      final decoded = _asMap(jsonDecode(trimmed));
      if (decoded == null) {
        throw Exception(fallback);
      }
      return decoded;
    } on FormatException {
      throw Exception(fallback);
    }
  }

  Map<String, dynamic> _buildFusionSubmitPayload({
    required Map<String, dynamic> quoteData,
    required String tradeSignature,
    String? approvalSignature,
    required int chainId,
  }) {
    final payload = <String, dynamic>{'chainId': '$chainId'};
    final trade = _asMap(quoteData['trade']);
    if (trade != null) {
      payload['trade'] = _buildFusionSignedPayloadObject(
        source: trade,
        signature: tradeSignature,
      );
    }

    final approval = _asMap(quoteData['approval']);
    if (approval != null && approvalSignature != null) {
      payload['approval'] = _buildFusionSignedPayloadObject(
        source: approval,
        signature: approvalSignature,
      );
    }

    return payload;
  }

  Map<String, dynamic> _buildFusionSignedPayloadObject({
    required Map<String, dynamic> source,
    required String signature,
  }) {
    final payload = <String, dynamic>{};
    final type = source['type']?.toString();
    if (type != null && type.isNotEmpty) {
      payload['type'] = type;
    }
    final eip712 = _asMap(source['eip712']);
    if (eip712 != null) {
      payload['eip712'] = eip712;
    }
    payload['signature'] = _splitSignature(signature);
    return payload;
  }

  Map<String, dynamic> _splitSignature(String signature) {
    final normalized = signature.startsWith('0x') ? signature : '0x$signature';
    final hex = normalized.substring(2);
    if (hex.length != 130) {
      throw FormatException(
        'Expected 65-byte signature, received ${hex.length ~/ 2} bytes.',
      );
    }

    final r = hex.substring(0, 64).padLeft(64, '0');
    final s = hex.substring(64, 128).padLeft(64, '0');
    final v = int.parse(hex.substring(128, 130), radix: 16);

    return <String, dynamic>{
      'r': '0x$r',
      's': '0x$s',
      'v': v,
      'signatureType': _eip712SignatureType,
    };
  }

  /// Parse a numeric string that may be decimal ("1000000") or hex ("0x...").
  static BigInt? _parseBigInt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return BigInt.tryParse(trimmed.substring(2), radix: 16);
    }
    return BigInt.tryParse(trimmed);
  }

  /// Parse an int from decimal or hex string.
  static int? _parseInt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return int.tryParse(trimmed.substring(2), radix: 16);
    }
    return int.tryParse(trimmed);
  }
}
