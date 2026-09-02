import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/features/shell/app_shell_controller.dart';
import 'package:fomowl_wallet/utils/in_app_link_router.dart';

void main() {
  group('InAppLinkRouter', () {
    testWidgets('does nothing if url cannot be resolved', (tester) async {
      final controller = AppShellController();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: controller,
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    InAppLinkRouter.open(context, 'mailto:test@example.com');
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(controller.pendingDiscoverUrl, isNull);
    });

    testWidgets('opens discover url if AppShellController is present', (
      tester,
    ) async {
      final controller = AppShellController();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: controller,
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    InAppLinkRouter.open(context, 'https://app.uniswap.org');
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(controller.pendingDiscoverUrl, 'https://app.uniswap.org');
      expect(controller.currentTab, AppShellTab.discover);
    });

    testWidgets('pushes /shell route if AppShellController is not present', (
      tester,
    ) async {
      String? pushedRouteName;
      Object? pushedArguments;

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          onGenerateRoute: (settings) {
            if (settings.name == '/shell') {
              pushedRouteName = settings.name;
              pushedArguments = settings.arguments;
              return MaterialPageRoute(builder: (_) => const SizedBox());
            }
            return null;
          },
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  InAppLinkRouter.open(context, 'https://app.uniswap.org');
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(pushedRouteName, '/shell');
      expect(pushedArguments, isA<Map<String, dynamic>>());
      final args = pushedArguments as Map<String, dynamic>;
      expect(args['tab'], AppShellTab.discover.index);
      expect(args['discoverUrl'], 'https://app.uniswap.org');
    });
  });
}
