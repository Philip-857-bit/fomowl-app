import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../models/patch_status_snapshot.dart';
import '../services/app_patch_service.dart';
import '../services/language_controller.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';
import '../utils/language_utils.dart';
import '../utils/toast_utils.dart';
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
  DateTime _lastInteractionAt = DateTime.now();
  Timer? _foregroundLockTimer;
  AppPatchStatus? _lastVisiblePatchStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppPatchService.instance.addListener(_showVisiblePatchStatus);
    ShowcaseView.register(enableAutoScroll: true, blurValue: 1);
    _foregroundLockTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _maybeRequireForegroundUnlock(),
    );
  }

  @override
  void dispose() {
    _foregroundLockTimer?.cancel();
    AppPatchService.instance.removeListener(_showVisiblePatchStatus);
    ShowcaseView.get().unregister();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showVisiblePatchStatus() {
    final status = AppPatchService.instance.snapshot.status;
    if (_lastVisiblePatchStatus == status) {
      return;
    }
    _lastVisiblePatchStatus = status;

    switch (status) {
      case AppPatchStatus.downloading:
        ToastUtils.showInfo('Downloading Owllet update...');
        break;
      case AppPatchStatus.restartRequired:
        ToastUtils.showSuccess('Update downloaded. Restart Owllet to apply.');
        break;
      case AppPatchStatus.failed:
        ToastUtils.showError(
          'Update download failed. Owllet will retry later.',
        );
        break;
      case AppPatchStatus.idle:
      case AppPatchStatus.unavailable:
      case AppPatchStatus.checking:
      case AppPatchStatus.outdated:
      case AppPatchStatus.upToDate:
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(AppPatchService.instance.handleAppResumed());
      _maybeRequireUnlock();
    }
  }

  Future<void> _maybeRequireUnlock() async {
    if (!_wasBackgrounded || _unlockInFlight) return;
    _wasBackgrounded = false;

    final routeName = currentRouteName.value;
    if (_shouldSkipLockForRoute(routeName)) {
      return;
    }

    final hasWallet = await _walletService.hasWallet();
    if (!hasWallet) return;

    final hasPasscode = await _storage.hasPasscode();
    final biometricEnabled = await _storage.isBiometricEnabled();
    if (!hasPasscode && !biometricEnabled) return;

    final lockOnBackground = await _storage.isLockOnBackgroundEnabled();
    if (!lockOnBackground) {
      return;
    }

    await _pushUnlockScreen();
  }

  Future<void> _maybeRequireForegroundUnlock() async {
    if (_unlockInFlight || !mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final routeName = currentRouteName.value;
    if (_shouldSkipLockForRoute(routeName)) return;

    final hasWallet = await _walletService.hasWallet();
    if (!hasWallet) return;

    final hasPasscode = await _storage.hasPasscode();
    final biometricEnabled = await _storage.isBiometricEnabled();
    if (!hasPasscode && !biometricEnabled) return;

    final autoLockMinutes = await _storage.getAutoLockMinutes();
    final lockDelay = Duration(minutes: autoLockMinutes);
    if (lockDelay <= Duration.zero ||
        DateTime.now().difference(_lastInteractionAt) < lockDelay) {
      return;
    }

    await _pushUnlockScreen();
  }

  bool _shouldSkipLockForRoute(String? routeName) {
    return routeName == '/unlock' ||
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
        routeName == '/congratulations';
  }

  Future<void> _pushUnlockScreen() async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !mounted) return;

    _lastInteractionAt = DateTime.now();
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

  void _recordInteraction() {
    _lastInteractionAt = DateTime.now();
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
          builder: (context, child) => Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _recordInteraction(),
            onPointerMove: (_) => _recordInteraction(),
            onPointerSignal: (_) => _recordInteraction(),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AppBootstrapper(),
          routes: buildAppRoutes(),
        );
      },
    );
  }
}
