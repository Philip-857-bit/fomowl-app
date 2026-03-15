import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/language_controller.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';
import '../utils/language_utils.dart';
import 'app_bootstrapper.dart';
import 'app_navigator.dart';
import 'app_routes.dart';

class OwlletApp extends StatefulWidget {
  const OwlletApp({super.key});

  @override
  State<OwlletApp> createState() => _OwlletAppState();
}

class _OwlletAppState extends State<OwlletApp> with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  final WalletService _walletService = WalletService();

  bool _unlockInFlight = false;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _maybeRequireUnlock();
    }
  }

  Future<void> _maybeRequireUnlock() async {
    if (!_wasBackgrounded || _unlockInFlight) return;
    _wasBackgrounded = false;

    final routeName = currentRouteName.value;
    if (routeName == '/unlock' ||
        routeName == '/welcome' ||
        routeName == '/import-wallet' ||
        routeName == '/language-selection' ||
        routeName == '/import-secret-phrase' ||
        routeName == '/import-private-key' ||
        routeName == '/create-wallet' ||
        routeName == '/confirm-phrase' ||
        routeName == '/verify-phrase' ||
        routeName == '/create-passcode' ||
        routeName == '/confirm-passcode' ||
        routeName == '/biometric-setup' ||
        routeName == '/face-id-verification' ||
        routeName == '/fingerprint-verification' ||
        routeName == '/congratulations') {
      return;
    }

    final hasWallet = await _walletService.hasWallet();
    if (!hasWallet) return;

    final hasPasscode = await _storage.hasPasscode();
    final biometricEnabled = await _storage.isBiometricEnabled();
    if (!hasPasscode && !biometricEnabled) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !mounted) return;

    _unlockInFlight = true;
    try {
      await navigator.pushNamed(
        '/unlock',
        arguments: {'returnToPrevious': true},
      );
    } finally {
      _unlockInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageController>(
      builder: (context, languageController, _) {
        return MaterialApp(
          title: 'Owllet Wallet',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          navigatorObservers: [owlletRouteObserver],
          locale: languageController.locale,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (supportedLocales.any(
              (l) => l.languageCode == languageController.languageCode,
            )) {
              return languageController.locale;
            }
            if (deviceLocale != null) {
              return LanguageUtils.toLocale(deviceLocale.toLanguageTag());
            }
            return LanguageUtils.defaultLocale;
          },
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.background,
            primaryColor: AppColors.primaryAccent,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryAccent,
              secondary: AppColors.primaryAccent,
              surface: AppColors.cardBackground,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              },
            ),
            useMaterial3: true,
          ),
          home: const AppBootstrapper(),
          routes: buildAppRoutes(),
        );
      },
    );
  }
}
