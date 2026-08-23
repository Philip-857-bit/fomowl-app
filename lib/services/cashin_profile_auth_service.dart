import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'storage_service.dart';
import 'wallet_service.dart';
import 'http_client_service.dart';

/// Auth for the cash-in mini-app's profile-scoped backend endpoints
/// (`/api/cash-in/*`, `/api/profile/wallet/*`).
///
/// These endpoints require the profile JWT issued by the wallet-signature
/// handshake (`POST /profile/wallet/nonce` → SIWE message → personal_sign →
/// `POST /profile/wallet/verify`). They reject the opaque `ws_…` settings
/// session token that [WalletBackendAuthService] obtains, so cash-in host
/// calls must go through this service instead.
class CashinProfileAuthService {
  static final Map<String, Future<String>> _inflightSessionRequests =
      <String, Future<String>>{};

  /// The verify response carries no expiry; the server-side session TTL is
  /// 24h (AUTH_SESSION_TTL_SECONDS), so we conservatively re-auth after 12h.
  static const Duration _sessionLifetime = Duration(hours: 12);

  CashinProfileAuthService({
    StorageService? storageService,
    WalletService? walletService,
    HttpClientService? httpClientService,
  }) : _storageService = storageService ?? StorageService(),
       _walletService = walletService ?? WalletService(),
       _httpClientService = httpClientService ?? HttpClientService();

  final StorageService _storageService;
  final WalletService _walletService;
  final HttpClientService _httpClientService;

  Future<String?> getValidSessionToken(String walletAddress) async {
    final session = await _storageService.getCashinProfileSession(
      walletAddress,
    );
    if (session == null) return null;
    final expiresAt = DateTime.tryParse(session['expiresAt'] ?? '');
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      await _storageService.clearCashinProfileSession(walletAddress);
      return null;
    }
    return session['token'];
  }

  Future<String> ensureWalletSession(String walletAddress) async {
    final normalizedWalletAddress = walletAddress.trim().toLowerCase();
    final cached = await getValidSessionToken(normalizedWalletAddress);
    if (cached != null) return cached;

    final inFlight = _inflightSessionRequests[normalizedWalletAddress];
    if (inFlight != null) {
      return inFlight;
    }

    final sessionFuture = _createWalletSession(normalizedWalletAddress);
    _inflightSessionRequests[normalizedWalletAddress] = sessionFuture;

    try {
      return await sessionFuture;
    } finally {
      if (identical(
        _inflightSessionRequests[normalizedWalletAddress],
        sessionFuture,
      )) {
        _inflightSessionRequests.remove(normalizedWalletAddress);
      }
    }
  }

  Future<void> invalidateSession(String walletAddress) {
    return _storageService.clearCashinProfileSession(walletAddress);
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

  Future<String> _createWalletSession(String walletAddress) async {
    final nonceResponse = await _httpClientService
        .sendWithRetry(
          () => _httpClientService.client.post(
            AppEnvironment.api('/profile/wallet/nonce'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'address': walletAddress}),
          ),
        )
        .timeout(const Duration(seconds: 8));

    if (nonceResponse.statusCode != 200) {
      throw Exception(
        _extractError(nonceResponse.body, 'Unable to verify wallet ownership.'),
      );
    }

    final nonceBody = jsonDecode(nonceResponse.body) as Map<String, dynamic>;
    final nonceData = nonceBody['data'];
    if (nonceData is! Map<String, dynamic>) {
      throw Exception('Unable to verify wallet ownership.');
    }
    final message = nonceData['message']?.toString();
    if (message == null || message.isEmpty) {
      throw Exception('Unable to verify wallet ownership.');
    }

    // signMessageForAddress returns bare hex (no 0x prefix).
    final signature = await _walletService.signMessageForAddress(
      walletAddress,
      message,
    );

    final verifyResponse = await _httpClientService
        .sendWithRetry(
          () => _httpClientService.client.post(
            AppEnvironment.api('/profile/wallet/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'address': walletAddress,
              'signature': '0x$signature',
            }),
          ),
        )
        .timeout(const Duration(seconds: 8));

    if (verifyResponse.statusCode != 200) {
      throw Exception(
        _extractError(
          verifyResponse.body,
          'Unable to verify wallet ownership.',
        ),
      );
    }

    final verifyBody = jsonDecode(verifyResponse.body) as Map<String, dynamic>;
    final verifyData = verifyBody['data'];
    if (verifyData is! Map<String, dynamic>) {
      throw Exception('Unable to verify wallet ownership.');
    }
    final token = verifyData['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Unable to verify wallet ownership.');
    }

    final expiresAt = DateTime.now()
        .toUtc()
        .add(_sessionLifetime)
        .toIso8601String();
    await _storageService.saveCashinProfileSession(
      walletAddress: walletAddress,
      token: token,
      expiresAt: expiresAt,
    );
    return token;
  }

  String _extractError(String body, String fallback) {
    return AppErrorUtils.backendMessage(body, fallback: fallback);
  }
}
