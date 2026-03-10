import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';

class ReferralProfile {
  final String referralCode;
  final String? referredByCode;
  final int totalReferrals;
  final double totalRewardsUsd;

  const ReferralProfile({
    required this.referralCode,
    required this.referredByCode,
    required this.totalReferrals,
    required this.totalRewardsUsd,
  });

  factory ReferralProfile.fromJson(Map<String, dynamic> json) {
    return ReferralProfile(
      referralCode: json['referralCode']?.toString() ?? '',
      referredByCode: json['referredByCode']?.toString(),
      totalReferrals: (json['totalReferrals'] as num?)?.toInt() ?? 0,
      totalRewardsUsd: (json['totalRewardsUsd'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReferralService {
  Future<ReferralProfile> getProfile(String walletAddress) async {
    try {
      final encodedAddress = Uri.encodeComponent(walletAddress);
      final uri = AppEnvironment.referrals('/$encodedAddress');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load referral profile (HTTP ${response.statusCode})',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralProfile.fromJson(data);
    } on TimeoutException {
      throw Exception(
        'Request timed out. Please check your internet connection.',
      );
    } on FormatException catch (e) {
      throw Exception('Invalid response from server: $e');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<void> bindReferralCode({
    required String walletAddress,
    required String referralCode,
  }) async {
    try {
      final uri = AppEnvironment.referrals('/bind');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'walletAddress': walletAddress,
              'referralCode': referralCode,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Unable to add referral code';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body.containsKey('message')) {
            message = body['message'].toString();
          } else if (body is Map && body.containsKey('error')) {
            message = body['error'].toString();
          }
        } catch (_) {
          // If body is not JSON or doesn't have expected fields, use default.
        }
        throw Exception(message);
      }
    } on TimeoutException {
      throw Exception(
        'Request timed out. Please check your internet connection.',
      );
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to bind referral: $e');
    }
  }

  Future<void> rewardOnSwap({
    required String walletAddress,
    required String txHash,
  }) async {
    try {
      final uri = AppEnvironment.referrals('/reward-on-swap');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'walletAddress': walletAddress,
              'txHash': txHash,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Unable to apply referral swap reward';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body.containsKey('message')) {
            message = body['message'].toString();
          } else if (body is Map && body.containsKey('error')) {
            message = body['error'].toString();
          }
        } catch (_) {
          // Fallback to default message.
        }
        throw Exception(message);
      }
    } on TimeoutException {
      throw Exception(
        'Request timed out. Please check your internet connection.',
      );
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to apply referral swap reward: $e');
    }
  }
}
