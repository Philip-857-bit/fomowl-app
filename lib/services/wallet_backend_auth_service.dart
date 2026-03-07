import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import 'storage_service.dart';
import 'wallet_service.dart';

class WalletBackendAuthService {
  WalletBackendAuthService({
    StorageService? storageService,
    WalletService? walletService,
    http.Client? httpClient,
  }) : _storageService = storageService ?? StorageService(),
       _walletService = walletService ?? WalletService(),
       _httpClient = httpClient ?? http.Client();

  final StorageService _storageService;
  final WalletService _walletService;
  final http.Client _httpClient;

  Future<String?> getValidSessionToken(String walletAddress) async {
    final session = await _storageService.getBackendSession(walletAddress);
    if (session == null) return null;
    final expiresAt = DateTime.tryParse(session['expiresAt'] ?? '');
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      await _storageService.clearBackendSession(walletAddress);
      return null;
    }
    return session['token'];
  }

  Future<String> ensureWalletSession(String walletAddress) async {
    final cached = await getValidSessionToken(walletAddress);
    if (cached != null) return cached;

    final challengeResponse = await _httpClient
        .post(
          AppEnvironment.settings('/auth/challenge'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'walletAddress': walletAddress}),
        )
        .timeout(const Duration(seconds: 8));

    if (challengeResponse.statusCode != 200) {
      throw Exception(
        _extractError(
          challengeResponse.body,
          'Failed to create wallet challenge.',
        ),
      );
    }

    final challengeData =
        jsonDecode(challengeResponse.body) as Map<String, dynamic>;
    final challenge = challengeData['challenge']?.toString();
    final message = challengeData['message']?.toString();
    if (challenge == null ||
        challenge.isEmpty ||
        message == null ||
        message.isEmpty) {
      throw Exception('Backend challenge response was incomplete.');
    }

    final signature = await _walletService.signMessageForAddress(
      walletAddress,
      message,
    );

    final verifyResponse = await _httpClient
        .post(
          AppEnvironment.settings('/auth/verify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletAddress': walletAddress,
            'challenge': challenge,
            'signature': '0x$signature',
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (verifyResponse.statusCode != 200) {
      throw Exception(
        _extractError(verifyResponse.body, 'Wallet authentication failed.'),
      );
    }

    final verifyData = jsonDecode(verifyResponse.body) as Map<String, dynamic>;
    final token = verifyData['token']?.toString();
    final expiresAt = verifyData['expiresAt']?.toString();
    if (token == null ||
        token.isEmpty ||
        expiresAt == null ||
        expiresAt.isEmpty) {
      throw Exception('Backend verification response was incomplete.');
    }

    await _storageService.saveBackendSession(
      walletAddress: walletAddress,
      token: token,
      expiresAt: expiresAt,
    );
    return token;
  }

  Future<void> invalidateSession(String walletAddress) {
    return _storageService.clearBackendSession(walletAddress);
  }

  Future<http.Response> sendAuthorized(
    String walletAddress,
    Future<http.Response> Function(Map<String, String> headers) send,
    Map<String, String> headers,
  ) async {
    final initialHeaders = await _buildAuthHeaders(walletAddress, headers);
    final firstResponse = await send(initialHeaders);
    if (firstResponse.statusCode != 401) {
      return firstResponse;
    }

    await invalidateSession(walletAddress);
    final retryHeaders = await _buildAuthHeaders(walletAddress, headers);
    return send(retryHeaders);
  }

  Future<Map<String, String>> _buildAuthHeaders(
    String walletAddress,
    Map<String, String> headers,
  ) async {
    final token = await ensureWalletSession(walletAddress);
    return {...headers, 'Authorization': 'Bearer $token'};
  }

  String _extractError(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return fallback;
  }
}
