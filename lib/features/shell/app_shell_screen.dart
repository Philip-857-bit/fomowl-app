import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../screens/home/home_screen.dart';
import '../../screens/profile/decentralized_profile_screen.dart';
import '../../screens/swap/swap_screen.dart';
import '../discover/discover_screen.dart';
import 'app_shell_bottom_navigation.dart';
import 'app_shell_controller.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  bool _appliedInitialArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedInitialArgs) {
      return;
    }
    _appliedInitialArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final initialIndex = switch (args) {
      int value => value,
      String value => int.tryParse(value),
      Map<String, dynamic> value => switch (value['tab']) {
        int tab => tab,
        String tab => int.tryParse(tab),
        _ => null,
      },
      _ => null,
    };
    final initialDiscoverUrl = switch (args) {
      Map<String, dynamic> value => value['discoverUrl']?.toString(),
      _ => null,
    };
    if (initialDiscoverUrl != null && initialDiscoverUrl.trim().isNotEmpty) {
      context.read<AppShellController>().openDiscoverUrl(initialDiscoverUrl);
    }
    if (initialIndex != null) {
      context.read<AppShellController>().selectIndex(initialIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppShellController>();
    // The shell is the root route. Without this guard, the hardware back button
    // pops the shell off the Navigator, leaving an empty stack (black screen).
    // Standard Android behavior: back from a sub-tab returns to the first tab;
    // back from the first tab backgrounds the app instead of popping the route.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (controller.currentTab != AppShellTab.wallet) {
          controller.selectTab(AppShellTab.wallet);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: controller.currentIndex,
          children: const [
            HomeScreen(showBottomNavigation: false),
            SwapScreen(showBottomNavigation: false),
            DiscoverScreen(),
            DecentralizedProfileScreen(showBottomNavigation: false),
          ],
        ),
        bottomNavigationBar: AppShellBottomNavigation(
          currentTab: controller.currentTab,
          onTap: controller.selectTab,
        ),
      ),
    );
  }
}
