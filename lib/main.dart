import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'utils/toast_utils.dart';
import 'config/app_environment.dart';

import 'app/app_providers.dart';
import 'app/owllet_app.dart';
import 'constants/app_colors.dart';

const bool kEnableRustBridge = bool.fromEnvironment(
  'ENABLE_RUST_BRIDGE',
  defaultValue: true,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: AppEnvironment.firebaseOptions);
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (AppEnvironment.pushNotificationsEnabled &&
      AppEnvironment.firebaseOptions != null) {
    try {
      await Firebase.initializeApp(options: AppEnvironment.firebaseOptions);
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null && notification.title != null) {
          ToastUtils.showInfo(
            '${notification.title}\n${notification.body ?? ''}'.trim(),
          );
        }
      });
    } catch (_) {
      // Ignore init errors here, handled in service.
    }
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

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
}
