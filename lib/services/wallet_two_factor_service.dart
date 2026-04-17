import 'dart:convert';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';
import 'wallet_backend_auth_service.dart';
import 'wallet_service.dart';

class WalletTwoFactorService {
  WalletTwoFactorService({
    WalletService? walletService,
    WalletBackendAuthService? walletBackendAuthService,
    HttpClientService? httpClientService,
  }) : _walletService = walletService ?? WalletService(),
       _walletBackendAuthService =
           walletBackendAuthService ?? WalletBackendAuthService(),
       _httpClientService = httpClientService ?? HttpClientService();

  final WalletService _walletService;
  final WalletBackendAuthService _walletBackendAuthService;
  final HttpClientService _httpClientService;

  Future<Map<String, dynamic>> fetchTwoFactorStatus() async {
    final walletAddress = await _activeWalletAddress();
    if (walletAddress == null) {
      return _missingWallet();
    }

    try {
      final encodedWallet = Uri.encodeComponent(walletAddress);
      final response = await _walletBackendAuthService.sendAuthorized(
        walletAddress,
        (headers) => _httpClientService.client.get(
          AppEnvironment.settings('/2fa/status/$encodedWallet'),
          headers: headers,
        ),
        const <String, String>{},
      );

      final data = _decodeObject(response.body) ?? <String, dynamic>{};
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return {'success': true, ...payload};
        }
      }

      return _error(
        response.body,
        'Unable to load wallet 2FA status right now.',
      );
    } catch (error) {
      return _exception(error, 'Unable to load wallet 2FA status right now.');
    }
  }

  Future<Map<String, dynamic>> beginTwoFactorSetup() async {
    final walletAddress = await _activeWalletAddress();
    if (walletAddress == null) {
      return _missingWallet();
    }

    try {
      final response = await _walletBackendAuthService.sendAuthorized(
        walletAddress,
        (headers) => _httpClientService.client.post(
          AppEnvironment.settings('/2fa/setup'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'walletAddress': walletAddress}),
        ),
        const <String, String>{'Content-Type': 'application/json'},
      );

      final data = _decodeObject(response.body) ?? <String, dynamic>{};
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return {'success': true, ...payload};
        }
      }

      return _error(
        response.body,
        'Unable to start wallet 2FA setup right now.',
      );
    } catch (error) {
      return _exception(error, 'Unable to start wallet 2FA setup right now.');
    }
  }

  Future<Map<String, dynamic>> verifyTwoFactorSetup({
    required String code,
  }) async {
    return _postCode(
      path: '/2fa/verify',
      code: code,
      fallback: 'Unable to activate wallet 2FA right now.',
    );
  }

  Future<Map<String, dynamic>> confirmTwoFactorCode({
    required String code,
  }) async {
    return _postCode(
      path: '/2fa/confirm',
      code: code,
      fallback: 'Unable to verify the authenticator code right now.',
    );
  }

  Future<Map<String, dynamic>> disableTwoFactor({required String code}) async {
    return _postCode(
      path: '/2fa/disable',
      code: code,
      fallback: 'Unable to disable wallet 2FA right now.',
    );
  }

  Future<Map<String, dynamic>> _postCode({
    required String path,
    required String code,
    required String fallback,
  }) async {
    final walletAddress = await _activeWalletAddress();
    if (walletAddress == null) {
      return _missingWallet();
    }

    try {
      final response = await _walletBackendAuthService.sendAuthorized(
        walletAddress,
        (headers) => _httpClientService.client.post(
          AppEnvironment.settings(path),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletAddress': walletAddress,
            'code': code.trim(),
          }),
        ),
        const <String, String>{'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }

      return _error(response.body, fallback);
    } catch (error) {
      return _exception(error, fallback);
    }
  }

  Future<String?> _activeWalletAddress() async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    final normalized = walletAddress?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Map<String, dynamic> _missingWallet() {
    return {
      'success': false,
      'error': 'Open the wallet you want to protect, then try again.',
    };
  }

  Map<String, dynamic> _error(String body, String fallback) {
    return {
      'success': false,
      'error': AppErrorUtils.backendMessage(body, fallback: fallback),
    };
  }

  Map<String, dynamic> _exception(Object error, String fallback) {
    return {
      'success': false,
      'error': AppErrorUtils.userMessage(error, fallback: fallback),
    };
  }

  Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
