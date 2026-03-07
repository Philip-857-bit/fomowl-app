import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../screens/auth/unlock_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final hasWallet = await _walletService.hasWallet();
    if (!mounted) return;

    var nextScreen = const WelcomeScreen() as Widget;
    if (hasWallet) {
      nextScreen = await _storage.hasPasscode()
          ? const UnlockScreen()
          : const HomeScreen();
    }

    if (!mounted) return;
    FlutterNativeSplash.remove();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(),
    );
  }
}
