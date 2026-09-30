import '../../config/app_environment.dart';
import '../discover/discover_url_utils.dart';
import 'mini_app_definition.dart';

class OwlletMiniApps {
  OwlletMiniApps._();

  static MiniAppDefinition get owlletPay => MiniAppDefinition(
    id: 'owllet_pay',
    title: 'OwlletPay',
    description:
        'Shop with crypto, fund your wallet, pay bills, and withdraw through OwlletPay.',
    launchUrl: AppEnvironment.owlletPayMiniAppUrl,
    allowedOrigins: AppEnvironment.owlletPayMiniAppAllowedOrigins,
  );

  /// Compatibility alias for integrations that still reference the former name.
  static MiniAppDefinition get cashIn => owlletPay;

  static MiniAppDefinition get affiliate => MiniAppDefinition(
    id: 'affiliate',
    title: 'Owllet Affiliate',
    description:
        'Hosted Owllet mini app for the affiliate program — apply, share your '
        'referral code, and track 20% recurring commissions.',
    launchUrl: AppEnvironment.affiliateMiniAppUrl,
    allowedOrigins: AppEnvironment.affiliateMiniAppAllowedOrigins,
    requiresWalletSession: true,
  );

  static MiniAppDefinition get burst => MiniAppDefinition(
    id: 'burst',
    title: 'Burst',
    description:
        'Create and join on-chain token distributions with your Owllet wallet.',
    launchUrl: AppEnvironment.burstMiniAppUrl,
    allowedOrigins: AppEnvironment.burstMiniAppAllowedOrigins,
    requiresWalletSession: true,
  );

  /// All registered mini apps. Order matters only for deterministic lookups.
  static List<MiniAppDefinition> get all => <MiniAppDefinition>[
    owlletPay,
    affiliate,
    burst,
  ];

  static MiniAppDefinition? byId(String id) {
    switch (id.trim().toLowerCase()) {
      case 'cash_in':
      case 'cash-in':
      case 'owllet_pay':
      case 'owllet-pay':
        return owlletPay;
      case 'affiliate':
        return affiliate;
      case 'burst':
        return burst;
      default:
        return null;
    }
  }

  static bool isOwlletPayId(String id) {
    final normalized = id.trim().toLowerCase();
    return normalized == 'owllet_pay' ||
        normalized == 'owllet-pay' ||
        normalized == 'cash_in' ||
        normalized == 'cash-in';
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
