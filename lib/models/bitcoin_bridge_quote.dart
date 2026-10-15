import 'dart:convert';

const relayBitcoinChainId = 8253038;
const relayBitcoinCurrency = 'bc1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqmql8k8';

/// The user's requested route, kept separate from provider-returned facts.
class BitcoinBridgeRequest {
  final int originChainId;
  final int destinationChainId;
  final String originCurrency;
  final String destinationCurrency;
  final String sender;
  final String recipient;
  final BigInt amount;

  const BitcoinBridgeRequest({
    required this.originChainId,
    required this.destinationChainId,
    required this.originCurrency,
    required this.destinationCurrency,
    required this.sender,
    required this.recipient,
    required this.amount,
  });

  bool get bitcoinOrigin => originChainId == relayBitcoinChainId;
}

/// Public, immutable facts from the dedicated Bitcoin bridge boundary.
/// Address checksum/script validation and transaction fees remain in Rust.
class BitcoinBridgeQuote {
  final BitcoinBridgeRequest request;
  final bool committed;
  final String requestId;
  final String? depositAddress;
  final BigInt amountOut;
  final BigInt minimumAmountOut;
  final DateTime approvalExpiresAt;
  final DateTime providerDeadline;
  final List<Map<String, dynamic>> originSteps;
  final Map<String, dynamic> display;
  final String _encoded;

  const BitcoinBridgeQuote._({
    required this.request,
    required this.committed,
    required this.requestId,
    required this.depositAddress,
    required this.amountOut,
    required this.minimumAmountOut,
    required this.approvalExpiresAt,
    required this.providerDeadline,
    required this.originSteps,
    required this.display,
    required String encoded,
  }) : _encoded = encoded;

  Map<String, dynamic> toJson() =>
      Map<String, dynamic>.from(jsonDecode(_encoded) as Map);

  int get destinationDecimals =>
      ((toJson()['intent'] as Map)['destination'] as Map)['decimals'] as int;
  int get originDecimals =>
      ((toJson()['intent'] as Map)['origin'] as Map)['decimals'] as int;

  /// Decode protected historical metadata for observation only. This does not
  /// renew approval; a funding service must check the original expiry again.
  factory BitcoinBridgeQuote.fromRecord(Map<String, dynamic> json) {
    const error = FormatException('Invalid saved Bitcoin bridge quote');
    final intent = json['intent'];
    final expiry = json['approvalExpiresAt'];
    if (intent is! Map ||
        intent['origin'] is! Map ||
        intent['destination'] is! Map ||
        intent['sender'] is! String ||
        intent['recipient'] is! String ||
        intent['amount'] is! String ||
        expiry is! int ||
        expiry < 120 ||
        expiry > 253402300799) {
      throw error;
    }
    final origin = intent['origin'] as Map;
    final destination = intent['destination'] as Map;
    final amount = BigInt.tryParse(intent['amount'] as String);
    if (origin['chainId'] is! int ||
        destination['chainId'] is! int ||
        origin['currency'] is! String ||
        destination['currency'] is! String ||
        amount == null) {
      throw error;
    }
    return BitcoinBridgeQuote.fromJson(
      json,
      expected: BitcoinBridgeRequest(
        originChainId: origin['chainId'] as int,
        destinationChainId: destination['chainId'] as int,
        originCurrency: origin['currency'] as String,
        destinationCurrency: destination['currency'] as String,
        sender: intent['sender'] as String,
        recipient: intent['recipient'] as String,
        amount: amount,
      ),
      now: DateTime.fromMillisecondsSinceEpoch(
        (expiry - 120) * 1000,
        isUtc: true,
      ),
    );
  }

