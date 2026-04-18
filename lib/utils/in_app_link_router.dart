import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/discover/discover_url_utils.dart';
import '../features/shell/app_shell_controller.dart';

class InAppLinkRouter {
  static Future<void> open(BuildContext context, String rawUrl) async {
    final target = resolveDiscoverInput(rawUrl);
    if (target == null) {
      return;
    }

    try {
      final controller = Provider.of<AppShellController>(
        context,
        listen: false,
      );
      controller.openDiscoverUrl(target.uri.toString());
      return;
    } catch (_) {}

    await Navigator.of(context).pushNamed(
      '/shell',
      arguments: <String, dynamic>{
        'tab': AppShellTab.discover.index,
        'discoverUrl': target.uri.toString(),
      },
    );
  }
}
