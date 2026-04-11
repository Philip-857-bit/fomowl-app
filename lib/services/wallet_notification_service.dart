import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import 'app_notification_service.dart';
import 'http_client_service.dart';

class WalletNotificationService {
  WalletNotificationService({HttpClientService? httpClientService})
    : _httpClientService = httpClientService ?? HttpClientService();

  final HttpClientService _httpClientService;

  Future<void> notifySendConfirmed({
    required String walletAddress,
    required int chainId,
    required String txHash,
    required String amountText,
    required String tokenSymbol,
    required String toAddress,
    required String networkName,
  }) {
    return _createNotification(
      walletAddress: walletAddress,
      title: 'Transfer confirmed',
      message:
          'Sent $amountText $tokenSymbol to ${_shortAddress(toAddress)} on $networkName.',
      dedupeKey: _buildTxDedupeKey(chainId: chainId, txHash: txHash),
    );
  }

  Future<void> notifySwapConfirmed({
    required String walletAddress,
    required int chainId,
    String? txHash,
    required String fromAmount,
    required String fromSymbol,
    required String toAmount,
    required String toSymbol,
    required String networkName,
  }) {
    return _createNotification(
      walletAddress: walletAddress,
      title: 'Swap confirmed',
      message:
          'Swapped $fromAmount $fromSymbol for $toAmount $toSymbol on $networkName.',
      dedupeKey: _buildOptionalTxDedupeKey(chainId: chainId, txHash: txHash),
    );
  }

  Future<void> _createNotification({
    required String walletAddress,
    required String title,
    required String message,
    String? dedupeKey,
  }) async {
    try {
      final payload = <String, dynamic>{
        'wallet_address': walletAddress,
        'title': title,
        'message': message,
        ...?dedupeKey == null ? null : {'dedupeKey': dedupeKey},
      };

      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              AppEnvironment.notifications('/add'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Wallet notification creation failed: ${response.statusCode}',
        );
        return;
      }
      AppNotificationService().announceInboxChanged(
        walletAddress: walletAddress,
      );
    } catch (error, stackTrace) {
      debugPrint('Wallet notification creation failed: $error');
      debugPrint(stackTrace.toString());
    }
  }

  String _shortAddress(String address) {
    final normalized = address.trim();
    if (normalized.length < 10) {
      return normalized;
    }
    return '${normalized.substring(0, 6)}...${normalized.substring(normalized.length - 4)}';
  }

  String _buildTxDedupeKey({required int chainId, required String txHash}) {
    final normalizedHash = txHash.trim().toLowerCase();
    return 'tx:$chainId:$normalizedHash';
  }

  String? _buildOptionalTxDedupeKey({required int chainId, String? txHash}) {
    if (txHash == null) {
      return null;
    }
    final normalizedHash = txHash.trim();
    if (normalizedHash.isEmpty) {
      return null;
    }
    return _buildTxDedupeKey(chainId: chainId, txHash: normalizedHash);
  }
}
