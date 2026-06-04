import '../../config/app_environment.dart';
import '../discover/discover_url_utils.dart';
import 'mini_app_definition.dart';

class OwlletMiniApps {
  OwlletMiniApps._();

  static MiniAppDefinition get cashIn => MiniAppDefinition(
    id: 'cash_in',
    title: 'Cash in',
    description:
        'Hosted Owllet mini app for on-ramp, off-ramp, bills, and future fiat services.',
    launchUrl: AppEnvironment.cashInMiniAppUrl,
    allowedOrigins: AppEnvironment.cashInMiniAppAllowedOrigins,
  );

  static MiniAppDefinition get affiliate => MiniAppDefinition(
    id: 'affiliate',
    title: 'Owllet Affiliate',
    description:
        'Hosted Owllet mini app for the affiliate program — apply, share your '
        'referral code, and track 20% recurring commissions.',
    launchUrl: AppEnvironment.affiliateMiniAppUrl,
    allowedOrigins: AppEnvironment.affiliateMiniAppAllowedOrigins,
  );

  /// All registered mini apps. Order matters only for deterministic lookups.
  static List<MiniAppDefinition> get all => <MiniAppDefinition>[
    cashIn,
    affiliate,
  ];

  static MiniAppDefinition? byId(String id) {
    switch (id.trim().toLowerCase()) {
      case 'cash_in':
      case 'cash-in':
        return cashIn;
      case 'affiliate':
        return affiliate;
      default:
        return null;
    }
  }

  /// Returns the registered mini app whose trusted origin matches [uri], or
  /// null when the URL does not belong to any configured mini app. Used to route
  /// a URL opened in the in-app browser to the mini-app host (which injects the
  /// OwlletMiniApp bridge + session) instead of the plain provider-only browser.
  static MiniAppDefinition? findByUri(Uri uri) {
    if (!isSupportedDiscoverWebUri(uri)) {
      return null;
    }
    final origin = normalizeOriginFromUri(uri);
    for (final app in all) {
      if (!app.isConfigured) {
        continue;
      }
      if (app.trustedOrigins.contains(origin)) {
        return app;
      }
    }
    return null;
  }
}
