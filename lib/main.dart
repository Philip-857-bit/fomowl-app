import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'config/app_environment.dart';
import 'app/app_providers.dart';
import 'app/owllet_app.dart';
import 'services/app_notification_service.dart';
import 'services/app_patch_service.dart';

const bool kEnableRustBridge = bool.fromEnvironment(
  'ENABLE_RUST_BRIDGE',
  defaultValue: true,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await AppEnvironment.initializeFirebaseApp();
  debugPrint("Handling a background message: ${message.messageId}");
  AppNotificationService().announceInboxChanged(
    walletAddress: message.data['wallet_address'],
  );
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  RemoteMessage? initialPushMessage;
  final appNotificationService = AppNotificationService();
  final appPatchService = AppPatchService.instance;
  await appNotificationService.initialize();

  if (AppEnvironment.pushNotificationsEnabled) {
    try {
      await AppEnvironment.initializeFirebaseApp();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Request permission proactively on first launch
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        appNotificationService.showForegroundMessage(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        appNotificationService.announceInboxChanged(
          walletAddress: message.data['wallet_address'],
        );
        appNotificationService.openNotificationsInbox();
      });
      initialPushMessage = await FirebaseMessaging.instance.getInitialMessage();
    } catch (_) {
      // Ignore init errors here, handled in service.
    }
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  if (kEnableRustBridge) {
    try {
      await RustLib.init();
    } catch (error, stackTrace) {
      debugPrint('Rust bridge initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  runApp(
    MultiProvider(providers: buildAppProviders(), child: const OwlletApp()),
  );

  unawaited(appPatchService.initialize());

  if (initialPushMessage != null) {
    appNotificationService.announceInboxChanged(
      walletAddress: initialPushMessage.data['wallet_address'],
    );
    appNotificationService.openNotificationsInbox();
  }
}
