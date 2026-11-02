import 'dart:convert';

class AppErrorUtils {
  AppErrorUtils._();

  static String userMessage(
    Object? error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final raw = _normalize(error);
    if (raw.isEmpty) return fallback;

    final lowered = raw.toLowerCase();

    if (_containsAny(lowered, const [
      'socketexception',
      'timed out',
      'timeout',
      'failed host lookup',
      'connection refused',
      'network is unreachable',
      'no address associated',
    ])) {
      return 'Connection failed. Please check your internet and try again.';
    }

    if (_containsAny(lowered, const [
      '401',
      '403',
      'wallet session',
      'challenge',
      'signature',
      'authentication',
      'authorization',
      'unauthorized',
      'forbidden',
    ])) {
      return 'Authentication failed. Please try again.';
    }

    if (_containsAny(lowered, const [
      '429',
      'rate limit',
      'too many requests',
    ])) {
      return 'Too many requests right now. Please try again shortly.';
    }

    if (_containsAny(lowered, const [
      'recipient account is not active',
      'rent exemption',
      'rent-exempt',
    ])) {
      return raw.replaceAll(RegExp(r'\s+'), ' ');
    }

    if (_isSolanaSwapBalanceError(lowered)) {
      return 'You don\'t have enough SOL to complete this swap. Add more SOL to cover the swap amount plus network fees.';
    }

    if (_isSolanaSwapAddressError(lowered)) {
      return 'Selected Solana wallet address is invalid. Switch to a Solana wallet and try again.';
    }

    if (_isSwapSlippageError(lowered)) {
      return 'Swap failed due to price movement. Try increasing your slippage tolerance.';
    }

    if (_containsAny(lowered, const [
      'amount too low',
      'swap quote response was missing',
      'missing the unsigned transaction',
    ])) {
      return 'Amount is too low for this swap. Try a larger amount.';
    }

    if (_containsAny(lowered, const [
      'failed to get quotes',
      'no quote',
      'no solana swap route',
      'no swap route',
      'route not found',
    ])) {
      return 'No swap quote is available right now. Please try again or choose another pair.';
    }
    if (_containsAny(lowered, const [
      'no liquidity',
      'insufficient liquidity',
    ])) {
      return "There isn't enough liquidity for this swap right now. Try another amount or pair.";
    }

    if (_containsAny(lowered, const [
      'jupiter',
      '/order',
      '/execute',
      'requestid',
      'swap provider',
    ])) {
      return fallback;
    }

    if (_containsAny(lowered, const [
      'invalid mnemonic',
      'invalid private key',
      'amount is required',
      'invalid amount format',
      'supports up to',
    ])) {
      return raw;
    }

    if (_containsAny(lowered, const [
      'seed phrase not available',
      'non-evm transactions require',
      'imported via private key and cannot sign',
    ])) {
      return 'This wallet was imported via private key and cannot sign Solana or Tron transactions. Create a new wallet from a seed phrase to use this network.';
    }

    if (_containsAny(lowered, const [
      'destination token account',
      'does not exist',
      'associated token account',
    ])) {
      return 'The recipient does not have a token account for this asset. They must first receive or create an account for this token before you can send it.';
    }

    if (_containsAny(lowered, const [
      'insufficient lamports',
      'attempt to debit an account',
      'custom program error: 0x1',
      'solana transaction',
    ])) {
      return 'Insufficient SOL to cover the transfer amount and network fee.';
    }

    if (_containsAny(lowered, const [
      'insufficient funds for fee',
      'insufficient funds for gas',
      'insufficient native gas',
      'insufficient funds',
    ])) {
      return "You don't have enough of the network's native coin to cover this transaction and its gas fee.";
    }
    if (_containsAny(lowered, const [
      'insufficient balance',
      'insufficient_balance',
    ])) {
      return 'Your balance is too low for this transaction. Try a smaller amount.';
    }

    if (_containsAny(lowered, const [
      'blockhash not found',
      'blockhash expired',
      'missing blockhash',
      'failed to fetch blockhash',
    ])) {
      return 'Solana network is busy. Please try the transfer again.';
    }

    if (_containsAny(lowered, const [
      'signature verification failed',
      'transaction signature verification failure',
      'invalid signature',
    ])) {
      return 'Transaction signing failed. Please try again.';
    }

    if (_containsAny(lowered, const [
      'invalid from_address',
      'invalid to_address',
      'invalid solana',
      'invalid public key',
    ])) {
      return 'Invalid Solana address.';
    }

    if (_containsAny(lowered, const [
      'tron broadcast rejected',
      'failed to broadcast tron',
      'failed to prepare tron',
    ])) {
      return 'Tron transaction failed. Please check your balance and try again.';
    }

    if (_containsAny(lowered, const [
      'failed to broadcast solana',
      'failed to prepare solana',
    ])) {
      return 'Solana transaction failed. Please check your balance and try again.';
    }

    if (_containsAny(lowered, const [
      'unexpected end of input',
      'unexpected character',
      'invalid portfolio response payload',
      'response was incomplete',
      'response was malformed',
      'invalid json',
    ])) {
      return fallback;
    }

    if (_containsAny(lowered, const [
      'type \'string\' is not a subtype of type \'int\' of \'index\'',
      'type \'string\' is not a subtype of type \'int\'',
    ])) {
      return 'Transaction reverted or failed. Please check your balance or slippage and try again.';
    }

    if (lowered.contains('gas required exceeds allowance')) {
      return 'The network could not estimate enough gas for this transaction. Please refresh your quote and try again.';
    }
    if (lowered.contains('intrinsic gas too low')) {
      return 'This transaction needs a higher gas limit. Please refresh your quote and try again.';
    }
    if (lowered.contains('out of gas')) {
      return 'The transaction ran out of gas. Please refresh your quote and try again.';
    }

    if (_containsAny(lowered, const [
      'execution reverted',
    ])) {
      return 'The network rejected this transaction. Check the token, amount and approval, then try again.';
    }
    if (lowered.contains('nonce too low')) {
      return 'This transaction is out of date. Wait for your pending transaction to finish, then try again.';
    }
    if (lowered.contains('transaction underpriced') ||
        lowered.contains('replacement transaction underpriced')) {
      return 'The network requires a higher transaction fee. Refresh your quote and try again.';
    }

    if (_containsAny(lowered, const [
      'backend',
      'database',
      'sql',
      'rpc',
      'provider',
      'upstream',
      'requestid',
      'response was incomplete',
      'response was malformed',
    ])) {
      return fallback;
    }

    if (_containsSensitiveEndpoint(raw, lowered)) {
      return fallback;
    }

    return raw.length > 160 ? fallback : raw;
  }

