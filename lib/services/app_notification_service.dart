import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app/app_navigator.dart';
import 'http_client_service.dart';

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
  String? _lastTransactionActionUrl;

  /// Callback provided by the app layer to open HTTP/mini-app notification URLs
  /// (for example via `InAppLinkRouter.open`) without introducing a circular
  /// dependency from [AppNotificationService] to UI screens.
  Future<bool> Function(BuildContext context, String url)?
  externalUrlTapHandler;

  @visibleForTesting
  String? get lastTransactionActionUrl => _lastTransactionActionUrl;

  void setLastTransactionActionUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _lastTransactionActionUrl = null;
      return;
    }
    if (trimmed.startsWith('https://') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('/')) {
      _lastTransactionActionUrl = trimmed;
    }
  }

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
      onDidReceiveNotificationResponse: (response) =>
          unawaited(handleNotificationTap(response.payload)),
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

    // Default to an expandable "big text" layout so the full message is shown
    // when the notification is pulled down, instead of a single truncated line.
    StyleInformation styleInformation = BigTextStyleInformation(
      body ?? '',
      contentTitle: title,
    );

    // If the push carries an image, render an expandable BigPicture instead.
    // (Background/terminated notifications get this automatically from the OS
    // via notification.image; the foreground path must build it itself.)
    final imageUrl =
        notification?.android?.imageUrl ??
        notification?.apple?.imageUrl ??
        (message.data['image'] as String?);
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final bigPicture = await _downloadAndroidBitmap(imageUrl.trim());
      if (bigPicture != null) {
        styleInformation = BigPictureStyleInformation(
          bigPicture,
          contentTitle: title,
          summaryText: body,
          hideExpandedLargeIcon: true,
        );
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _defaultChannelId,
      _defaultChannelName,
      channelDescription: _defaultChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: styleInformation,
    );

    final payloadTarget = resolveNotificationTarget(
      data: message.data,
      category: message.category,
      title: title,
      body: body,
    );

    await _localNotifications.show(
      _notificationIdFor(message),
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payloadTarget,
    );
    announceInboxChanged(walletAddress: message.data['wallet_address']);
  }

  /// Show a simple local notification on behalf of a host feature (e.g. a
  /// mini app raising "your token has arrived"). Unlike FCM foreground relays,
  /// this displays on both platforms.
  Future<void> showLocal({
    required String title,
    String? body,
    String payloadRoute = '/notifications',
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
      trimmedTitle,
      (body ?? '').trim().isEmpty ? null : body!.trim(),
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
      payload: payloadRoute,
    );
  }

  /// Download a notification image over HTTPS into an Android bitmap for the
  /// BigPicture style. Returns null (caller falls back to big-text) on any
  /// failure, non-https URL, or oversized payload.
  Future<ByteArrayAndroidBitmap?> _downloadAndroidBitmap(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.isScheme('https')) {
        return null;
      }
      final response = await HttpClientService().client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      // Guard against very large images.
      if (response.bodyBytes.length > 2 * 1024 * 1024) {
        return null;
      }
      return ByteArrayAndroidBitmap(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  void announceInboxChanged({String? walletAddress}) {
    if (_events.isClosed) {
      return;
    }
    _events.add(AppNotificationEvent(walletAddress: walletAddress));
  }

  static const List<String> _actionUrlKeys = <String>[
    'action_url',
    'actionUrl',
    'url',
    'receipt_url',
    'receiptUrl',
    'deep_link',
    'deepLink',
    'route',
  ];

  static const List<String> _transactionKeywords = <String>[
    'transaction',
    'withdraw',
    'withdrawal',
    'transfer',
    'deposit',
    'cashin',
    'cash-in',
    'cashout',
    'cash-out',
    'swap',
    'bridge',
    'sent',
    'received',
    'settled',
    'payout',
    'receipt',
    'wallet_activity',
    'tx_',
  ];

  String resolveNotificationTarget({
    String? payload,
    Map<String, dynamic>? data,
    String? category,
    String? title,
    String? body,
  }) {
    if (data != null) {
      for (final key in _actionUrlKeys) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty && value != '/notifications') {
          return value;
        }
      }
    }
    final trimmedPayload = payload?.trim();
    if (trimmedPayload != null &&
        trimmedPayload.isNotEmpty &&
        trimmedPayload != '/notifications') {
      return trimmedPayload;
    }

    final metadataHint = <String?>[
      category,
      data?['type']?.toString(),
      data?['category']?.toString(),
      data?['event']?.toString(),
      data?['tx_hash']?.toString(),
      data?['txHash']?.toString(),
      data?['transaction_hash']?.toString(),
      data?['transactionHash']?.toString(),
      data?['reference']?.toString(),
    ].whereType<String>().join(' ').toLowerCase();
    final textHint = '${title ?? ''} ${body ?? ''}'.toLowerCase();
    final isTransaction = _transactionKeywords.any(
      (kw) => metadataHint.contains(kw) || textHint.contains(kw),
    );
    if (isTransaction) {
      final cached = _lastTransactionActionUrl?.trim();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      return '/transactions';
    }
    return '/notifications';
  }

  Future<void> handleNotificationTap(String? payload) async {
    final target = resolveNotificationTarget(payload: payload);
    await openNotificationTarget(target);
  }

  Future<void> handleRemoteMessageOpened(RemoteMessage message) async {
    announceInboxChanged(
      walletAddress: message.data['wallet_address']?.toString(),
    );
    final target = resolveNotificationTarget(
      data: message.data,
      category: message.category,
      title: message.notification?.title,
      body: message.notification?.body,
    );
    await openNotificationTarget(target);
  }

  Future<void> openNotificationTarget(String rawTarget) async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await openNotificationTargetNow(rawTarget);
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    return completer.future;
  }

  @visibleForTesting
  Future<void> openNotificationTargetNow(String rawTarget) async {
    final target = rawTarget.trim();
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    final navContext = navigator.context;
    if ((target.startsWith('https://') || target.startsWith('http://')) &&
        externalUrlTapHandler != null) {
      try {
        final handled = await externalUrlTapHandler!(navContext, target);
        if (handled) {
          return;
        }
      } catch (_) {}
    }
    if (target.startsWith('/') && target != '/notifications') {
      if (currentRouteName.value == target) {
        return;
      }
      unawaited(navigator.pushNamed(target));
      return;
    }
    if (currentRouteName.value == '/notifications') {
      return;
    }
    unawaited(navigator.pushNamed('/notifications'));
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
  unawaited(AppNotificationService().handleNotificationTap(response.payload));
}
