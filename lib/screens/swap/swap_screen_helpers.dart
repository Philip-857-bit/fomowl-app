import 'package:decimal/decimal.dart';

import '../../utils/amount_utils.dart';

/// Pure, widget-state-free helpers for the swap screen.
///
/// These were extracted from `swap_screen.dart` so the parsing, formatting and
/// error-classification logic can be reasoned about and unit-tested in
/// isolation, without standing up a widget tree. Nothing here touches
/// `BuildContext`, `setState`, or any screen state.

final RegExp _txHashPattern = RegExp(r'^0x[a-fA-F0-9]{64}$');
final RegExp _solanaPublicKeyPattern = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$');

/// Whether [value] is a 0x-prefixed 32-byte EVM transaction hash.
bool looksLikeTxHash(String value) => _txHashPattern.hasMatch(value);

/// Whether [value] looks like a base58 Solana public key (32–44 chars).
bool looksLikeSolanaPublicKey(String value) =>
    _solanaPublicKeyPattern.hasMatch(value.trim());

/// Abbreviate a hash/address as `0x1234...abcd` for display.
String shortHash(String hash) {
  if (hash.length <= 10) return hash;
  return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
}

// ── Swap error classification ───────────────────────────────────────────────
// [lower] is expected to already be lower-cased by the caller.

/// Insufficient-SOL style balance failures originating from a Solana swap.
bool isSolanaSwapBalanceError(String lower) {
  final hasBalanceSignal =
      lower.contains('insufficient funds') ||
      lower.contains('not enough sol') ||
      lower.contains('don\'t have enough sol') ||
      lower.contains('dont have enough sol');
  if (!hasBalanceSignal) return false;
  return lower.contains('jupiter') ||
      lower.contains('/order') ||
      lower.contains('swap') ||
      lower.contains('quote') ||
      lower.contains('unsigned transaction') ||
      lower.contains('transaction":""');
}

/// Invalid-wallet-address failures originating from a Solana swap.
bool isSolanaSwapAddressError(String lower) {
  final hasAddressSignal =
      lower.contains('invalid taker') ||
      lower.contains('valid public key') ||
      lower.contains('selected solana wallet address is invalid');
  if (!hasAddressSignal) return false;
  return lower.contains('solana') ||
      lower.contains('jupiter') ||
      lower.contains('swap') ||
      lower.contains('taker') ||
      lower.contains('`user`');
}

/// Slippage / price-movement failures originating from a swap quote.
bool isSwapPriceMovementError(String lower) {
  if (!lower.contains('slippage') && !lower.contains('price movement')) {
    return false;
  }
  return lower.contains('swap') ||
      lower.contains('jupiter') ||
      lower.contains('/order') ||
      lower.contains('quote');
}

// ── Amount parsing / formatting ─────────────────────────────────────────────

/// Parse a user-entered amount string (commas stripped) into a [Decimal],
/// returning [Decimal.zero] for empty or unparseable input.
Decimal parseDecimalAmount(String rawValue) {
  final cleaned = rawValue.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return Decimal.zero;
  return Decimal.tryParse(cleaned) ?? Decimal.zero;
}

/// Convert a decimal amount string to its base-unit (wei-equivalent) string for
/// the given [decimals], or `null` if the input is empty or malformed.
String? toWeiAmount(String amountText, int decimals) {
  final cleaned = amountText.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  try {
    return AmountUtils.parseDecimalToBaseUnits(cleaned, decimals).toString();
  } on FormatException {
    return null;
  }
}

/// Render [value] with at most [fractionDigits] decimals, trimming trailing
/// zeros (and a dangling decimal point).
String formatDecimalInput(Decimal value, int fractionDigits) {
  final raw = value.toString();
  if (!raw.contains('.')) return raw;
  final parts = raw.split('.');
  var fraction = parts[1];
  if (fraction.length > fractionDigits) {
    fraction = fraction.substring(0, fractionDigits);
  }
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? parts[0] : '${parts[0]}.$fraction';
}

// ── Gasless swap response parsing ───────────────────────────────────────────

/// Pull a status string out of a gasless-swap status response, checking the
/// top-level payload then the nested `trade` / `result` objects.
String? extractGaslessStatusValue(Map<String, dynamic> data) {
  final direct = data['status']?.toString();
  if (direct != null && direct.isNotEmpty) return direct;
  final trade = data['trade'];
  if (trade is Map<String, dynamic>) {
    final nested = trade['status']?.toString();
    if (nested != null && nested.isNotEmpty) return nested;
  }
  final result = data['result'];
  if (result is Map<String, dynamic>) {
    final nested = result['status']?.toString();
    if (nested != null && nested.isNotEmpty) return nested;
  }
  return null;
}

/// Locate the settlement transaction hash in a gasless-swap response, searching
/// explicit hash keys and the `transactions` lists under `trade` / `result`.
String? extractGaslessTxHash(Map<String, dynamic> data) {
  final direct = _extractExplicitGaslessTxHash(data);
  if (direct != null) return direct;
  final trade = data['trade'];
  if (trade is Map<String, dynamic>) {
    final nested = _extractExplicitGaslessTxHash(trade);
    if (nested != null) return nested;
    final listed = _extractTransactionListHash(trade['transactions']);
    if (listed != null) return listed;
  }
  final result = data['result'];
  if (result is Map<String, dynamic>) {
    final nested = _extractExplicitGaslessTxHash(result);
    if (nested != null) return nested;
    final listed = _extractTransactionListHash(result['transactions']);
    if (listed != null) return listed;
  }
  return null;
}

String? _extractExplicitGaslessTxHash(Map<String, dynamic> data) {
  const candidateKeys = [
    'transactionHash',
    'txHash',
    'settlementTxHash',
    'settledTxHash',
    'fillTxHash',
  ];
  for (final key in candidateKeys) {
    final value = data[key]?.toString();
    if (value != null && looksLikeTxHash(value)) {
      return value;
    }
  }
  return null;
}

String? _extractTransactionListHash(dynamic transactions) {
  if (transactions is! List) {
    return null;
  }
  for (final entry in transactions) {
    if (entry is! Map<String, dynamic>) {
      continue;
    }
    final explicit = _extractExplicitGaslessTxHash(entry);
    if (explicit != null) {
      return explicit;
    }
    final listedHash = entry['hash']?.toString();
    if (listedHash != null && looksLikeTxHash(listedHash)) {
      return listedHash;
    }
  }
  return null;
}
