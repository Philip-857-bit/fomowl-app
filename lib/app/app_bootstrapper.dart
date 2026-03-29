import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

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

    var nextRoute = '/welcome';
    if (hasWallet) {
      nextRoute = await _storage.hasPasscode() ? '/unlock' : '/shell';
    }

    if (!mounted) return;
    FlutterNativeSplash.remove();
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(),
    );
  }
}
