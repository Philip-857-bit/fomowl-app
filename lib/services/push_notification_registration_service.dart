import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_environment.dart';
import 'storage_service.dart';
import 'wallet_backend_auth_service.dart';
import 'wallet_service.dart';

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
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() {
    final messaging = _messaging;
    if (messaging == null) {
      return Future.value(null);
    }
    return messaging.getToken();
  }
}

class PushNotificationRegistrationService {
  PushNotificationRegistrationService({
    StorageService? storageService,
    WalletService? walletService,
    WalletBackendAuthService? walletBackendAuthService,
    PushMessagingClient? messagingClient,
    http.Client? httpClient,
    Future<String> Function()? appVersionProvider,
    bool? pushNotificationsEnabled,
  }) : _storageService = storageService ?? StorageService(),
       _walletService = walletService ?? WalletService(),
       _walletBackendAuthService =
           walletBackendAuthService ?? WalletBackendAuthService(),
       _messagingClient = messagingClient ?? FirebasePushMessagingClient(),
       _httpClient = httpClient ?? http.Client(),
       _appVersionProvider = appVersionProvider ?? _defaultAppVersionProvider,
       _pushNotificationsEnabled =
           pushNotificationsEnabled ?? AppEnvironment.pushNotificationsEnabled;

  final StorageService _storageService;
  final WalletService _walletService;
  final WalletBackendAuthService _walletBackendAuthService;
  final PushMessagingClient _messagingClient;
  final http.Client _httpClient;
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

    _bindTokenRefreshListener();

    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      return;
    }

    final permissionGranted = await _messagingClient.requestPermission();
    if (!permissionGranted) {
      return;
    }

    final token = await _messagingClient.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    await _registerDeviceToken(
      walletAddress: walletAddress,
      deviceToken: token.trim(),
    );
  }

  void _bindTokenRefreshListener() {
    if (_tokenRefreshSubscription != null) return;
    _tokenRefreshSubscription = _messagingClient.onTokenRefresh.listen(
      (token) async {
        try {
          final walletAddress = await _walletService.getCurrentWalletAddress();
          if (walletAddress == null || walletAddress.isEmpty) {
            return;
          }
          final normalized = token.trim();
          if (normalized.isEmpty) {
            return;
          }
          await _registerDeviceToken(
            walletAddress: walletAddress,
            deviceToken: normalized,
          );
        } catch (error, stackTrace) {
          debugPrint('Push token refresh registration failed: $error');
          debugPrint(stackTrace.toString());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Push token refresh listener failed: $error');
        debugPrint(stackTrace.toString());
      },
    );
  }

  Future<void> _registerDeviceToken({
    required String walletAddress,
    required String deviceToken,
  }) async {
    final appVersion = await _appVersionProvider();
    final existing = await _storageService.getNotificationDeviceRegistration(
      walletAddress,
    );
    final oldToken = existing?['token'];

    if (existing != null &&
        existing['token'] == deviceToken &&
        existing['appVersion'] == appVersion) {
      return;
    }

    if (oldToken != null &&
        oldToken.isNotEmpty &&
        oldToken.toLowerCase() != deviceToken.toLowerCase()) {
      await _unregisterDeviceToken(
        walletAddress: walletAddress,
        deviceToken: oldToken,
      );
    }

    final response = await _walletBackendAuthService.sendAuthorized(
      walletAddress,
      (headers) => _httpClient
          .post(
            AppEnvironment.notifications('/devices/register'),
            headers: headers,
            body: jsonEncode({
              'walletAddress': walletAddress,
              'deviceToken': deviceToken,
              'platform': _platformName,
              'appVersion': appVersion,
            }),
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
        (headers) => _httpClient
            .post(
              AppEnvironment.notifications('/devices/unregister'),
              headers: headers,
              body: jsonEncode({
                'walletAddress': walletAddress,
                'deviceToken': deviceToken,
              }),
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

  static Future<String> _defaultAppVersionProvider() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'web';
    }
  }
}
