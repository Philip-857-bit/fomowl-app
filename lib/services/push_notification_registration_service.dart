import 'dart:convert';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_environment.dart';
import 'storage_service.dart';
import 'wallet_backend_auth_service.dart';
import 'wallet_service.dart';
import 'http_client_service.dart';

abstract class PushMessagingClient {
  Stream<String> get onTokenRefresh;
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<String?> getToken();
}

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient({FirebaseMessaging? messaging})
    : _providedMessaging = messaging;

  final FirebaseMessaging? _providedMessaging;
  FirebaseMessaging? _messaging;
  bool _initialized = false;

  @override
  Stream<String> get onTokenRefresh {
    final messaging = _messaging;
    if (messaging == null) {
      return const Stream<String>.empty();
    }
    return messaging.onTokenRefresh;
  }

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    final options = AppEnvironment.firebaseOptions;
    if (!AppEnvironment.pushNotificationsEnabled || options == null) {
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      _messaging = _providedMessaging ?? FirebaseMessaging.instance;
      _initialized = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Push init failed: $error');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) {
      return false;
    }
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() async {
    final messaging = _messaging;
    if (messaging == null) {
      return null;
    }
    try {
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}

class PushNotificationRegistrationService {
  PushNotificationRegistrationService({
    StorageService? storageService,
    WalletService? walletService,
    WalletBackendAuthService? walletBackendAuthService,
    PushMessagingClient? messagingClient,
    HttpClientService? httpClientService,
    Future<String> Function()? appVersionProvider,
    bool? pushNotificationsEnabled,
  }) : _storageService = storageService ?? StorageService(),
       _walletService = walletService ?? WalletService(),
       _walletBackendAuthService =
           walletBackendAuthService ?? WalletBackendAuthService(),
       _messagingClient = messagingClient ?? FirebasePushMessagingClient(),
       _httpClientService = httpClientService ?? HttpClientService(),
       _appVersionProvider = appVersionProvider ?? _defaultAppVersionProvider,
       _pushNotificationsEnabled =
           pushNotificationsEnabled ?? AppEnvironment.pushNotificationsEnabled;

  final StorageService _storageService;
  final WalletService _walletService;
  final WalletBackendAuthService _walletBackendAuthService;
  final PushMessagingClient _messagingClient;
  final HttpClientService _httpClientService;
  final Future<String> Function() _appVersionProvider;
  final bool _pushNotificationsEnabled;

  static StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> syncForActiveWallet() async {
    if (!_pushNotificationsEnabled) {
      return;
    }

    final initialized = await _messagingClient.initialize();
    if (!initialized) {
      return;
    }

    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      return;
    }

    try {
      // 1. Ensure permissions
      final hasPermission = await _messagingClient.requestPermission();
      if (!hasPermission) return;

      // 2. Get current device token
      final deviceToken = await _messagingClient.getToken();
      if (deviceToken == null || deviceToken.isEmpty) return;

      // 3. Register if needed
      await _registerDeviceToken(
        walletAddress: walletAddress,
        deviceToken: deviceToken,
      );

      // 4. Setup refresh listener
      _setupTokenRefreshListener(walletAddress);
    } catch (e) {
      debugPrint('Push sync failed: $e');
    }
  }

  void _setupTokenRefreshListener(String walletAddress) {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messagingClient.onTokenRefresh.listen((
      newToken,
    ) {
      _registerDeviceToken(walletAddress: walletAddress, deviceToken: newToken);
    });
  }

  Future<void> _registerDeviceToken({
    required String walletAddress,
    required String deviceToken,
  }) async {
    final cached = await _storageService.getNotificationDeviceRegistration(
      walletAddress,
    );
    final appVersion = await _appVersionProvider();

    if (cached != null &&
        cached['token'] == deviceToken &&
        cached['appVersion'] == appVersion) {
      // Already registered with backend
      return;
    }

    // If token changed, unregister old one (best effort)
    final oldToken = cached?['token'];
    if (oldToken != null && oldToken != deviceToken) {
      unawaited(
        _unregisterDeviceToken(
          walletAddress: walletAddress,
          deviceToken: oldToken,
        ),
      );
    }

    final response = await _walletBackendAuthService.sendAuthorized(
      walletAddress,
      (headers) => _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              AppEnvironment.notifications('/devices/register'),
              headers: headers,
              body: jsonEncode({
                'walletAddress': walletAddress,
                'deviceToken': deviceToken,
                'platform': _platformName,
                'appVersion': appVersion,
              }),
            ),
          )
          .timeout(const Duration(seconds: 10)),
      {'Content-Type': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Push device registration failed: ${response.statusCode}');
      return;
    }

    await _storageService.saveNotificationDeviceRegistration(
      walletAddress: walletAddress,
      token: deviceToken,
      appVersion: appVersion,
    );
  }

  Future<void> _unregisterDeviceToken({
    required String walletAddress,
    required String deviceToken,
  }) async {
    try {
      final response = await _walletBackendAuthService.sendAuthorized(
        walletAddress,
        (headers) => _httpClientService
            .sendWithRetry(
              () => _httpClientService.client.post(
                AppEnvironment.notifications('/devices/unregister'),
                headers: headers,
                body: jsonEncode({
                  'walletAddress': walletAddress,
                  'deviceToken': deviceToken,
                }),
              ),
            )
            .timeout(const Duration(seconds: 10)),
        {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _storageService.clearNotificationDeviceRegistration(
          walletAddress,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Push device unregister failed: $error');
      debugPrint(stackTrace.toString());
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }

  static Future<String> _defaultAppVersionProvider() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }
}