  factory BitcoinBridgeQuote.fromJson(
    Map<String, dynamic> json, {
    required BitcoinBridgeRequest expected,
    required DateTime now,
  }) {
    Never invalid() => throw const FormatException(
      'Bitcoin bridge quote changed or is unavailable',
    );
    const fields = {
      'committed',
      'requestId',
      'intent',
      'amountOut',
      'minimumAmountOut',
      'approvalExpiresAt',
      'providerDeadline',
      'bitcoinDepositAddress',
      'originSteps',
      'display',
    };
    if (json.keys.any((key) => !fields.contains(key))) {
      invalid();
    }
    final bitcoinOrigin = expected.bitcoinOrigin;
    if (bitcoinOrigin == (expected.destinationChainId == relayBitcoinChainId) ||
        expected.originChainId == expected.destinationChainId ||
        expected.amount <= BigInt.zero) {
      invalid();
    }
    bool same(int chain, Object? actual, String selected) =>
        actual is String &&
        (chain != relayBitcoinChainId && chain != 792703809
            ? actual.toLowerCase() == selected.toLowerCase()
            : actual == selected);
    Map<String, dynamic> object(Object? raw) {
      if (raw is! Map || raw.keys.any((key) => key is! String)) {
        invalid();
      }
      return Map<String, dynamic>.from(raw);
    }

    BigInt units(Object? raw) {
      if (raw is! String ||
          raw.length > 78 ||
          !RegExp(r'^[1-9][0-9]*$').hasMatch(raw)) {
        invalid();
      }
      final value = BigInt.parse(raw);
      if (value > (BigInt.one << 256) - BigInt.one) {
        invalid();
      }
      return value;
    }

    DateTime timestamp(Object? raw) {
      if (raw is! int || raw <= 0 || raw > 253402300799) {
        invalid();
      }
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
    }

    void asset(Object? raw, int id, String currency) {
      final data = object(raw);
      if (data['chainId'] is! int ||
          data['chainId'] != id ||
          !same(id, data['currency'], currency) ||
          data['decimals'] is! int) {
        invalid();
      }
      final decimals = data['decimals'] as int;
      if (decimals < 0 || decimals > 30) {
        invalid();
      }
      if (id == relayBitcoinChainId) {
        if (data['family'] != 'bitcoin' ||
            data['providerChain'] != 'bitcoin' ||
            currency != relayBitcoinCurrency ||
            decimals != 8) {
          invalid();
        }
      } else if (id == 792703809) {
        if (data['family'] != 'solana' || data['providerChain'] != 'solana') {
          invalid();
        }
      } else if (data['family'] != 'evm' || id <= 0 || id == 728126428) {
        invalid();
      }
    }

    final intent = object(json['intent']);
    asset(intent['origin'], expected.originChainId, expected.originCurrency);
    asset(
      intent['destination'],
      expected.destinationChainId,
      expected.destinationCurrency,
    );
    if (!same(expected.originChainId, intent['sender'], expected.sender) ||
        !same(expected.originChainId, intent['refundTo'], expected.sender) ||
        !same(
          expected.destinationChainId,
          intent['recipient'],
          expected.recipient,
        ) ||
        units(intent['amount']) != expected.amount) {
      invalid();
    }
    final amountOut = units(json['amountOut']);
    final minimum = units(json['minimumAmountOut']);
    final maximumSats = BigInt.from(2100000000000000);
    if (minimum > amountOut ||
        (bitcoinOrigin ? expected.amount : amountOut) > maximumSats) {
      invalid();
    }
    final expires = timestamp(json['approvalExpiresAt']);
    final deadline = timestamp(json['providerDeadline']);
    if (!expires.isAfter(now) ||
        expires.isAfter(now.add(const Duration(seconds: 150))) ||
        deadline.isBefore(expires)) {
      invalid();
    }
    final id = json['requestId'];
    if (id is! String ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(id) ||
        json['committed'] is! bool) {
      invalid();
    }
    final committed = json['committed'] as bool;
    final rawSteps = json['originSteps'];
    if (rawSteps is! List || rawSteps.length > 8) {
      invalid();
    }
    final address = json['bitcoinDepositAddress'];
    if (committed && bitcoinOrigin) {
      if (address is! String ||
          address.length > 90 ||
          !(address.startsWith('bc1q') || address.startsWith('bc1p')) ||
          rawSteps.isNotEmpty) {
        invalid();
      }
    } else {
      if (address != null ||
          (!committed && rawSteps.isNotEmpty) ||
          (committed && !bitcoinOrigin && rawSteps.isEmpty)) {
        invalid();
      }
    }
    final encoded = jsonEncode(json);
    if (encoded.length > 1048576) {
      invalid();
    }
    final immutable = _freeze(jsonDecode(encoded)) as Map<String, dynamic>;
    final steps = (immutable['originSteps'] as List)
        .map((step) => object(step))
        .toList(growable: false);
    return BitcoinBridgeQuote._(
      request: expected,
      committed: committed,
      requestId: id,
      depositAddress: address as String?,
      amountOut: amountOut,
      minimumAmountOut: minimum,
      approvalExpiresAt: expires,
      providerDeadline: deadline,
      originSteps: List.unmodifiable(
        steps.map((step) => Map<String, dynamic>.unmodifiable(step)),
      ),
      display: Map<String, dynamic>.unmodifiable(object(immutable['display'])),
      encoded: encoded,
    );
  }

  static Object? _freeze(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key as String, _freeze(item))),
      );
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_freeze));
    }
    return value;
  }
}
