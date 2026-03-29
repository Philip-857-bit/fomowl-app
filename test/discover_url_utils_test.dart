import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/discover_url_utils.dart';

void main() {
  group('discover_url_utils', () {
    test('normalizeDiscoverUri adds https when missing', () {
      final uri = normalizeDiscoverUri('app.uniswap.org');
      expect(uri?.toString(), 'https://app.uniswap.org');
    });

    test('normalizeDiscoverOrigin lowercases host and strips default port', () {
      expect(
        normalizeDiscoverOrigin('HTTPS://APP.UNISWAP.ORG:443/#/swap'),
        'https://app.uniswap.org',
      );
    });

    test('normalizeOriginFromUri preserves non-default port', () {
      final uri = Uri.parse('http://localhost:3000/#/discover');
      expect(normalizeOriginFromUri(uri), 'http://localhost:3000');
    });

    test('isDiscoverInjectableUri only allows https or localhost http', () {
      expect(
        isDiscoverInjectableUri(Uri.parse('https://app.aave.com')),
        isTrue,
      );
      expect(
        isDiscoverInjectableUri(Uri.parse('http://localhost:3000')),
        isTrue,
      );
      expect(
        isDiscoverInjectableUri(Uri.parse('http://app.aave.com')),
        isFalse,
      );
      expect(isDiscoverInjectableUri(Uri.parse('ftp://app.aave.com')), isFalse);
    });
  });
}
