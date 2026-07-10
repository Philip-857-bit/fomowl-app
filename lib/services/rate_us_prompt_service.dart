import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/rate_us_feedback_modal.dart';
import 'app_patch_service.dart';
import 'app_store_service.dart';
import 'feedback_service.dart';
import 'storage_service.dart';
import 'wallet_service.dart';

class RateUsPromptService {
  RateUsPromptService({
    AppStoreService? appStoreService,
    FeedbackService? feedbackService,
    StorageService? storageService,
    WalletService? walletService,
  }) : _appStoreService = appStoreService ?? AppStoreService(),
       _feedbackService = feedbackService ?? FeedbackService(),
       _storageService = storageService ?? StorageService(),
       _walletService = walletService ?? WalletService();

  static const Duration cooldown = Duration(days: 7);
  static const String _lastShownKey = 'last_rate_us_prompt_shown_at_v1';
  static bool _dialogInFlight = false;

  final AppStoreService _appStoreService;
  final FeedbackService _feedbackService;
  final StorageService _storageService;
  final WalletService _walletService;

  Future<void> maybeShowAfterPositiveMoment(BuildContext context) async {
    if (_dialogInFlight || !context.mounted) return;
    if (!await _canShow()) return;

    _dialogInFlight = true;
    try {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (dialogContext) {
          return RateUsFeedbackModal(
            onRateNow: () async {
              await _markShownNow();
              await _appStoreService.requestReviewOrOpenStore();
            },
            onMaybeLater: _markShownNow,
            onClose: _markShownNow,
            onSubmitFeedback: (message) async {
              await _submitFeedback(context, message);
              await _markShownNow();
            },
          );
        },
      );
    } finally {
      _dialogInFlight = false;
    }
  }

  Future<bool> _canShow() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastShownKey);
    if (raw == null || raw.isEmpty) return true;
    final lastShown = DateTime.tryParse(raw);
    if (lastShown == null) return true;
    return DateTime.now().difference(lastShown) >= cooldown;
  }

  Future<void> _markShownNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastShownKey, DateTime.now().toIso8601String());
  }

  Future<void> _submitFeedback(BuildContext context, String message) async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      throw Exception('No active wallet found.');
    }

    final languageCode = await _storageService.getLanguage();
    final packageInfo = await PackageInfo.fromPlatform();
    final fallbackVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final patchVersion = context.mounted
        ? context.read<AppPatchService>().reportVersion
        : fallbackVersion;

    await _feedbackService.submitFeedback(
      walletAddress: walletAddress,
      category: 'rating_prompt',
      subject: 'Rate us modal feedback',
      message: message,
      appVersion: patchVersion.isEmpty ? fallbackVersion : patchVersion,
      languageCode: languageCode,
    );
  }
}