  static String backendMessage(String? body, {required String fallback}) {
    if (body == null || body.trim().isEmpty) return fallback;
    final lowered = body.toLowerCase();
    final backendJsonMessage = _extractBackendJsonMessage(body);
    if (backendJsonMessage != null && backendJsonMessage.isNotEmpty) {
      return userMessage(backendJsonMessage, fallback: fallback);
    }
    if (_isSolanaSwapBalanceError(lowered)) {
      return 'You don\'t have enough SOL to complete this swap. Add more SOL to cover the swap amount plus network fees.';
    }
    if (_isSolanaSwapAddressError(lowered)) {
      return 'Selected Solana wallet address is invalid. Switch to a Solana wallet and try again.';
    }
    if (_isSwapSlippageError(lowered)) {
      return 'Swap failed due to price movement. Try increasing your slippage tolerance.';
    }
    if (_containsAny(lowered, const [
      'failed to get quotes',
      'no solana swap route',
      'no swap route',
      'no quote',
      'route not found',
      'amount too low',
      'swap quote response was missing',
      'missing the unsigned transaction',
    ])) {
      return 'Amount is too low for this swap. Try a larger amount.';
    }
    if (_containsAny(lowered, const [
      'challenge',
      'signature',
      'wallet session',
      'backend',
      'database',
      'internal',
      'sql',
      'rpc',
      'provider',
      'jupiter',
      '/order',
      '/execute',
      'requestid',
    ])) {
      return fallback;
    }
    return fallback;
  }

  static String? _extractBackendJsonMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return null;
  }

  static String _normalize(Object? error) {
    if (error == null) return '';
    var text = error.toString().trim();
    if (text.startsWith('Exception:')) {
      text = text.substring('Exception:'.length).trim();
    }
    if (text.startsWith('FormatException:')) {
      text = text.substring('FormatException:'.length).trim();
    }
    return text;
  }

  static bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }

  static bool _isSolanaSwapBalanceError(String lowered) {
    final hasBalanceSignal =
        lowered.contains('insufficient funds') ||
        lowered.contains('not enough sol') ||
        lowered.contains('don\'t have enough sol') ||
        lowered.contains('dont have enough sol');
    if (!hasBalanceSignal) return false;
    return _containsAny(lowered, const [
      'jupiter',
      '/order',
      '/execute',
      'solana',
      'lamports',
      'not enough sol',
      'don\'t have enough sol',
      'dont have enough sol',
      'unsigned transaction',
      'transaction":""',
    ]);
  }

  static bool _isSolanaSwapAddressError(String lowered) {
    final hasAddressSignal =
        lowered.contains('invalid taker') ||
        lowered.contains('valid public key') ||
        lowered.contains('selected solana wallet address is invalid');
    if (!hasAddressSignal) return false;
    return _containsAny(lowered, const [
      'solana',
      'jupiter',
      'swap',
      'taker',
      '`user`',
    ]);
  }

  static bool _isSwapSlippageError(String lowered) {
    if (!lowered.contains('slippage') && !lowered.contains('price movement')) {
      return false;
    }
    return _containsAny(lowered, const ['swap', 'jupiter', '/order', 'quote']);
  }

  static bool _containsSensitiveEndpoint(String raw, String lowered) {
    final hasUrl = RegExp(r'https?://', caseSensitive: false).hasMatch(raw);
    final hasLocalHost = _containsAny(lowered, const [
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '10.0.3.2',
      'onrender.com',
    ]);
    final hasInfraShape = RegExp(
      r'\b\d{1,3}(\.\d{1,3}){3}:\d+\b',
    ).hasMatch(raw);

    return hasUrl || hasLocalHost || hasInfraShape;
  }
}
