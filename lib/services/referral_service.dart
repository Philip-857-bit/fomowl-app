import 'dart:async';
import 'dart:convert';

import '../config/app_environment.dart';
import 'http_client_service.dart';
import 'wallet_backend_auth_service.dart';
import '../utils/app_error_utils.dart';

class ReferralProfile {
  final String referralCode;
  final String? referredByCode;
  final int totalReferrals;
  final double totalRewardsUsd;
  final double claimableRewardsUsd;
  final double minPayoutUsd;
  final bool payoutsEnabled;
  final String? payoutTokenSymbol;
  final int? payoutChainId;

  const ReferralProfile({
    required this.referralCode,
    required this.referredByCode,
    required this.totalReferrals,
    required this.totalRewardsUsd,
    required this.claimableRewardsUsd,
    required this.minPayoutUsd,
    required this.payoutsEnabled,
    required this.payoutTokenSymbol,
    required this.payoutChainId,
  });

  factory ReferralProfile.fromJson(Map<String, dynamic> json) {
    return ReferralProfile(
      referralCode: json['referralCode']?.toString() ?? '',
      referredByCode: json['referredByCode']?.toString(),
      totalReferrals: (json['totalReferrals'] as num?)?.toInt() ?? 0,
      totalRewardsUsd: (json['totalRewardsUsd'] as num?)?.toDouble() ?? 0.0,
      claimableRewardsUsd:
          (json['claimableRewardsUsd'] as num?)?.toDouble() ?? 0.0,
      minPayoutUsd: (json['minPayoutUsd'] as num?)?.toDouble() ?? 5.0,
      payoutsEnabled: json['payoutsEnabled'] == true,
      payoutTokenSymbol: json['payoutTokenSymbol']?.toString(),
      payoutChainId: (json['payoutChainId'] as num?)?.toInt(),
    );
  }

  bool get canClaim =>
      payoutsEnabled &&
      claimableRewardsUsd > 0 &&
      claimableRewardsUsd + 0.000001 >= minPayoutUsd;
}

class ReferralClaimResult {
  final String txHash;
  final double amountUsd;
  final String? payoutTokenSymbol;
  final int? chainId;

  const ReferralClaimResult({
    required this.txHash,
    required this.amountUsd,
    required this.payoutTokenSymbol,
    required this.chainId,
  });

  factory ReferralClaimResult.fromJson(Map<String, dynamic> json) {
    return ReferralClaimResult(
      txHash: json['txHash']?.toString() ?? '',
      amountUsd: (json['amountUsd'] as num?)?.toDouble() ?? 0.0,
      payoutTokenSymbol: json['payoutTokenSymbol']?.toString(),
      chainId: (json['chainId'] as num?)?.toInt(),
    );
  }
}

class ReferralService {
  ReferralService({
    WalletBackendAuthService? walletBackendAuthService,
    HttpClientService? httpClientService,
  }) : _walletBackendAuthService =
           walletBackendAuthService ?? WalletBackendAuthService(),
       _httpClientService = httpClientService ?? HttpClientService();

  final WalletBackendAuthService _walletBackendAuthService;
  final HttpClientService _httpClientService;

  String _normalizeWallet(String walletAddress) {
    return walletAddress.trim().toLowerCase();
  }

  Future<ReferralProfile> getProfile(String walletAddress) async {
    try {
      final encodedAddress = Uri.encodeComponent(
        _normalizeWallet(walletAddress),
      );
      final uri = AppEnvironment.referrals('/$encodedAddress');
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(uri))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(
          AppErrorUtils.backendMessage(
            response.body,
            fallback: 'Unable to load referrals',
          ),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralProfile.fromJson(data);
    } on TimeoutException {
      throw Exception(
        AppErrorUtils.userMessage(
          'Request timed out. Please check your internet connection.',
        ),
      );
    } on FormatException catch (e) {
      throw Exception(
        AppErrorUtils.userMessage(
          'Invalid response from server: $e',
          fallback: 'Unable to load referrals',
        ),
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
        AppErrorUtils.userMessage(
          'An unexpected error occurred: $e',
          fallback: 'Unable to load referrals',
        ),
      );
    }
  }

  Future<void> bindReferralCode({
    required String walletAddress,
    required String referralCode,
  }) async {
    try {
      final uri = AppEnvironment.referrals('/bind');
      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'walletAddress': _normalizeWallet(walletAddress),
                'referralCode': referralCode,
              }),
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          AppErrorUtils.backendMessage(
            response.body,
            fallback: 'Unable to add referral code',
          ),
        );
      }
    } on TimeoutException {
      throw Exception(
        AppErrorUtils.userMessage(
          'Request timed out. Please check your internet connection.',
        ),
      );
    } on FormatException catch (e) {
      throw Exception(
        AppErrorUtils.userMessage(
          'Invalid response format: $e',
          fallback: 'Unable to add referral code',
        ),
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
        AppErrorUtils.userMessage(
          'Failed to bind referral: $e',
          fallback: 'Unable to add referral code',
        ),
      );
    }
  }

  Future<void> rewardOnSwap({
    required String walletAddress,
    required String txHash,
    required double swapAmountUsd,
  }) async {
    try {
      final uri = AppEnvironment.referrals('/reward-on-swap');
      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'walletAddress': _normalizeWallet(walletAddress),
                'txHash': txHash,
                'swapAmountUsd': swapAmountUsd,
              }),
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          AppErrorUtils.backendMessage(
            response.body,
            fallback: 'Unable to apply referral swap reward',
          ),
        );
      }
    } on TimeoutException {
      throw Exception(
        AppErrorUtils.userMessage(
          'Request timed out. Please check your internet connection.',
        ),
      );
    } on FormatException catch (e) {
      throw Exception(
        AppErrorUtils.userMessage(
          'Invalid response format: $e',
          fallback: 'Unable to apply referral swap reward',
        ),
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
        AppErrorUtils.userMessage(
          'Failed to apply referral swap reward: $e',
          fallback: 'Unable to apply referral swap reward',
        ),
      );
    }
  }

  Future<ReferralClaimResult> claimRewards({
    required String walletAddress,
  }) async {
    try {
      final normalizedWallet = _normalizeWallet(walletAddress);
      final uri = AppEnvironment.referrals('/claim');
      final response = await _walletBackendAuthService
          .sendAuthorized(
            normalizedWallet,
            (headers) => _httpClientService.sendWithRetry(
              () => _httpClientService.client.post(
                uri,
                headers: headers,
                body: jsonEncode({'walletAddress': normalizedWallet}),
              ),
            ),
            {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          AppErrorUtils.backendMessage(
            response.body,
            fallback: 'Unable to claim referral rewards',
          ),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralClaimResult.fromJson(data);
    } on TimeoutException {
      throw Exception(
        AppErrorUtils.userMessage(
          'Request timed out. Please check your internet connection.',
        ),
      );
    } on FormatException catch (e) {
      throw Exception(
        AppErrorUtils.userMessage(
          'Invalid response format: $e',
          fallback: 'Unable to claim referral rewards',
        ),
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
        AppErrorUtils.userMessage(
          'Failed to claim referral rewards: $e',
          fallback: 'Unable to claim referral rewards',
        ),
      );
    }
  }
}
