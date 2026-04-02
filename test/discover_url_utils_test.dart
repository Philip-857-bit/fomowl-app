import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/discover_url_utils.dart';

void main() {
  group('discover_url_utils', () {
    test('normalizeDiscoverUri adds https when missing', () {
      final uri = normalizeDiscoverUri('app.uniswap.org');
      expect(uri?.toString(), 'https://app.uniswap.org');
    });

    test('normalizeDiscoverUri defaults localhost hosts to http', () {
      final uri = normalizeDiscoverUri('localhost:3000');
      expect(uri?.toString(), 'http://localhost:3000');
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

    test('resolveDiscoverInput returns a url target for domain-like input', () {
      final target = resolveDiscoverInput('app.uniswap.org');
      expect(target, isNotNull);
      expect(target?.type, DiscoverInputType.url);
      expect(target?.uri.toString(), 'https://app.uniswap.org');
    });

    test('resolveDiscoverInput returns a web search target for plain text', () {
      final target = resolveDiscoverInput('best staking dapps');
      expect(target, isNotNull);
      expect(target?.type, DiscoverInputType.webSearch);
      expect(
        target?.uri.toString(),
        'https://duckduckgo.com/?q=best+staking+dapps',
      );
    });

    test('isSupportedDiscoverWebUri only allows http and https', () {
      expect(
        isSupportedDiscoverWebUri(
          Uri.parse('https://duckduckgo.com/?q=owllet'),
        ),
        isTrue,
      );
      expect(
        isSupportedDiscoverWebUri(Uri.parse('http://localhost:3000')),
        isTrue,
      );
      expect(
        isSupportedDiscoverWebUri(Uri.parse('mailto:test@example.com')),
        isFalse,
      );
    });

    test('resolveDiscoverInput rejects unsupported manual schemes', () {
      expect(resolveDiscoverInput('mailto:test@example.com'), isNull);
    });
  });
}
