const swapRouteUnavailableMessage =
    'No swap route is available for this pair and amount. Try a different amount or token pair.';
const swapAmountTooLowMessage =
    'Amount is too low for this swap. Try a larger amount.';
const swapQuoteIncompleteMessage =
    'The swap quote is incomplete. Please try again.';

/// A failed route is not evidence that increasing the amount will help.
String? swapQuoteErrorMessage(String raw) {
  final lower = raw.toLowerCase();
  if (const [
    'amount too low',
    'amount is too low',
    'sell_amount_too_small',
    'buy_amount_too_small',
    'provided sell amount is too small',
    'provided buy amount is too small',
    'minsellamount',
    'minbuyamount',
    'minimum sell amount',
    'minimum buy amount',
    'too small to cover fees required to execute swap',
  ].any(lower.contains)) {
    return swapAmountTooLowMessage;
  }
  if (const [
    'swap quote response was missing',
    'swap quote response was incomplete',
    'missing the unsigned transaction',
    'transaction":""',
    'transaction is empty',
  ].any(lower.contains)) {
    return swapQuoteIncompleteMessage;
  }
  if (const [
    'failed to get quotes',
    'could not find any route',
    'no solana swap route',
    'no swap route',
    'route not found',
    'no route found',
    'no quote',
    'no liquidity',
    'insufficient liquidity',
    'quoter simulation failed',
    'no liquid market',
    'no executable quote',
  ].any(lower.contains)) {
    return swapRouteUnavailableMessage;
  }
  return null;
}
