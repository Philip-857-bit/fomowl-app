import '../models/bitcoin_account_state.dart';
import '../models/bitcoin_network_data.dart';
import 'amount_utils.dart';

class BitcoinAmountUtils {
  BitcoinAmountUtils._();
  static BigInt parse(String text) {
    final normalized = text.trim();
    if (normalized.length > 32 ||
        !RegExp(r'^\d+(?:\.\d{1,8})?$').hasMatch(normalized)) {
      throw const FormatException('Enter BTC with at most 8 decimal places.');
    }
    final sats = AmountUtils.parseDecimalToBaseUnits(normalized, 8);
    if (sats <= BigInt.zero || sats > bitcoinMaxMoneySats) {
      throw const FormatException('Invalid Bitcoin amount.');
    }
    return sats;
  }

  static String format(BigInt sats) {
    if (sats.isNegative || sats > bitcoinMaxMoneySats) {
      throw const FormatException('Invalid Bitcoin amount.');
    }
    return AmountUtils.formatBaseUnits(sats, 8, maxFractionDigits: 8);
  }

  /// Input guidance only. The SDK validates checksum, network and script support.
  static bool recipientLooksCompatible(
    String text,
    BitcoinProductNetwork network,
  ) {
    final prefix = network == BitcoinProductNetwork.mainnet ? 'bc1' : 'tb1';
    return text.length >= 14 &&
        text.length <= 90 &&
        text == text.toLowerCase() &&
        text.startsWith(prefix) &&
        !RegExp(r'\s').hasMatch(text);
  }
}
