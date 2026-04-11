import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_definition.dart';

void main() {
  group('MiniAppDefinition', () {
    test('buildLaunchUri adds Owllet launch context query params', () {
      const definition = MiniAppDefinition(
        id: 'cash_in',
        title: 'Cash in',
        description: 'Test',
        launchUrl: 'https://cashin.owllet.app/app?foo=bar',
      );

      final uri = definition.buildLaunchUri(launchSource: 'discover');

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'cashin.owllet.app');
      expect(uri.queryParameters['foo'], 'bar');
      expect(uri.queryParameters['owllet_host'], 'mobile');
      expect(uri.queryParameters['owllet_mini_app'], 'cash_in');
      expect(uri.queryParameters['owllet_source'], 'discover');
    });

    test('trustedOrigins includes launch origin and configured extras', () {
      const definition = MiniAppDefinition(
        id: 'cash_in',
        title: 'Cash in',
        description: 'Test',
        launchUrl: 'https://cashin.owllet.app/app',
        allowedOrigins: <String>[
          'https://cashin.owllet.app',
          'https://staging-cashin.owllet.app',
        ],
      );

      expect(
        definition.trustedOrigins,
        containsAll(<String>[
          'https://cashin.owllet.app',
          'https://staging-cashin.owllet.app',
        ]),
      );
    });
  });
}
