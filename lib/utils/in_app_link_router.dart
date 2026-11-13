import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/discover/discover_url_utils.dart';
import '../features/mini_apps/mini_app_host_screen.dart';
import '../features/mini_apps/mini_app_registry.dart';
import '../features/shell/app_shell_controller.dart';

class InAppLinkRouter {
  static Future<void> open(
    BuildContext context,
    String rawUrl, {
    String? miniAppLaunchSource,
  }) async {
    final target = resolveDiscoverInput(rawUrl);
    if (target == null) {
      return;
    }

    final source = miniAppLaunchSource?.trim();
    final miniApp = source == null || source.isEmpty
        ? null
        : OwlletMiniApps.findByUri(target.uri);
    if (miniApp != null) {
      if (await MiniAppHostScreen.openUrlInActiveHost(target.uri)) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context).pushNamed(
        '/mini-app-host',
        arguments: MiniAppHostArguments(
          miniAppId: miniApp.id,
          launchSource: source!,
          initialUrl: target.uri.toString(),
        ),
      );
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
