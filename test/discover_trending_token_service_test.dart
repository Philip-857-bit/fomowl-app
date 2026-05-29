import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/market/discover_trending_token_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchTrendingTokens parses backend response', () async {
    final service = DiscoverTrendingTokenService(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/api/discover/trending-tokens'));
        return http.Response(
          '''
          {
            "tokens": [
              {
                "id": "ethereum",
                "symbol": "ETH",
                "name": "Ethereum",
                "imageUrl": "https://example.com/eth.png",
                "priceUsd": 3452.12,
                "changePercent24h": -1.12
              }
            ],
            "generatedAt": "2026-03-30T10:00:00Z"
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final tokens = await service.fetchTrendingTokens();

    expect(tokens, hasLength(1));
    expect(tokens.first.id, 'ethereum');
    expect(tokens.first.priceUsd, 3452.12);
    expect(tokens.first.changePercent24h, -1.12);
  });

  test(
    'fetchTrendingTokens falls back to defaults on invalid backend response',
    () async {
      final service = DiscoverTrendingTokenService(
        client: MockClient((request) async => http.Response('[]', 200)),
      );

      // On an unparseable/invalid response the service degrades gracefully to a
      // built-in fallback list rather than throwing.
      final tokens = await service.fetchTrendingTokens();

      expect(tokens, isNotEmpty);
      expect(tokens.first.id, 'fomowl');
    },
  );
}
