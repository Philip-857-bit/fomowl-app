import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';

import '../models/token.dart';
import 'blockchain_service.dart';
import 'swap_service.dart'; // Still needed for SwapQuote
import 'wallet_service.dart';

class SwapExecutionResult {
  final bool success;
  final String? transactionHash;
  final String? error;

  const SwapExecutionResult({
    required this.success,
    this.transactionHash,
    this.error,
  });
}

class SwapExecutionService {
  final WalletService _walletService;

  SwapExecutionService({
    WalletService? walletService,
    SwapService? swapService, // Kept constructor sig for compatibility
  }) : _walletService = walletService ?? WalletService();

  static const String _backendApiBase =
      'https://fomowl-backend.onrender.com/api/swap';

  /// Builds calldata via backend and broadcasts the swap transaction.
  Future<SwapExecutionResult> execute({
    required SwapQuote
    quote, // Keep signature compatibility, despite us re-querying 1inch for calldata
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required double expectedToAmount,
    required double slippagePercent,
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
          blockchain: blockchain,
          walletAddress: recipientAddress,
        );
      } else {
        return await _executeStandard(
          fromToken: fromToken,
          toToken: toToken,
          fromAmountWei: fromAmountWei,
          slippagePercent: slippagePercent,
          blockchain: blockchain,
          walletAddress: recipientAddress,
        );
      }
    } catch (e) {
      debugPrint('Swap execution failed: $e');
      return SwapExecutionResult(success: false, error: e.toString());
    }
  }

  Future<SwapExecutionResult> _executeStandard({
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required double slippagePercent,
    required BlockchainService blockchain,
    required String walletAddress,
  }) async {
    final client = Web3Client(blockchain.activeChain.rpcUrl, http.Client());
    try {
      // 1. Fetch swap transaction payload from Backend
      final src = fromToken.contractAddress?.isNotEmpty == true
          ? fromToken.contractAddress!
          : '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
      final dst = toToken.contractAddress?.isNotEmpty == true
          ? toToken.contractAddress!
          : '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

      final rawAmountStr = fromAmountWei;

      final url = Uri.parse(
        '$_backendApiBase/transaction'
        '?chainId=${blockchain.activeChain.chainId}'
        '&src=$src'
        '&dst=$dst'
        '&amount=$rawAmountStr'
        '&from=$walletAddress'
        '&slippage=$slippagePercent',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(
          'Backend returned swap compilation error: ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final txData = data['transaction'];
      if (txData == null) {
        throw Exception('Backend returned null tx object');
      }

      // 2. Prepare Web3 Transaction
      if (txData['to'] == null) {
        throw Exception('Backend returned tx object with missing "to" field');
      }
      final toAddress = EthereumAddress.fromHex(txData['to'].toString());

      final gasPriceStr = txData['gasPrice']?.toString();
      final gasPrice = gasPriceStr != null
          ? BigInt.tryParse(gasPriceStr)
          : null;
      if (gasPrice == null) {
        throw Exception('Invalid or missing gasPrice in txData: $gasPriceStr');
      }

      final dataStr = txData['data']?.toString();
      if (dataStr == null) {
        throw Exception('Missing "data" field in txData');
      }
      final dataBytes = hexToBytes(dataStr.replaceFirst('0x', ''));

      final valueStr = txData['value']?.toString();
      final valueWei = valueStr != null ? BigInt.tryParse(valueStr) : null;
      if (valueWei == null) {
        throw Exception('Invalid or missing value in txData: $valueStr');
      }

      final tx = Transaction(
        to: toAddress,
        data: dataBytes,
        value: EtherAmount.inWei(valueWei),
        gasPrice: EtherAmount.inWei(gasPrice),
        // let web3dart estimate maxGas, or provide conservative default
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
      client.dispose();
    }
  }

  Future<SwapExecutionResult> _executeFusion({
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
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
      final quoteUrl = Uri.parse(
        '$_backendApiBase/fusion/quote'
        '?chainId=${blockchain.activeChain.chainId}'
        '&fromTokenAddress=$src'
        '&toTokenAddress=$dst'
        '&amount=$rawAmountStr'
        '&walletAddress=$walletAddress',
      );

      final quoteResponse = await http
          .get(quoteUrl)
          .timeout(const Duration(seconds: 15));
      if (quoteResponse.statusCode != 200) {
        throw Exception(
          'Backend returned gasless quote error: ${quoteResponse.body}',
        );
      }

      final quoteData = jsonDecode(quoteResponse.body);

      // 0x Gasless Payload Extraction
      Map<String, dynamic>? eip712Data;
      if (quoteData['trade'] != null && quoteData['trade']['eip712'] != null) {
        eip712Data = quoteData['trade']['eip712'];
      } else if (quoteData['permit2'] != null &&
          quoteData['permit2']['eip712'] != null) {
        eip712Data = quoteData['permit2']['eip712'];
      } else if (quoteData['eip712'] != null) {
        eip712Data = quoteData['eip712'];
      }

      if (eip712Data == null) {
        throw Exception(
          'Backend quote did not contain an EIP-712 signature payload. Check 0x Permit2 response schemas.',
        );
      }

      // 2. Sign EIP-712 Payload
      String signature;
      try {
        final eip712JsonString = jsonEncode(eip712Data);
        signature = await _walletService.signTypedData(eip712JsonString);
      } catch (e) {
        throw Exception('Failed to sign gasless Permit2 payload: $e');
      }

      // 3. Submit Signed Order
      final submitUrl = Uri.parse(
        '$_backendApiBase/fusion/order/submit/${blockchain.activeChain.chainId}',
      );

      final submitPayload = Map<String, dynamic>.from(quoteData);
      submitPayload['signature'] = signature;

      final submitResponse = await http
          .post(
            submitUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(submitPayload),
          )
          .timeout(const Duration(seconds: 15));

      if (submitResponse.statusCode != 200) {
        throw Exception(
          'Backend relative order submission failed: ${submitResponse.body}',
        );
      }

      final submitData = jsonDecode(submitResponse.body);
      final String? transactionHash =
          submitData['transactionHash']?.toString() ??
          submitData['hash']?.toString() ??
          submitData['orderHash']?.toString() ??
          submitData['orderId']?.toString();

      if (transactionHash == null) {
        throw Exception(
          'Backend submission response did not contain a recognizable hash or ID. Response: ${submitResponse.body}',
        );
      }

      return SwapExecutionResult(
        success: true,
        transactionHash: transactionHash,
      );
    } catch (e) {
      debugPrint('Fusion execution failed: $e');
      return SwapExecutionResult(success: false, error: e.toString());
    }
  }
}
