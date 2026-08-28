import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_definition.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_registry.dart';

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

  group('OwlletPay registry compatibility', () {
    test('publishes the canonical OwlletPay definition once', () {
      expect(OwlletMiniApps.owlletPay.id, 'owllet_pay');
      expect(OwlletMiniApps.owlletPay.title, 'OwlletPay');
      expect(
        OwlletMiniApps.all.where((app) => app.id == 'owllet_pay'),
        hasLength(1),
      );
    });

    test('resolves canonical and legacy IDs to OwlletPay', () {
      for (final id in const [
        'owllet_pay',
        'owllet-pay',
        'cash_in',
        'cash-in',
      ]) {
        expect(OwlletMiniApps.byId(id)?.id, 'owllet_pay');
        expect(OwlletMiniApps.isOwlletPayId(id), isTrue);
      }
      expect(OwlletMiniApps.cashIn.id, 'owllet_pay');
    });
  });

  test('registers Burst as a distinct Owllet mini app', () {
    expect(OwlletMiniApps.burst.id, 'burst');
    expect(OwlletMiniApps.byId('BURST')?.id, 'burst');
    expect(OwlletMiniApps.all.where((app) => app.id == 'burst'), hasLength(1));
    expect(OwlletMiniApps.burst.requiresWalletSession, isFalse);
  });
}
