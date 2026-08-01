import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/swap_quote_safety.dart';

void main() {
  group('gasless quote safety', () {
    test('blocks a quote without executable liquidity', () {
      final message = gaslessQuoteBlockingMessage({
        'liquidityAvailable': false,
      });

      expect(message, contains('too low for a gasless route'));
    });

    test('blocks an incomplete firm-quote simulation', () {
      final message = gaslessQuoteBlockingMessage({
        'liquidityAvailable': true,
        'issues': {'simulationIncomplete': true},
      });

      expect(message, contains('could not be validated'));
    });

    test('allows a provider-validated transfer-tax gasless quote', () {
      final message = gaslessQuoteBlockingMessage({
        'liquidityAvailable': true,
        'issues': {'simulationIncomplete': false},
        'tokenMetadata': {
          'sellToken': {'sellTaxBps': '399'},
          'buyToken': {'buyTaxBps': '0'},
        },
      });

      expect(message, isNull);
    });
  });
}
