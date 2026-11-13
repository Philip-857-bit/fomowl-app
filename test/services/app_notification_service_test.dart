import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/app/app_navigator.dart';
import 'package:fomowl_wallet/services/app_notification_service.dart';

void main() {
  final service = AppNotificationService();

  setUp(() {
    service.setLastTransactionActionUrl(null);
    service.externalUrlTapHandler = null;
    currentRouteName.value = null;
  });

  test('resolveNotificationTarget prefers explicit action_url over payload', () {
    service.setLastTransactionActionUrl(
      'https://pay.owllet.xyz/withdraw/receipt/cached?source=saga',
    );
    final target = service.resolveNotificationTarget(
      payload: '/notifications',
      data: <String, dynamic>{
        'action_url':
            'https://pay.owllet.xyz/withdraw/receipt/ref-123?source=saga',
      },
      title: 'Withdrawal completed',
      body: 'Funds sent',
    );

    expect(
      target,
      'https://pay.owllet.xyz/withdraw/receipt/ref-123?source=saga',
    );
  });

  test('resolveNotificationTarget uses non-inbox payload route', () {
    final target = service.resolveNotificationTarget(
      payload: 'https://pay.owllet.xyz/withdraw/receipt/ref-456?source=direct',
    );
    expect(
      target,
      'https://pay.owllet.xyz/withdraw/receipt/ref-456?source=direct',
    );
  });

  test(
    'resolveNotificationTarget uses cached receipt URL for transaction pushes without action_url',
    () {
      service.setLastTransactionActionUrl(
        'https://pay.owllet.xyz/withdraw/receipt/ref-789?source=saga',
      );
      final target = service.resolveNotificationTarget(
        data: <String, dynamic>{'type': 'wallet_activity'},
        title: 'USDC Transfer Confirmed',
        body: 'Your withdrawal transfer succeeded.',
      );

      expect(
        target,
        'https://pay.owllet.xyz/withdraw/receipt/ref-789?source=saga',
      );
    },
  );

  test(
    'resolveNotificationTarget falls back to /transactions for transaction pushes when no receipt URL exists',
    () {
      final target = service.resolveNotificationTarget(
        data: <String, dynamic>{'tx_hash': '0xabc'},
        title: 'Transfer Confirmed',
        body: 'Sent 10 USDC',
      );
      expect(target, '/transactions');
    },
  );

  test(
    'resolveNotificationTarget routes general notifications to /notifications',
    () {
      final target = service.resolveNotificationTarget(
        title: 'Security update',
        body: 'New login protection features available.',
      );
      expect(target, '/notifications');
    },
  );

  testWidgets(
    'openNotificationTargetNow routes external receipt URLs via externalUrlTapHandler and internal routes via navigator',
    (tester) async {
      final openedExternalUrls = <String>[];
      service.externalUrlTapHandler = (_, url) async {
        openedExternalUrls.add(url);
        return true;
      };

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: <NavigatorObserver>[owlletRouteObserver],
          initialRoute: '/',
          routes: <String, WidgetBuilder>{
            '/': (_) => const Scaffold(body: Text('home')),
            '/transactions': (_) => const Scaffold(body: Text('transactions')),
            '/notifications': (_) => const Scaffold(body: Text('notifications')),
          },
        ),
      );

      await service.openNotificationTargetNow(
        'https://pay.owllet.xyz/withdraw/receipt/ref-999?source=saga',
      );
      expect(openedExternalUrls, <String>[
        'https://pay.owllet.xyz/withdraw/receipt/ref-999?source=saga',
      ]);
      expect(find.text('home'), findsOneWidget);

      await service.openNotificationTargetNow('/transactions');
      await tester.pumpAndSettle();
      expect(find.text('transactions'), findsOneWidget);
      expect(find.text('notifications'), findsNothing);
    },
  );
}
