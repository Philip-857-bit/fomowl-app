const String limitOrderUnsupportedMessage =
    'Limit orders are available on Solana and supported OpenOcean EVM networks: Ethereum, BNB, Polygon, Base, Arbitrum, Avalanche, Optimism, Sonic, HyperEVM, Sei, Plasma, Monad, and Berachain.';

class LimitOrderReadiness {
  const LimitOrderReadiness({
    required this.buttonLabel,
    required this.statusMessage,
  });

  final String buttonLabel;
  final String statusMessage;
}

LimitOrderReadiness resolveLimitOrderReadiness({
  required bool isBuyMode,
  required bool isSubmitting,
  required bool hasWallet,
  required bool isNetworkSupported,
  required bool hasTokenPair,
  required bool hasDistinctTokens,
  required bool requiresErc20Pair,
  required bool hasErc20Pair,
  required bool hasAmount,
  required bool hasTargetPrice,
}) {
  final side = isBuyMode ? 'Buy' : 'Sell';
  if (isSubmitting) {
    return LimitOrderReadiness(
      buttonLabel: 'Submitting $side...',
      statusMessage:
          'Submitting your signed ${side.toUpperCase()} limit order...',
    );
  }
  if (!hasWallet) {
    return const LimitOrderReadiness(
      buttonLabel: 'Connect Wallet',
      statusMessage: 'Connect your wallet to create limit orders.',
    );
  }
  if (!isNetworkSupported) {
    return const LimitOrderReadiness(
      buttonLabel: 'Network Unsupported',
      statusMessage: limitOrderUnsupportedMessage,
    );
  }
  if (!hasTokenPair) {
    return const LimitOrderReadiness(
      buttonLabel: 'Select Tokens',
      statusMessage: 'Select both sell and receive tokens to continue.',
    );
  }
  if (!hasDistinctTokens) {
    return const LimitOrderReadiness(
      buttonLabel: 'Choose Different Tokens',
      statusMessage: 'Choose two different tokens for the limit pair.',
    );
  }
  if (requiresErc20Pair && !hasErc20Pair) {
    return const LimitOrderReadiness(
      buttonLabel: 'Use ERC-20 Tokens',
      statusMessage: 'Limit orders currently support ERC-20 token pairs only.',
    );
  }
  if (!hasAmount) {
    return LimitOrderReadiness(
      buttonLabel: isBuyMode ? 'Enter Max Spend' : 'Enter Sell Amount',
      statusMessage: isBuyMode
          ? 'Enter the maximum amount you want to spend.'
          : 'Enter how much you want to sell.',
    );
  }
  if (!hasTargetPrice) {
    return const LimitOrderReadiness(
      buttonLabel: 'Set Target Price',
      statusMessage: 'Set the execution price that should trigger this order.',
    );
  }
  return LimitOrderReadiness(
    buttonLabel: 'Place $side Order',
    statusMessage:
        'You pay no gas to place or cancel a limit order. Your first sell-token approval may still need a network fee.',
  );
}
