import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/language_controller.dart';
import '../utils/language_utils.dart';
import 'app_navigator.dart';
import 'app_bootstrapper.dart';
import 'app_routes.dart';

class OwlletApp extends StatelessWidget {
  const OwlletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageController>(
      builder: (context, languageController, _) {
        return MaterialApp(
          title: 'Owllet Wallet',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
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
            useMaterial3: true,
          ),
          home: const AppBootstrapper(),
          routes: buildAppRoutes(),
        );
      },
    );
  }
}
