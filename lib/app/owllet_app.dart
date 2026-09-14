import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../models/patch_status_snapshot.dart';
import '../services/app_patch_service.dart';
import '../services/app_release_checker.dart';
import '../services/language_controller.dart';
import '../services/runtime_config_service.dart';
import '../services/storage_service.dart';
import '../services/system_picker_guard.dart';
import '../services/wallet_service.dart';
import '../utils/language_utils.dart';
import '../utils/toast_utils.dart';
import '../widgets/forced_update_dialog.dart';
import '../services/deep_link_service.dart';
import '../services/walletconnect/wallet_connect_service.dart';
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
  final AppReleaseChecker _releaseChecker = AppReleaseChecker();
  final RuntimeConfigService _runtimeConfig = RuntimeConfigService.instance;

  bool _unlockInFlight = false;
  bool _wasBackgrounded = false;
  DateTime _lastInteractionAt = DateTime.now();
  Timer? _foregroundLockTimer;
  Timer? _runtimeConfigTimer;
  AppPatchStatus? _lastVisiblePatchStatus;
  bool _requiredUpdateCheckInFlight = false;
  bool _requiredUpdateDialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppPatchService.instance.addListener(_showVisiblePatchStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_enforceRequiredUpdate());
      unawaited(_runtimeConfig.refresh());
      unawaited(WalletConnectService.instance.initialize());
      unawaited(DeepLinkService.instance.initialize());
    });
    ShowcaseView.register(enableAutoScroll: true, blurValue: 1);
    _foregroundLockTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _maybeRequireForegroundUnlock(),
    );
    _runtimeConfigTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_runtimeConfig.refresh()),
    );
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    _foregroundLockTimer?.cancel();
    _runtimeConfigTimer?.cancel();
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
      unawaited(_enforceRequiredUpdate());
      unawaited(_runtimeConfig.refresh());
      _maybeRequireUnlock();
    }
  }

  Future<void> _enforceRequiredUpdate() async {
    if (_requiredUpdateCheckInFlight || _requiredUpdateDialogVisible) return;
    _requiredUpdateCheckInFlight = true;
    try {
      final result = await _releaseChecker.checkForRequiredUpdate();
      if (result == null || !mounted || _requiredUpdateDialogVisible) return;

      final navigatorContext = appNavigatorKey.currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) return;

      _requiredUpdateDialogVisible = true;
      await ForcedUpdateDialog.show(
        navigatorContext,
        version: result.serverVersion.toLowerCase().startsWith('v')
            ? result.serverVersion
            : 'v${result.serverVersion}',
      );
    } catch (error) {
      debugPrint('[AppUpdate] Required update check failed: $error');
    } finally {
      _requiredUpdateCheckInFlight = false;
      _requiredUpdateDialogVisible = false;
    }
  }

  Future<void> _maybeRequireUnlock() async {
    if (!_wasBackgrounded || _unlockInFlight) return;
    _wasBackgrounded = false;

    // A system camera/file picker launched from within the app (e.g. OwlletPay
    // KYC capture) briefly backgrounds us. Don't treat that as the user leaving
    // the app, or the unlock screen would cover and wipe the capture in flight.
    if (SystemPickerGuard.isActive) {
      return;
    }

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
    if (SystemPickerGuard.isActive) return;

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
          builder: (context, child) => AnimatedBuilder(
            animation: _runtimeConfig,
            builder: (context, _) {
              final policy = _runtimeConfig.snapshot;
              if (policy.fullMaintenance) {
                return _MaintenanceScreen(message: policy.maintenanceMessage);
              }
              return Column(
                children: [
                  if (policy.readOnly)
                    const Material(
                      color: Color(0xFFFFC857),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text(
                            'Owllet is temporarily read-only. Existing activity remains available.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => _recordInteraction(),
                      onPointerMove: (_) => _recordInteraction(),
                      onPointerSignal: (_) => _recordInteraction(),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            },
          ),
          home: const AppBootstrapper(),
          routes: buildAppRoutes(),
        );
      },
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.message});

  final String message;

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
                  Icons.construction_rounded,
                  color: Color(0xFFFFC857),
                  size: 58,
                ),
                const SizedBox(height: 20),
                const Text(
                  'We’ll be back shortly',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message.isEmpty
                      ? 'Owllet is temporarily undergoing maintenance. Please try again shortly.'
                      : message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
