import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Using localhost for Android emulator (10.0.2.2) or iOS simulator (127.0.0.1)
  // For production, this should be the deployed backend URL
  static const String _baseUrl =
      'https://fomowl-backend.onrender.com/api/profile';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_jwt_token';

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Register a new profile
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    required String xSecret,
    String? walletAddress,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'username': username,
              'password': password,
              'x_secret': xSecret,
              'primary_wallet_address': walletAddress,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['data']['token'];
        await saveToken(token);
        return {'success': true, 'profile': data['data']['profile']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to register',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Login to an existing profile
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['data']['token'];
        await saveToken(token);
        return {'success': true, 'profile': data['data']['profile']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Invalid credentials',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
