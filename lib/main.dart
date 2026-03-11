import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'package:provider/provider.dart';

import 'app/app_providers.dart';
import 'app/owllet_app.dart';
import 'constants/app_colors.dart';

const bool kEnableRustBridge = bool.fromEnvironment(
  'ENABLE_RUST_BRIDGE',
  defaultValue: false,
);

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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
