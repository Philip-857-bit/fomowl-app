import 'bitcoin_account_state.dart';
import '../utils/bitcoin_amount_utils.dart';

/// Public payment intent fetched by the authenticated host from the backend.
/// Only the Rust planner validates the final address and constructs the spend.
class BitcoinOfframpIntent {
  final String reference;
  final String destination;
  final BigInt amountSat;
  final DateTime fundingExpiresAt;
  BitcoinProductNetwork get network => BitcoinProductNetwork.mainnet;

  const BitcoinOfframpIntent._(
    this.reference,
    this.destination,
    this.amountSat,
    this.fundingExpiresAt,
  );

  static bool validReference(String value) =>
      value.isNotEmpty &&
      value.length <= 128 &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);

  factory BitcoinOfframpIntent.fromWithdrawalPlan(
    String expectedReference,
    Map<String, dynamic> plan,
  ) {
    final reference = plan['reference'];
    final destination = plan['toAddress'];
    final amount = plan['amountBaseUnits'];
    final expiry = plan['fundingExpiresAt'];
    if (expiry is! String ||
        expiry.length > 32 ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$',
        ).hasMatch(expiry)) {
      throw const FormatException('Invalid Bitcoin cash-out funding deadline');
    }
    final expires = DateTime.tryParse(expiry);
    if (expires == null ||
        !expires.isUtc ||
        expires.toIso8601String().substring(0, 19) != expiry.substring(0, 19)) {
      throw const FormatException('Invalid Bitcoin cash-out funding deadline');
    }
    if (!validReference(expectedReference) ||
        reference != expectedReference ||
        plan['action'] != 'transfer' ||
        plan['networkKey'] != 'bitcoin:mainnet' ||
        plan['chainFamily'] != 'bitcoin' ||
        plan['assetSymbol'] != 'BTC' ||
        plan['nativeSymbol'] != 'BTC' ||
        plan['decimals'] is! int ||
        plan['decimals'] != 8 ||
        plan['tokenContract'] != null ||
        destination is! String ||
        !BitcoinAmountUtils.recipientLooksCompatible(
          destination,
          BitcoinProductNetwork.mainnet,
        ) ||
        amount is! String ||
        !RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(amount)) {
      throw const FormatException('Invalid Bitcoin cash-out intent');
    }
    final sats = BigInt.parse(amount);
    if (sats > BigInt.from(2100000000000000) ||
        [
          'sourceNetworkKey',
          'sourceChainFamily',
          'sourceAssetSymbol',
          'sourceTokenContract',
          'sourceDecimals',
          'quoteMode',
        ].any((field) => plan[field] != null)) {
      throw const FormatException('Invalid Bitcoin cash-out intent');
    }
    return BitcoinOfframpIntent._(
      expectedReference,
      destination,
      sats,
      expires,
    );
  }

  bool matches(BitcoinOfframpIntent other) =>
      reference == other.reference &&
      destination == other.destination &&
      amountSat == other.amountSat &&
      fundingExpiresAt == other.fundingExpiresAt;
}
