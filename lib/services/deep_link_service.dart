import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../app/app_navigator.dart';
import '../utils/in_app_link_router.dart';
import 'walletconnect/wallet_connect_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

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

    // 1. Direct wc: scheme
    if (rawString.startsWith('wc:')) {
      await WalletConnectService.instance.pair(rawString);
      return;
    }

    // 2. Universal Link (e.g. https://owlletapp.com/wc?uri=wc:...) or custom scheme (owllet://wc?uri=wc:...)
    final isWcUniversalLink = (uri.host == 'owlletapp.com' || uri.host == 'fomowl.com') &&
        (uri.path == '/wc' || uri.path.startsWith('/wc/'));
    final isWcCustomScheme = uri.scheme == 'owllet' && (uri.host == 'wc' || uri.path.contains('wc'));
    final containsWcParam = uri.queryParameters.containsKey('uri') || rawString.contains('wc?uri=');

    if (isWcUniversalLink || isWcCustomScheme || containsWcParam) {
      String? pairingUri = uri.queryParameters['uri'];
      if (pairingUri == null && rawString.contains('uri=')) {
        final uriIndex = rawString.indexOf('uri=');
        if (uriIndex != -1) {
          pairingUri = Uri.decodeComponent(rawString.substring(uriIndex + 4));
        }
      }
      if (pairingUri != null && pairingUri.isNotEmpty) {
        await WalletConnectService.instance.pair(pairingUri);
        return;
      }
    }


    // 3. Fallback to In-App router (Discover / Web)
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
