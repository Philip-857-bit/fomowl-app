import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/utils/app_error_utils.dart';
import 'package:fomowl_wallet/utils/swap_quote_error_messages.dart';

void main() {
  for (final error in [
    'No liquidity pool',
    'Insufficient liquidity',
    'No swap route',
    'Failed to get quotes',
  ]) {
    test('$error never advises increasing the swap amount', () {
      expect(swapQuoteErrorMessage(error), swapRouteUnavailableMessage);
      expect(AppErrorUtils.userMessage(error), swapRouteUnavailableMessage);
    });
  }
  test('the supplied Asset Chain response reports a route failure', () {
    expect(
      AppErrorUtils.backendMessage(
        '{"error":"Insufficient liquidity","message":"No liquidity pool"}',
        fallback: 'Request failed',
      ),
      swapRouteUnavailableMessage,
    );
  });
  test('only an explicit minimum-amount error advises a larger amount', () {
    expect(
      swapQuoteErrorMessage('SELL_AMOUNT_TOO_SMALL'),
      swapAmountTooLowMessage,
    );
  });
}
