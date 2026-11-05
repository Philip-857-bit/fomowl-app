import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/deep_link_service.dart';

void main() {
  group('Discover external links', () {
    test('custom owllet scheme opens a validated HTTPS Discover target', () {
      final target = DeepLinkService.discoverUrlFromLink(
        Uri.parse('owllet://open?url=https%3A%2F%2Fapp.assetclaw.xyz%2Fbridge'),
      );
      expect(target?.toString(), 'https://app.assetclaw.xyz/bridge');
    });

    test('official universal link opens the same Discover target', () {
      final target = DeepLinkService.discoverUrlFromLink(
        Uri.parse(
          'https://owlletapp.com/open?url=https%3A%2F%2Fapp.assetclaw.xyz',
        ),
      );
      expect(target?.toString(), 'https://app.assetclaw.xyz');
    });

    test('rejects non-HTTPS and malformed Discover destinations', () {
      for (final destination in [
        'javascript:alert(1)',
        'http://app.assetclaw.xyz',
        'https://user:password@app.assetclaw.xyz',
        'file:///etc/passwd',
        'https:///missing-host',
      ]) {
        final uri = Uri(
          scheme: 'owllet',
          host: 'open',
          queryParameters: {'url': destination},
        );
        expect(
          DeepLinkService.discoverUrlFromLink(uri),
          isNull,
          reason: 'Unsafe destination unexpectedly allowed: $destination',
        );
      }
    });

    test('does not intercept WalletConnect or unrelated hosts', () {
      expect(
        DeepLinkService.discoverUrlFromLink(
          Uri.parse('owllet://wc?uri=wc%3Aabc'),
        ),
        isNull,
      );
      expect(
        DeepLinkService.discoverUrlFromLink(
          Uri.parse(
            'https://attacker.example/open?url=https%3A%2F%2Fapp.assetclaw.xyz',
          ),
        ),
        isNull,
      );
    });
  });
}
