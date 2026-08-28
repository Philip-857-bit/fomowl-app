import '../../mini_apps/mini_app_definition.dart';
import '../discover_url_utils.dart';
import 'discover_dapp_entry.dart';

/// Presentation model for a card in the FOMOWL Products carousel.
///
/// A product is either a trusted, bridge-enabled Owllet mini app or a backend
/// Discover catalog entry. Keeping that distinction explicit prevents an
/// ordinary website from accidentally receiving the mini-app host bridge.
class DiscoverProductEntry {
  const DiscoverProductEntry._({this.miniApp, this.dapp})
    : assert((miniApp == null) != (dapp == null));

  factory DiscoverProductEntry.miniApp(MiniAppDefinition miniApp) {
    return DiscoverProductEntry._(miniApp: miniApp);
  }

  factory DiscoverProductEntry.dapp(DiscoverDappEntry dapp) {
    return DiscoverProductEntry._(dapp: dapp);
  }

  final MiniAppDefinition? miniApp;
  final DiscoverDappEntry? dapp;

  bool get isMiniApp => miniApp != null;

  String get id => miniApp?.id ?? dapp!.id;
  String get title => miniApp?.title ?? dapp!.title;
  String get description =>
      miniApp?.description ?? dapp!.subtitle ?? 'Explore with Owllet';
  String? get networkArtworkUrl => dapp?.heroImageUrl ?? dapp?.logoUrl;

  /// Existing committed FOMOwl artwork for known first-party cards. Future
  /// mini apps intentionally fall back to the branded tile in the widget.
  String? get artworkAssetPath => switch (miniApp?.id) {
    'owllet_pay' => 'assets/images/owl_wallet.png',
    'affiliate' => 'assets/images/logo.png',
    'burst' => 'assets/images/dancing_owls.png',
    _ => null,
  };

  String? get normalizedOrigin {
    final app = miniApp;
    if (app != null) {
      return app.trustedOrigins.firstOrNull;
    }
    return normalizeDiscoverOrigin(dapp!.origin) ??
        _normalizedLaunchOrigin(dapp!.launchUrl);
  }

  /// Builds the carousel in deterministic registry/rank order and removes any
  /// backend card whose trusted origin is already represented by a mini app.
  static List<DiscoverProductEntry> merge({
    required Iterable<MiniAppDefinition> miniApps,
    required Iterable<DiscoverDappEntry> catalogDapps,
  }) {
    final products = <DiscoverProductEntry>[];
    final seenOrigins = <String>{};

    for (final app in miniApps) {
      if (!app.isConfigured) {
        continue;
      }
      final origins = app.trustedOrigins;
      if (origins.isEmpty || origins.any(seenOrigins.contains)) {
        continue;
      }
      products.add(DiscoverProductEntry.miniApp(app));
      seenOrigins.addAll(origins);
    }

    final ranked =
        catalogDapps
            .where((entry) => entry.isActive && entry.featuredRank != null)
            .toList(growable: false)
          ..sort((left, right) {
            final byRank = left.featuredRank!.compareTo(right.featuredRank!);
            if (byRank != 0) {
              return byRank;
            }
            return left.title.toLowerCase().compareTo(
              right.title.toLowerCase(),
            );
          });

    for (final dapp in ranked) {
      final origin =
          normalizeDiscoverOrigin(dapp.origin) ??
          _normalizedLaunchOrigin(dapp.launchUrl);
      if (origin == null || seenOrigins.contains(origin)) {
        continue;
      }
      products.add(DiscoverProductEntry.dapp(dapp));
      seenOrigins.add(origin);
    }

    return List<DiscoverProductEntry>.unmodifiable(products);
  }

  /// Resolves a catalog card to the trusted mini app that owns its origin.
  /// Returns null for ordinary DApps so callers can use the secure browser.
  static MiniAppDefinition? trustedMiniAppForDapp(
    DiscoverDappEntry dapp,
    Iterable<MiniAppDefinition> miniApps,
  ) {
    final uri = Uri.tryParse(dapp.launchUrl);
    if (uri == null || !isSupportedDiscoverWebUri(uri)) {
      return null;
    }
    final origin = normalizeOriginFromUri(uri);
    for (final app in miniApps) {
      if (app.isConfigured && app.trustedOrigins.contains(origin)) {
        return app;
      }
    }
    return null;
  }

  static List<String> orderedCategories(Iterable<DiscoverDappEntry> dapps) {
    const preferred = <String>[
      'Featured',
      'Shop',
      'DEX',
      'NFTs',
      'AI&Bot',
      'Staking',
      'DeFi',
    ];
    final discovered = <String>{};
    for (final dapp in dapps) {
      for (final category in dapp.categories) {
        final display = _displayCategory(category);
        if (display.isNotEmpty && !preferred.contains(display)) {
          discovered.add(display);
        }
      }
    }
    final extras = discovered.toList()
      ..sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
      );
    return List<String>.unmodifiable(<String>[...preferred, ...extras]);
  }

  static bool matchesCategory(DiscoverDappEntry dapp, String category) {
    if (category == 'Featured') {
      return dapp.featuredRank != null;
    }
    return dapp.categories.any(
      (value) =>
          _displayCategory(value).toLowerCase() == category.toLowerCase(),
    );
  }

  static String? _normalizedLaunchOrigin(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !isSupportedDiscoverWebUri(uri)) {
      return null;
    }
    return normalizeOriginFromUri(uri);
  }

  static String _displayCategory(String rawCategory) {
    final trimmed = rawCategory.trim();
    final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return switch (normalized) {
      'shop' || 'shopping' || 'commerce' || 'ecommerce' => 'Shop',
      'dex' || 'exchange' || 'exchanges' || 'swap' || 'swaps' => 'DEX',
      'nft' || 'nfts' || 'collectible' || 'collectibles' => 'NFTs',
      'ai' || 'bot' || 'bots' || 'aibot' || 'ai&bot' => 'AI&Bot',
      'stake' || 'staking' => 'Staking',
      'defi' || 'decentralizedfinance' => 'DeFi',
      _ =>
        trimmed.isEmpty
            ? ''
            : '${trimmed.substring(0, 1).toUpperCase()}${trimmed.substring(1)}',
    };
  }
}
