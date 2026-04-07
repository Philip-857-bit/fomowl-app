import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/screens/home/home_portfolio_api_service.dart';

void main() {
  test('parses portfolio snapshot response into grouped sections', () {
    final snapshot = HomePortfolioApiService.parseResponse('''
{
  "walletAddress": "0xabc",
  "snapshotAt": "2026-04-04T12:30:00Z",
  "source": "cache",
  "isStale": false,
  "partialFailure": false,
  "summary": {
    "totalNetWorthUsd": 150.0,
    "changeAmountUsd24h": 10.0,
    "changePercent24h": 7.14
  },
  "sections": [
    {
      "chainId": 56,
      "chainName": "BNB Smart Chain",
      "chainLogoUrl": "https://example.com/bnb.png",
      "totalBalanceUsd": 150.0,
      "tokens": [
        {
          "symbol": "BNB",
          "name": "BNB",
          "contractAddress": null,
          "balance": 1.0,
          "valueUsd": 150.0,
          "priceUsd": 150.0,
          "changePercent24h": 7.14,
          "decimals": 18,
          "imageUrl": "https://example.com/token.png",
          "coinGeckoId": "binancecoin",
          "isCertified": true
        }
      ]
    }
  ]
}
''');

    expect(snapshot.walletAddress, '0xabc');
    expect(snapshot.sections, hasLength(1));
    expect(snapshot.sections.first.chain.chainId, 56);
    expect(
      snapshot.sections.first.chain.logoUrl,
      'https://example.com/bnb.png',
    );
    expect(snapshot.sections.first.tokens.single.symbol, 'BNB');
    expect(
      snapshot.timestamp.toUtc().toIso8601String(),
      '2026-04-04T12:30:00.000Z',
    );
  });
}
