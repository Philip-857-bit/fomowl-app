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
          : '[DeepLink] Incoming URI scheme: ${uri.scheme}',
    );
    final rawString = uri.toString();

    // 1. Direct wc: scheme or WalletConnect link
    if (rawString.startsWith('wc:') || rawString.contains('wc?uri=')) {
      String pairingUri = rawString;
      if (uri.queryParameters.containsKey('uri')) {
        pairingUri = uri.queryParameters['uri']!;
      }
      await WalletConnectService.instance.pair(pairingUri);
      return;
    }

    // 2. Custom owllet:// scheme
    if (uri.scheme == 'owllet') {
      if (uri.host == 'wc' || uri.path.contains('wc')) {
        final wcParam = uri.queryParameters['uri'];
        if (wcParam != null && wcParam.isNotEmpty) {
          await WalletConnectService.instance.pair(wcParam);
          return;
        }
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
