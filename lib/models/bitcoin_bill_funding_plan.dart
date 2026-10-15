import 'dart:convert';
import 'bitcoin_account_state.dart';
import '../utils/bitcoin_amount_utils.dart';

/// A public invoice obtained by the native host using its retained session.
/// JavaScript supplies only the reference; it cannot authorize these fields.
class BitcoinBillFundingPlan {
  final String reference;
  final String collectionId;
  final String walletIdentity;
  final String destination;
  final BigInt amountSat;
  final DateTime expiresAt;
  final String provider;
  final String serviceType;
  final String serviceId;
  final String beneficiary;
  final BigInt amountKobo;
  final Map<String, dynamic> _bill;
  BitcoinProductNetwork get network => BitcoinProductNetwork.mainnet;

  const BitcoinBillFundingPlan._({
    required this.reference,
    required this.collectionId,
    required this.walletIdentity,
    required this.destination,
    required this.amountSat,
    required this.expiresAt,
    required this.provider,
    required this.serviceType,
    required this.serviceId,
    required this.beneficiary,
    required this.amountKobo,
    required Map<String, dynamic> bill,
  }) : _bill = bill;

  Map<String, dynamic> toServerJson() => {
    'reference': reference,
    'collectionPaymentId': collectionId,
    'walletIdentity': walletIdentity,
    'action': 'transfer',
    'quoteMode': 'owllet_bitcoin_bill',
    'networkKey': network.networkKey,
    'chainFamily': 'bitcoin',
    'assetSymbol': 'BTC',
    'nativeSymbol': 'BTC',
    'decimals': 8,
    'amountBaseUnits': amountSat.toString(),
    'expiresAt': expiresAt.millisecondsSinceEpoch ~/ 1000,
    'toAddress': destination,
    'billProvider': provider,
    'bill': _bill,
  };

  bool matches(BitcoinBillFundingPlan other) =>
      jsonEncode(toServerJson()) == jsonEncode(other.toServerJson());

  static bool validReference(String value) =>
      RegExp(r'^OWL-BTC-BILL-[0-9a-f]{32}$').hasMatch(value);

  factory BitcoinBillFundingPlan.fromServer(
    String expectedReference,
    String expectedIdentity,
    Map<String, dynamic> value,
  ) {
    Never invalid() =>
        throw const FormatException('Invalid Bitcoin bill invoice');
    String text(Object? raw, int maximum) {
      if (raw is! String ||
          raw.isEmpty ||
          raw.length > maximum ||
          raw.trim() != raw ||
          raw.codeUnits.any((c) => c < 32 || c == 127)) {
        invalid();
      }
      return raw;
    }

    final identity = expectedIdentity.trim().toLowerCase();
    final amount = value['amountBaseUnits'];
    final expiry = value['expiresAt'];
    final bill = value['bill'];
    if (!validReference(expectedReference) ||
        identity.isEmpty ||
        value['reference'] != expectedReference ||
        value['walletIdentity'] != identity ||
        value['action'] != 'transfer' ||
        value['quoteMode'] != 'owllet_bitcoin_bill' ||
        value['networkKey'] != 'bitcoin:mainnet' ||
        value['chainFamily'] != 'bitcoin' ||
        value['assetSymbol'] != 'BTC' ||
        value['nativeSymbol'] != 'BTC' ||
        value['decimals'] != 8 ||
        value['decimals'] is! int ||
        value['tokenContract'] != null ||
        amount is! String ||
        !RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(amount) ||
        expiry is! int ||
        expiry < 0 ||
        expiry > 253402300799 ||
        bill is! Map<String, dynamic>) {
      invalid();
    }
    final sats = BigInt.parse(amount);
    final destination = text(value['toAddress'], 100);
    final provider = text(value['billProvider'], 16);
    final service = text(bill['serviceType'], 16);
    final kobo = bill['amountKobo'];
    for (final key in ['variationCode', 'contactPhone', 'meterType']) {
      if (bill[key] != null) text(bill[key], 80);
    }
    if (sats > BigInt.from(2100000000000000) ||
        !BitcoinAmountUtils.recipientLooksCompatible(
          destination,
          BitcoinProductNetwork.mainnet,
        ) ||
        !{'vtpass', 'ebills'}.contains(provider) ||
        !{'airtime', 'data', 'electricity', 'tv'}.contains(service) ||
        kobo is! int ||
        kobo <= 0) {
      invalid();
    }
    return BitcoinBillFundingPlan._(
      reference: expectedReference,
      collectionId: text(value['collectionPaymentId'], 128),
      walletIdentity: identity,
      destination: destination,
      amountSat: sats,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiry * 1000,
        isUtc: true,
      ),
      provider: provider,
      serviceType: service,
      serviceId: text(bill['serviceId'], 80),
      beneficiary: text(bill['beneficiary'], 80),
      amountKobo: BigInt.from(kobo),
      bill: Map<String, dynamic>.unmodifiable({
        'serviceType': service,
        'serviceId': bill['serviceId'],
        'beneficiary': bill['beneficiary'],
        'amountKobo': kobo,
        'variationCode': bill['variationCode'],
        'contactPhone': bill['contactPhone'],
        'meterType': bill['meterType'],
      }),
    );
  }
}
