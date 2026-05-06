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

class _AppBootstrapperState extends State<AppBootstrapper>
    with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Determine the next route while the native splash is still visible.
    final hasWallet = await _walletService.hasWallet();
    var nextRoute = '/welcome';
    if (hasWallet) {
      nextRoute = await _storage.hasPasscode() ? '/unlock' : '/shell';
    }

    if (!mounted) return;

    // Wait for the first frame so [SplashScreenBody] is definitely painted
    // with the matching [kSplashBackground] before we dismiss the native
    // splash.  Without this the OS window briefly shows the wrong colour.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Remove native splash — the custom splash beneath is already drawn
      // with the same background so the transition is invisible.
      FlutterNativeSplash.remove();
      // Reset before forwarding so the animation reliably plays on every
      // cold launch (guards against edge-cases in debug hot-restart).
      _animationController
        ..reset()
        ..forward();
    });

    // Hold on splash long enough for the full animation + a brief pause.
    await Future.delayed(const Duration(milliseconds: 1900));

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreenBody(scaleAnimation: _scaleAnimation);
  }
}
