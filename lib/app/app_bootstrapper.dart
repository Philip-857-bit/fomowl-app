import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../screens/splash/splash_screen.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';

/// Orchestrates app startup:
/// 1. Holds the native splash while determining the first route.
/// 2. Removes the native splash and starts the [SplashScreenBody] animation.
/// 3. Navigates to the correct route once the animation completes.
///
/// The UI is entirely delegated to [SplashScreenBody] in
/// `lib/screens/splash/splash_screen.dart`.
class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();

  bool _splashPrecached = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_splashPrecached) {
      _splashPrecached = true;
      // Precache the splash asset so it's ready the moment the native splash is removed.
      // This prevents the "black screen" flash during asset decoding.
      precacheImage(
        const AssetImage('assets/images/splash.png'),
        context,
        onError: (exception, stackTrace) {
          debugPrint(
            '[AppBootstrapper] Failed to precache splash image: $exception',
          );
        },
      );
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Determine the next route while the native splash is still visible.
      final hasWallet = await _walletService.hasWallet();
      var nextRoute = '/welcome';
      if (hasWallet) {
        nextRoute = await _storage.hasPasscode() ? '/unlock' : '/shell';
      }

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        FlutterNativeSplash.remove();
      });

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(nextRoute);
    } catch (e) {
      debugPrint('[AppBootstrapper] Init failed: $e');
      if (mounted) {
        FlutterNativeSplash.remove();
        Navigator.of(context).pushReplacementNamed('/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreenBody();
  }
}
