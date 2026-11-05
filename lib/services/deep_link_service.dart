import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../app/app_navigator.dart';
import '../utils/in_app_link_router.dart';
import 'affiliate_attribution_service.dart';
import 'walletconnect/wallet_connect_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// Helper to detect and extract a WalletConnect pairing URI from any raw input string,
  /// including raw `wc:...`, universal links `https://owlletapp.com/wc?uri=...`, or deep links `owllet://wc?uri=...`.
  static String? extractWalletConnectPairingUri(String rawString) {
    final trimmed = rawString.trim();
    if (trimmed.isEmpty) return null;

    // 1. Direct wc: scheme
    if (trimmed.startsWith('wc:')) {
      return trimmed;
    }

    // 2. Query parameter or substring containing uri=wc:
    if (trimmed.contains('uri=')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.queryParameters.containsKey('uri')) {
        final param = uri.queryParameters['uri'];
        if (param != null && param.trim().startsWith('wc:')) {
          return param.trim();
        }
      }
      final uriIndex = trimmed.indexOf('uri=');
      if (uriIndex != -1) {
        final extracted = Uri.decodeComponent(trimmed.substring(uriIndex + 4));
        if (extracted.trim().startsWith('wc:')) {
          return extracted.trim();
        }
      }
    }

    // 3. Custom scheme owllet://wc?uri=...
    if (trimmed.startsWith('owllet://wc') ||
        trimmed.startsWith('owllet://app/wc')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.queryParameters.containsKey('uri')) {
        final param = uri.queryParameters['uri'];
        if (param != null && param.trim().isNotEmpty) {
          return param.trim();
        }
      }
    }

    return null;
  }

  /// Public protocol for links that open a specific page inside Discover.
  /// Accepts owllet://open?url=<encoded HTTPS URL> and the verified app-link
  /// equivalent https://owlletapp.com/open?url=<encoded HTTPS URL>.
  /// No arbitrary URI schemes or credentials may be passed to the webview.
  static Uri? discoverUrlFromLink(Uri link) {
    final isCustom = link.scheme.toLowerCase() == 'owllet' &&
        ((link.host.toLowerCase() == 'open' &&
                (link.path.isEmpty || link.path == '/')) ||
            (link.host.toLowerCase() == 'app' && link.path == '/open'));
    final isWeb = link.scheme.toLowerCase() == 'https' &&
        link.host.toLowerCase() == 'owlletapp.com' &&
        link.path == '/open';
    if (!isCustom && !isWeb) return null;

    final raw = link.queryParameters['url'];
    if (raw == null || raw.isEmpty) return null;
    final target = Uri.tryParse(raw);
    if (target == null ||
        target.scheme.toLowerCase() != 'https' ||
        target.host.isEmpty ||
        target.userInfo.isNotEmpty) {
      return null;
    }
    return target;
  }

  Future<void> _openDiscoverWhenReady(Uri target) async {
    // Initial Android App Links can arrive before the navigator has mounted.
    for (var attempt = 0; attempt < 40; attempt++) {
      final context = appNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        await InAppLinkRouter.open(context, target.toString());
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    debugPrint('[DeepLink] Discover URL could not open: navigator unavailable.');
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Handle initial link if launched via deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handleUri(initialUri));
      }
    } catch (error) {
      debugPrint('[DeepLink] Failed to get initial link: $error');
    }

    // Handle background / foreground incoming links
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(_handleUri(uri));
      },
      onError: (error) {
        debugPrint('[DeepLink] uriLinkStream error: $error');
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    debugPrint(
      uri.scheme.toLowerCase() == 'wc'
          ? '[DeepLink] Incoming WalletConnect URI: <redacted>'
          : '[DeepLink] Incoming URI: ${uri.scheme}://${uri.host}${uri.path}',
    );
    final rawString = uri.toString();

    final pairingUri = extractWalletConnectPairingUri(rawString);
    if (pairingUri != null && pairingUri.isNotEmpty) {
      await WalletConnectService.instance.pair(pairingUri);
      return;
    }

    final discoverTarget = discoverUrlFromLink(uri);
    if (discoverTarget != null) {
      await _openDiscoverWhenReady(discoverTarget);
      return;
    }

    final affiliateCode = AffiliateAttributionService.parseCodeFromUri(uri);
    if (affiliateCode != null) {
      await AffiliateAttributionService.instance.rememberCode(affiliateCode);
      await AffiliateAttributionService.instance.applyPendingToCurrentWallet();
      return;
    }

    // Fallback to In-App router (Discover / Web)
    final context = appNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      await InAppLinkRouter.open(context, rawString);
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
