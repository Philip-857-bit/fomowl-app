import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/services/runtime_config_service.dart';
import 'package:fomowl_wallet/widgets/runtime_feature_gate.dart';

void main() {
  testWidgets(
    'network failure leaves mini apps open but server disable is enforced',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var attempts = 0;
      final service = RuntimeConfigService.forTesting(
        client: MockClient((_) async {
          if (++attempts == 1) return http.Response('unavailable', 503);
          return http.Response(
            jsonEncode({
              'policy': {
                'features': {'miniAppsEnabled': false},
              },
            }),
            200,
          );
        }),
      );
      await service.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: RuntimeFeatureGate(
            runtimeConfig: service,
            feature: RuntimeFeature.miniApps,
            child: const Scaffold(body: Text('Mini app ready')),
          ),
        ),
      );
      expect(find.text('Mini app ready'), findsOneWidget);
      expect(find.text('Mini apps unavailable'), findsNothing);
      await service.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Mini app ready'), findsNothing);
      expect(find.text('Mini apps unavailable'), findsOneWidget);
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
}
