import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/token_standard.dart';
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
    expect(snapshot.sections.first.tokens.single.networkKey, 'evm:56');
    expect(
      snapshot.timestamp.toUtc().toIso8601String(),
      '2026-04-04T12:30:00.000Z',
    );
  });

  test('preserves token network metadata from portfolio response', () {
    final snapshot = HomePortfolioApiService.parseResponse('''
{
  "walletAddress": "0xabc",
  "sections": [
    {
      "chainId": 1,
      "chainName": "Ethereum",
      "tokens": [
        {
          "symbol": "SOL",
          "name": "Solana",
          "balance": 1.0,
          "valueUsd": 100.0,
          "networkKey": "solana:mainnet",
          "tokenStandard": "native"
        }
      ]
    }
  ]
}
''');

    final token = snapshot.sections.single.tokens.single;
    expect(token.networkKey, 'solana:mainnet');
    expect(token.tokenStandard, TokenStandard.native);
  });

  test(
    'preserves a balance and displays zero when the price is unavailable',
    () {
      final snapshot = HomePortfolioApiService.parseResponse('''
{"walletAddress":"0xabc","sections":[{"chainId":56,"chainName":"BNB Smart Chain","tokens":[{"symbol":"NEW","name":"New token","contractAddress":"0x1","balance":42,"valueUsd":0,"priceUsd":null,"priceStatus":"provider_error"}]}]}
''');

      final token = snapshot.sections.single.tokens.single;
      expect(token.balance, 42);
      expect(token.priceUsd, 0);
      expect(token.priceStatus, 'provider_error');
      expect(token.formattedValue, '\$0');
    },
  );
}
