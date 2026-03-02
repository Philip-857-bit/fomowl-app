import 'dart:convert';

import 'package:http/http.dart' as http;

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
  static const String _baseUrl =
      'https://fomowl-backend.onrender.com/api/referrals';

  Future<ReferralProfile> getProfile(String walletAddress) async {
    final encodedAddress = Uri.encodeComponent(walletAddress);
    final uri = Uri.parse('$_baseUrl/$encodedAddress');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load referral profile (HTTP ${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ReferralProfile.fromJson(data);
  }

  Future<void> bindReferralCode({
    required String walletAddress,
    required String referralCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/bind');
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
      final body = response.body;
      throw Exception(body.isEmpty ? 'Unable to add referral code' : body);
    }
  }
}
