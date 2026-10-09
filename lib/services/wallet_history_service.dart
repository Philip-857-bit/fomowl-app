import 'dart:async';
import '../models/bitcoin_account_history.dart';
import '../models/bitcoin_account_state.dart';
import '../utils/bitcoin_amount_utils.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import 'http_client_service.dart';

class WalletHistoryEntry {
  const WalletHistoryEntry({
    required this.id,
    required this.walletAddress,
    required this.networkName,
    required this.eventType,
    required this.title,
    required this.message,
    required this.isIncoming,
    required this.createdAt,
    required this.source,
    this.chainId,
    this.txHash,
    this.tokenName,
    this.tokenSymbol,
    this.amount,
    this.networkKey,
    this.bitcoin,
  });

  final String id;
  final String walletAddress;
  final int? chainId;
  final String networkName;
  final String? txHash;
  final String eventType;
  final String title;
  final String message;
  final String? tokenName;
  final String? tokenSymbol;
  final double? amount;
  final bool isIncoming;
  final DateTime createdAt;
  final String source;
  final String? networkKey;
  final BitcoinAccountHistoryEntry? bitcoin;

  factory WalletHistoryEntry.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString() ?? '';
    return WalletHistoryEntry(
      id: json['id']?.toString() ?? '',
      walletAddress: json['walletAddress']?.toString() ?? '',
      chainId: _decodeInt(json['chainId']),
      networkName: json['networkName']?.toString() ?? 'Unknown network',
      txHash: json['txHash']?.toString(),
      eventType: json['eventType']?.toString() ?? 'receive',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      tokenName: json['tokenName']?.toString(),
      tokenSymbol: json['tokenSymbol']?.toString(),
      amount: _decodeDouble(json['amount']),
      isIncoming: json['isIncoming'] == true,
      createdAt: DateTime.tryParse(createdAtRaw) ?? DateTime.now(),
      source: json['source']?.toString() ?? 'local_history',
      networkKey: json['networkKey']?.toString(),
    );
  }

  static int? _decodeInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _decodeDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class WalletHistoryResponse {
  const WalletHistoryResponse({
    required this.history,
    required this.partial,
    this.message,
  });

  final List<WalletHistoryEntry> history;
  final bool partial;
  final String? message;

  factory WalletHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List<dynamic>? ?? const [];
    return WalletHistoryResponse(
      history: rawHistory
          .whereType<Map<String, dynamic>>()
          .map(WalletHistoryEntry.fromJson)
          .toList(),
      partial: json['partial'] == true,
      message: json['message']?.toString(),
    );
  }
}

class WalletHistoryService {
  WalletHistoryService({HttpClientService? httpClientService})
    : _httpClientService = httpClientService ?? HttpClientService();

  final HttpClientService _httpClientService;

  Future<WalletHistoryResponse> fetchWalletHistory({
    required String walletAddress,
    int? chainId,
    String type = 'all',
    int limit = 100,
  }) async {
    final query = <String, String>{'type': type, 'limit': '$limit'};
    if (chainId != null) {
      query['chainId'] = '$chainId';
    }

    final response = await _httpClientService
        .sendWithRetry(
          () => _httpClientService.client.get(
            AppEnvironment.history('/wallet/$walletAddress', query),
          ),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Wallet history request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Wallet history response was malformed.');
    }
    return WalletHistoryResponse.fromJson(decoded);
  }

  Future<void> recordBitcoinSend({
    required String walletIdentity,
    required String txid,
    required BitcoinProductNetwork network,
    required BigInt amountSats,
    required String recipient,
  }) {
    final amount = BitcoinAmountUtils.format(amountSats);
    return _recordHistory({
      'walletAddress': walletIdentity,
      'txHash': txid,
      'txType': 'send',
      'tokenName': 'Bitcoin',
      'tokenSymbol': 'BTC',
      'amount': _parseAmount(amount),
      'isIncoming': false,
      'networkName': network == BitcoinProductNetwork.mainnet
          ? 'Bitcoin'
          : 'Bitcoin Testnet4',
      'networkKey': network.networkKey,
      'title': 'Bitcoin submitted',
      'message': 'Submitted $amount BTC to $recipient.',
    });
  }

  Future<void> recordSendConfirmed({
    required String walletAddress,
    required String txHash,
    required int chainId,
    required String networkName,
    required String tokenName,
    required String tokenSymbol,
    required String amountText,
    required String toAddress,
    String? tokenAddress,
    String? networkKey,
  }) {
    return _recordHistory({
      'walletAddress': walletAddress,
      'txHash': txHash,
      'txType': 'send',
      'tokenName': tokenName,
      'tokenSymbol': tokenSymbol,
      if (tokenAddress?.trim().isNotEmpty == true)
        'tokenAddress': tokenAddress!.trim(),
      'amount': _parseAmount(amountText),
      'isIncoming': false,
      'chainId': chainId,
      'networkName': networkName,
      'networkKey': networkKey,
      'title': 'Transfer sent',
      'message':
          'Sent $amountText $tokenSymbol to ${_shortAddress(toAddress)} on $networkName.',
    });
  }

