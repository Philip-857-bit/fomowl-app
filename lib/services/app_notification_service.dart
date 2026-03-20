import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app/app_navigator.dart';

class AppNotificationEvent {
  const AppNotificationEvent({this.walletAddress});

  final String? walletAddress;
}

class AppNotificationService {
  AppNotificationService._internal();

  static final AppNotificationService _instance =
      AppNotificationService._internal();

  factory AppNotificationService() => _instance;

  static const String _defaultChannelId = 'owllet_default_notifications';
  static const String _defaultChannelName = 'General Notifications';
  static const String _defaultChannelDescription =
      'General Owllet notifications';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<AppNotificationEvent> _events =
      StreamController<AppNotificationEvent>.broadcast();

  bool _initialized = false;

  Stream<AppNotificationEvent> get events => _events.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (_) => openNotificationsInbox(),
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundNotificationResponse,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        _defaultChannelName,
        description: _defaultChannelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<void> showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title?.trim();
    final body = notification?.body?.trim();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      announceInboxChanged(walletAddress: message.data['wallet_address']);
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      announceInboxChanged(walletAddress: message.data['wallet_address']);
      return;
    }

    await _localNotifications.show(
      _notificationIdFor(message),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannelId,
          _defaultChannelName,
          channelDescription: _defaultChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: '/notifications',
    );
    announceInboxChanged(walletAddress: message.data['wallet_address']);
  }

  void announceInboxChanged({String? walletAddress}) {
    if (_events.isClosed) {
      return;
    }
    _events.add(AppNotificationEvent(walletAddress: walletAddress));
  }

  void openNotificationsInbox() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      if (currentRouteName.value == '/notifications') {
        return;
      }
      navigator.pushNamed('/notifications');
    });
  }

  static int _notificationIdFor(RemoteMessage message) {
    final source = message.messageId ?? message.sentTime?.toIso8601String();
    if (source == null || source.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
    return source.hashCode & 0x7fffffff;
  }
}

@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse response) {
  AppNotificationService().openNotificationsInbox();
}
