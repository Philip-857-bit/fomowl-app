import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/admin/admin_api_service.dart';
import 'package:fomowl_wallet/screens/admin/admin_dashboard_screen.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

class _FakeAdminApiService extends AdminApiService {
  _FakeAdminApiService() : super(adminSecret: 'secret');

  @override
  Future<Map<String, dynamic>> fetchHealth() async => {'status': 'healthy'};

  @override
  Future<Map<String, dynamic>> fetchStats(int chainId) async => {
    'users_count': 12,
    'transactions_24h': 7,
    'notifications_24h': 5,
    'feedback_24h': 1,
    'token_registry_size': 9,
    'maintainers_count': 1,
    'registered_devices': 3,
    'registered_wallets': 2,
    'db_latency_ms': 12,
  };

  @override
  Future<Map<String, dynamic>> fetchOps(int chainId) async => {
    'activity': {
      'estimatedEventsPerMinute': 4,
      'estimatedEventsPerSecond': 0.07,
    },
    'errorSignals': {
      'feedbackErrorSignals24h': 1,
      'serverErrors24h': 0,
      'serverErrorsLastMinute': 0,
    },
    'rateLimits': {
      'configuredRequestsPerSecond': 10,
      'configuredBurstSize': 20,
    },
    'push': {
      'fcmConfigured': true,
      'registeredDevices': 3,
      'broadcastMode': 'stored-notification-and-device-push',
    },
  };

  @override
  Future<Map<String, dynamic>> fetchRegistry(
    int chainId, {
    String? query,
    int page = 1,
    int pageSize = 40,
  }) async => {
    'tokens': [
      {
        'contractAddress': '0x55d398326f99059ff775485246999027b3197955',
        'symbol': 'USDT',
        'name': 'Tether USD',
        'imageUrl': null,
        'isCertified': true,
        'updatedAt': '2026-03-21T00:00:00Z',
      },
    ],
    'page': 1,
    'total': 1,
    'hasNext': false,
  };
}

void main() {
  testWidgets('admin dashboard switches to registry section', (tester) async {
    final blockchainService = BlockchainService();

    await tester.pumpWidget(
      ChangeNotifierProvider<BlockchainService>.value(
        value: blockchainService,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminDashboardScreen(
            adminSecret: 'secret',
            apiService: _FakeAdminApiService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Operational overview'), findsOneWidget);

    final sectionStrip = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(sectionStrip, const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(find.text('Registry'), findsOneWidget);

    await tester.tap(find.text('Registry'));
    await tester.pumpAndSettle();

    expect(find.text('Token registry'), findsOneWidget);
    expect(find.text('Tether USD'), findsOneWidget);
    expect(find.text('USDT'), findsWidgets);
  });
}