  Future<void> recordSwapConfirmed({
    required String walletAddress,
    String? txHash,
    required int chainId,
    required String networkName,
    required String fromTokenName,
    required String fromTokenSymbol,
    required String fromAmount,
    required String toAmount,
    required String toTokenSymbol,
    String? networkKey,
  }) {
    return _recordHistory({
      'walletAddress': walletAddress,
      'txHash': txHash,
      'txType': 'swap',
      'tokenName': fromTokenName,
      'tokenSymbol': fromTokenSymbol,
      'amount': _parseAmount(fromAmount),
      'isIncoming': false,
      'chainId': chainId,
      'networkName': networkName,
      'networkKey': networkKey,
      'title': 'Swap confirmed',
      'message':
          'Swapped $fromAmount $fromTokenSymbol for $toAmount $toTokenSymbol on $networkName.',
    });
  }

  Future<void> recordBridgeSubmitted({
    required String walletAddress,
    required String txHash,
    required int chainId,
    required String networkName,
    required String fromTokenSymbol,
    required String fromAmount,
    required String toTokenSymbol,
    required String destinationNetworkName,
    String? networkKey,
  }) {
    return _recordHistory({
      'walletAddress': walletAddress,
      'txHash': txHash,
      'txType': 'bridge',
      'tokenName': fromTokenSymbol,
      'tokenSymbol': fromTokenSymbol,
      'amount': _parseAmount(fromAmount),
      'isIncoming': false,
      'chainId': chainId,
      'networkName': networkName,
      'networkKey': networkKey,
      'title': 'Bridge submitted',
      'message':
          'Bridging $fromAmount $fromTokenSymbol from $networkName to $toTokenSymbol on $destinationNetworkName.',
    });
  }

  Future<void> recordDappConfirmed({
    required String walletAddress,
    required String txHash,
    required int chainId,
    required String networkName,
    required String miniAppName,
    required String tokenName,
    required String tokenSymbol,
    required String amountText,
    required String toAddress,
    String? networkKey,
  }) {
    return _recordHistory({
      'walletAddress': walletAddress,
      'txHash': txHash,
      'txType': 'dapp',
      'tokenName': tokenName,
      'tokenSymbol': tokenSymbol,
      'amount': _parseAmount(amountText),
      'isIncoming': false,
      'chainId': chainId,
      'networkName': networkName,
      'networkKey': networkKey,
      'title': '$miniAppName transaction',
      'message':
          '$miniAppName sent $amountText $tokenSymbol to ${_shortAddress(toAddress)} on $networkName.',
    });
  }

  Future<void> recordDappInteraction({
    required String walletAddress,
    required String txHash,
    required String origin,
    int? chainId,
    required String networkName,
    String? toAddress,
    String? valueEth,
    String? networkKey,
  }) {
    final host = Uri.tryParse(origin)?.host ?? origin;
    final cleanHost = host.isEmpty ? origin : host;
    final isContract = toAddress != null && toAddress.trim().isNotEmpty;
    final title = '$cleanHost interaction';
    final message = isContract
        ? 'Contract interaction with ${_shortAddress(toAddress)} via $cleanHost on $networkName.'
        : 'Transaction executed via $cleanHost on $networkName.';

    return _recordHistory({
      'walletAddress': walletAddress,
      'txHash': txHash,
      'txType': 'dapp_interaction',
      'tokenName': 'Smart Contract',
      'tokenSymbol': 'DAPP',
      if (toAddress != null && toAddress.trim().isNotEmpty)
        'tokenAddress': toAddress.trim(),
      'amount': _parseAmount(valueEth ?? '0'),
      'isIncoming': false,
      'chainId': ?chainId,
      'networkName': networkName,
      'networkKey': networkKey,
      'title': title,
      'message': message,
    });
  }

  Future<void> _recordHistory(Map<String, dynamic> payload) async {
    try {
      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              AppEnvironment.history('/add'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Wallet history creation failed: ${response.statusCode}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Wallet history creation failed: $error');
      debugPrint(stackTrace.toString());
    }
  }

  double _parseAmount(String rawValue) {
    return double.tryParse(rawValue.replaceAll(',', '').trim()) ?? 0.0;
  }

  String _shortAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 10) {
      return trimmed;
    }
    return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
  }
}
