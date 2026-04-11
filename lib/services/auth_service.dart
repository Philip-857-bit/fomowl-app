import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_jwt_token';
  static const String _profileKey = 'auth_profile_payload';
  static String? _sessionToken;
  static Map<String, dynamic>? _sessionProfile;

  Future<void> saveToken(String token, {bool persist = true}) async {
    _sessionToken = token;
    if (persist) {
      await _secureStorage.write(key: _tokenKey, value: token);
      return;
    }
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<String?> getToken() async {
    if (_sessionToken != null && _sessionToken!.isNotEmpty) {
      return _sessionToken;
    }
    final stored = await _secureStorage.read(key: _tokenKey);
    _sessionToken = stored;
    return stored;
  }

  Future<void> saveProfile(
    Map<String, dynamic> profile, {
    bool persist = true,
  }) async {
    _sessionProfile = Map<String, dynamic>.from(profile);
    if (persist) {
      await _secureStorage.write(
        key: _profileKey,
        value: jsonEncode(_sessionProfile),
      );
      return;
    }
    await _secureStorage.delete(key: _profileKey);
  }

  Future<Map<String, dynamic>?> getCachedProfile() async {
    if (_sessionProfile != null) {
      return _sessionProfile;
    }
    final stored = await _secureStorage.read(key: _profileKey);
    if (stored == null || stored.trim().isEmpty) {
      return null;
    }
    _sessionProfile = _decodeObject(stored);
    return _sessionProfile;
  }

  Future<void> logout() async {
    _sessionToken = null;
    _sessionProfile = null;
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _profileKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Map<String, String> _jsonHeaders([String? token]) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
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

  String? _extractErrorCode(String body) {
    return _decodeObject(body)?['error']?.toString();
  }

  /// Register a new profile
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
    String? xSecret,
    String? walletAddress,
    String? country,
    String? referralCode,
    bool acceptTerms = false,
    bool acceptCompliance = false,
  }) async {
    try {
      final response = await http
          .post(
            AppEnvironment.profile('/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'username': username,
              'password': password,
              'x_secret': xSecret,
              'primary_wallet_address': walletAddress,
              'country': country,
              'referralCode': referralCode,
              'acceptTerms': acceptTerms,
              'acceptCompliance': acceptCompliance,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final responseData = data['data'];
        if (responseData is! Map<String, dynamic>) {
          return {
            'success': false,
            'error': 'Unexpected response format. Please try again.',
          };
        }
        final token = responseData['token']?.toString();
        if (token == null || token.isEmpty) {
          return {
            'success': false,
            'error': 'Unexpected response format. Please try again.',
          };
        }
        await saveToken(token);
        final profile = responseData['profile'];
        if (profile is Map<String, dynamic>) {
          await saveProfile(profile);
        }
        return {'success': true, 'profile': profile};
      } else {
        return {
          'success': false,
          'error': AppErrorUtils.backendMessage(
            response.body,
            fallback: 'Unable to create your account right now.',
          ),
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': AppErrorUtils.userMessage(
          e,
          fallback: 'Unable to create your account right now.',
        ),
      };
    }
  }

  /// Login to an existing profile
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool rememberMe = true,
    String? twoFactorCode,
  }) async {
    try {
      final response = await http
          .post(
            AppEnvironment.profile('/login'),
            headers: _jsonHeaders(),
            body: jsonEncode({
              'email': email,
              'password': password,
              if (twoFactorCode != null && twoFactorCode.trim().isNotEmpty)
                'twoFactorCode': twoFactorCode.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final responseData = data['data'];
        if (responseData is! Map<String, dynamic>) {
          return {
            'success': false,
            'error': 'Unexpected response format. Please try again.',
          };
        }
        final token = responseData['token']?.toString();
        if (token == null || token.isEmpty) {
          return {
            'success': false,
            'error': 'Unexpected response format. Please try again.',
          };
        }
        await saveToken(token, persist: rememberMe);
        final profile = responseData['profile'];
        if (profile is Map<String, dynamic>) {
          await saveProfile(profile, persist: rememberMe);
        }
        return {'success': true, 'profile': profile};
      } else {
        return {
          'success': false,
          'errorCode': _extractErrorCode(response.body),
          'error': AppErrorUtils.backendMessage(
            response.body,
            fallback: 'Invalid email or password.',
          ),
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': null,
        'error': AppErrorUtils.userMessage(
          e,
          fallback: 'Unable to sign in right now.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    bool rememberMe = true,
    String? twoFactorCode,
  }) async {
    try {
      final response = await http
          .post(
            AppEnvironment.profile('/google-login'),
            headers: _jsonHeaders(),
            body: jsonEncode({
              'idToken': idToken,
              if (twoFactorCode != null && twoFactorCode.trim().isNotEmpty)
                'twoFactorCode': twoFactorCode.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeObject(response.body) ?? <String, dynamic>{};
      if (response.statusCode == 200 && data['success'] == true) {
        final responseData = data['data'];
        if (responseData is! Map<String, dynamic>) {
          return {
            'success': false,
            'error': 'Unexpected response format. Please try again.',
          };
        }
        final token = responseData['token']?.toString();
        if (token == null || token.isEmpty) {
          return {
            'success': false,
            'error': 'Unexpected response format. Please try again.',
          };
        }
        await saveToken(token, persist: rememberMe);
        final profile = responseData['profile'];
        if (profile is Map<String, dynamic>) {
          await saveProfile(profile, persist: rememberMe);
        }
        return {'success': true, 'profile': profile};
      }

      return {
        'success': false,
        'errorCode': _extractErrorCode(response.body),
        'error': AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to sign in with Google right now.',
        ),
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': AppErrorUtils.userMessage(
          e,
          fallback: 'Unable to sign in with Google right now.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            AppEnvironment.profile('/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = _decodeObject(response.body);
        final payload = data?['data'] as Map<String, dynamic>?;
        return {'success': true, 'delivered': payload?['delivered'] == true};
      }

      return {
        'success': false,
        'error': AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to process the password reset request right now.',
        ),
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': AppErrorUtils.userMessage(
          e,
          fallback: 'Unable to process the password reset request right now.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>> fetchTwoFactorStatus() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'You need to sign in again.'};
      }

      final response = await http
          .get(
            AppEnvironment.profile('/2fa/status'),
            headers: _jsonHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeObject(response.body) ?? <String, dynamic>{};
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return {'success': true, ...payload};
        }
      }

      return {
        'success': false,
        'error': AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to load 2FA status right now.',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': AppErrorUtils.userMessage(
          e,
          fallback: 'Unable to load 2FA status right now.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>> beginTwoFactorSetup() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'You need to sign in again.'};
      }

      final response = await http
          .post(
            AppEnvironment.profile('/2fa/setup'),
            headers: _jsonHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeObject(response.body) ?? <String, dynamic>{};
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return {'success': true, ...payload};
        }
      }

      return {
        'success': false,
        'error': AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to start 2FA setup right now.',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': AppErrorUtils.userMessage(
          e,
          fallback: 'Unable to start 2FA setup right now.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>> verifyTwoFactorSetup({
    required String code,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'You need to sign in again.'};
      }

      final response = await http
          .post(
            AppEnvironment.profile('/2fa/verify'),
            headers: _jsonHeaders(token),
            body: jsonEncode({'code': code}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {'success': true};
      }

      return {
        'success': false,
        'error': AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to activate 2FA right now.',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': AppErrorUtils.userMessage(
          e,
          fallback: 'Unable to activate 2FA right now.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>> disableTwoFactor({required String code}) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'You need to sign in again.'};
      }

      final response = await http
          .post(
            AppEnvironment.profile('/2fa/disable'),
            headers: _jsonHeaders(token),
            body: jsonEncode({'code': code}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {'success': true};
      }

      return {
        'success': false,
        'error': AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to disable 2FA right now.',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': AppErrorUtils.userMessage(
          e,
          fallback: 'Unable to disable 2FA right now.',
        ),
      };
    }
  }
}
