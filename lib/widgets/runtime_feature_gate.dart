import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/runtime_config_service.dart';

class RuntimeFeatureGate extends StatelessWidget {
  const RuntimeFeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.runtimeConfig,
    this.onReturn,
  });

  final RuntimeFeature feature;
  final Widget child;
  final RuntimeConfigService? runtimeConfig;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final runtimeConfig = this.runtimeConfig ?? RuntimeConfigService.instance;
    return AnimatedBuilder(
      animation: runtimeConfig,
      builder: (context, _) {
        final policy = runtimeConfig.snapshot;
        if (policy.allows(feature)) return child;
        return RuntimeFeatureUnavailableScreen(
          feature: feature,
          title: runtimeConfig.hasPolicy
              ? null
              : runtimeConfig.refreshFailed
              ? 'Could not check availability'
              : 'Checking availability',
          message: runtimeConfig.hasPolicy
              ? policy.unavailableMessage(feature)
              : runtimeConfig.refreshFailed
              ? 'Check your connection and try again.'
              : 'Waiting for Owllet availability settings. Please try again if this takes too long.',
          onRetry: () => runtimeConfig.refresh(),
          refreshing: runtimeConfig.refreshing,
          onReturn: onReturn,
        );
      },
    );
  }
}

class RuntimeFeatureUnavailableScreen extends StatelessWidget {
  const RuntimeFeatureUnavailableScreen({
    super.key,
    required this.feature,
    required this.message,
    this.title,
    this.onRetry,
    this.refreshing = false,
    this.onReturn,
  });

  final RuntimeFeature feature;
  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final bool refreshing;
  final VoidCallback? onReturn;

  String get _title => switch (feature) {
    RuntimeFeature.transfers => 'Transfers unavailable',
    RuntimeFeature.swaps => 'Swaps unavailable',
    RuntimeFeature.bridges => 'Bridging unavailable',
    RuntimeFeature.miniApps => 'Mini apps unavailable',
    RuntimeFeature.cashIn => 'OwlletPay deposits unavailable',
    RuntimeFeature.cashOut => 'OwlletPay withdrawals unavailable',
    RuntimeFeature.bills => 'OwlletPay bills unavailable',
    RuntimeFeature.shop => 'OwlletPay shop unavailable',
    RuntimeFeature.legacySystem => 'Older payment flow unavailable',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.build_circle_outlined,
                  color: Color(0xFFFFC857),
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  title ?? _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB4BCC7),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                if (onRetry != null)
                  TextButton(
                    onPressed: refreshing ? null : onRetry,
                    child: Text(refreshing ? 'Checking...' : 'Try again'),
                  ),
                FilledButton(
                  onPressed: onReturn ?? () => _returnToWallet(context),
                  child: const Text('Return to wallet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _returnToWallet(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushNamedAndRemoveUntil('/shell', (route) => false, arguments: 0);
  }
}
