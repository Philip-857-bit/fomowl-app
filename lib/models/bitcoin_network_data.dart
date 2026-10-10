import 'bitcoin_account_state.dart';

final bitcoinMaxMoneySats = BigInt.from(2100000000000000);
Map<String, dynamic> bitcoinJsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid Bitcoin network response');
  }
  return value;
}

String bitcoinJsonString(Object? value, {int maxLength = 256}) {
  if (value is! String || value.isEmpty || value.length > maxLength) {
    throw const FormatException('Invalid Bitcoin network response');
  }
  return value;
}

int bitcoinJsonInt(Object? value, {int maximum = 0x7fffffff}) {
  if (value is! int || value < 0 || value > maximum) {
    throw const FormatException('Invalid Bitcoin network integer');
  }
  return value;
}

bool bitcoinJsonBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Bitcoin network response');
  }
  return value;
}

BigInt bitcoinJsonSats(
  Object? value, {
  bool signed = false,
  bool allowZero = true,
}) {
  if (value is! int) {
    throw const FormatException('Invalid Bitcoin satoshi amount');
  }
  final amount = BigInt.from(value);
  if (amount.abs() > bitcoinMaxMoneySats ||
      !signed && amount.isNegative ||
      !allowZero && amount == BigInt.zero) {
    throw const FormatException('Invalid Bitcoin satoshi amount');
  }
  return amount;
}

String bitcoinTxid(Object? value) {
  final hash = bitcoinJsonString(value, maxLength: 64);
  if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
    throw const FormatException('Invalid Bitcoin transaction ID');
  }
  return hash.toLowerCase();
}

List<dynamic> _list(Object? value, int limit) {
  if (value is! List || value.length > limit) {
    throw const FormatException('Invalid Bitcoin network response');
  }
  return value;
}

class BitcoinNetworkUtxo {
  final String txid;
  final int vout;
  final BigInt valueSats;
  final String address;
  final String scriptPubkeyHex;
  final bool confirmed;
  final int? blockHeight;
  BitcoinNetworkUtxo.fromJson(Map<String, dynamic> json)
    : txid = bitcoinTxid(json['txid']),
      vout = bitcoinJsonInt(json['vout'], maximum: 0xffffffff),
      valueSats = bitcoinJsonSats(json['valueSats'], allowZero: false),
      address = bitcoinJsonString(json['address'], maxLength: 90),
      scriptPubkeyHex = bitcoinJsonString(
        json['scriptPubkeyHex'],
        maxLength: 128,
      ),
      confirmed = bitcoinJsonBool(json['confirmed']),
      blockHeight = json['blockHeight'] == null
          ? null
          : bitcoinJsonInt(json['blockHeight']) {
    if (!RegExp(r'^(?:[0-9a-fA-F]{2})+$').hasMatch(scriptPubkeyHex) ||
        confirmed && blockHeight == null ||
        !confirmed && blockHeight != null) {
      throw const FormatException('Invalid Bitcoin UTXO response');
    }
  }
  String get outpoint => '$txid:$vout';
}

class BitcoinAddressActivity {
  final String address;
  final bool reportedUsed;
  final BigInt confirmedBalanceSats;
  final BigInt mempoolBalanceSats;
  final int txCount;
  final List<BitcoinNetworkUtxo> utxos;
  BitcoinAddressActivity.fromJson(Map<String, dynamic> json)
    : address = bitcoinJsonString(json['address'], maxLength: 90),
      reportedUsed = bitcoinJsonBool(json['used']),
      confirmedBalanceSats = bitcoinJsonSats(json['confirmedBalanceSats']),
      mempoolBalanceSats = bitcoinJsonSats(
        json['mempoolBalanceSats'],
        signed: true,
      ),
      txCount = bitcoinJsonInt(json['txCount']),
      utxos = List.unmodifiable(
        _list(
          json['utxos'],
          10000,
        ).map((value) => BitcoinNetworkUtxo.fromJson(bitcoinJsonObject(value))),
      ) {
    if (utxos.any((utxo) => utxo.address != address)) {
      throw const FormatException('Bitcoin UTXO address mismatch');
    }
  }
  bool get used => reportedUsed || txCount > 0 || utxos.isNotEmpty;
}

enum BitcoinFeeTier { economy, normal, priority }

class BitcoinFeeRates {
  final int economy;
  final int normal;
  final int priority;
  final int minimum;
  final bool stale;
  BitcoinFeeRates.fromJson(Map<String, dynamic> json)
    : economy = bitcoinJsonInt(json['economy'], maximum: 10000),
      normal = bitcoinJsonInt(json['normal'], maximum: 10000),
      priority = bitcoinJsonInt(json['priority'], maximum: 10000),
      minimum = bitcoinJsonInt(json['minimum'], maximum: 10000),
      stale = bitcoinJsonBool(json['stale']) {
    if (minimum < 1 ||
        economy < minimum ||
        normal < economy ||
        priority < normal) {
      throw const FormatException('Invalid Bitcoin fee rates');
    }
  }
  BigInt rate(BitcoinFeeTier tier) => BigInt.from(switch (tier) {
    BitcoinFeeTier.economy => economy,
    BitcoinFeeTier.normal => normal,
    BitcoinFeeTier.priority => priority,
  });
  bool get hasDistinctTiers => economy != normal || normal != priority;
}

class BitcoinTransactionStatus {
  final bool confirmed;
  final bool found;
  final int confirmations;
  final int? blockHeight;
  final String? blockHash;
  final int? timestamp;
  BitcoinTransactionStatus.fromJson(Map<String, dynamic> json)
    : confirmed = bitcoinJsonBool(json['confirmed']),
      found = bitcoinJsonBool(json['found']),
      confirmations = bitcoinJsonInt(json['confirmations']),
      blockHeight = json['blockHeight'] == null
          ? null
          : bitcoinJsonInt(json['blockHeight']),
      blockHash = json['blockHash'] == null
          ? null
          : bitcoinTxid(json['blockHash']),
      timestamp = json['timestamp'] == null
          ? null
          : bitcoinJsonInt(json['timestamp'], maximum: 0xffffffff) {
    if (json['status'] != (confirmed ? 'confirmed' : 'pending') ||
        confirmed &&
            (!found ||
                confirmations < 1 ||
                blockHeight == null ||
                blockHash == null) ||
        !confirmed &&
            (confirmations != 0 || blockHeight != null || blockHash != null)) {
      throw const FormatException('Invalid Bitcoin transaction status');
    }
  }
}

class BitcoinOwnedAmount {
  final String address;
  final BigInt valueSats;
  BitcoinOwnedAmount.fromJson(Map<String, dynamic> json)
    : address = bitcoinJsonString(json['address'], maxLength: 90),
      valueSats = bitcoinJsonSats(json['valueSats']);
}

class BitcoinHistoryObservation {
  final int position;
  final String? address;
  final BigInt valueSats;
  BitcoinHistoryObservation.fromJson(Map<String, dynamic> json)
    : position = bitcoinJsonInt(json['position'], maximum: 9999),
      address = json['address'] == null
          ? null
          : bitcoinJsonString(json['address'], maxLength: 90),
      valueSats = bitcoinJsonSats(json['valueSats']);
  bool sameAs(BitcoinHistoryObservation other) =>
      position == other.position &&
      address == other.address &&
      valueSats == other.valueSats;
}

List<BitcoinHistoryObservation> _observations(Object? raw) {
  final values = _list(raw, 10000)
      .map(
        (value) => BitcoinHistoryObservation.fromJson(bitcoinJsonObject(value)),
      )
      .toList();
  for (var index = 0; index < values.length; index++) {
    if (values[index].position != index) {
      throw const FormatException('Invalid Bitcoin history positions');
    }
  }
  return List.unmodifiable(values);
}

class BitcoinHistoryTransaction {
  final String txid;
  final int? timestamp;
  final int confirmations;
  final int? blockHeight;
  final String? blockHash;
  final List<BitcoinOwnedAmount> ownedInputs;
  final List<BitcoinOwnedAmount> ownedOutputs;
  final List<BitcoinHistoryObservation> inputs;
  final List<BitcoinHistoryObservation> outputs;
  final BigInt netWalletDeltaSats;
  final BigInt feeSats;
  final String direction;
  BitcoinHistoryTransaction.fromJson(Map<String, dynamic> json)
    : txid = bitcoinTxid(json['txid']),
      timestamp = json['timestamp'] == null
          ? null
          : bitcoinJsonInt(json['timestamp'], maximum: 0xffffffff),
      confirmations = bitcoinJsonInt(json['confirmations']),
      blockHeight = json['blockHeight'] == null
          ? null
          : bitcoinJsonInt(json['blockHeight']),
      blockHash = json['blockHash'] == null
          ? null
          : bitcoinTxid(json['blockHash']),
      ownedInputs = List.unmodifiable(
        _list(
          json['ownedInputs'],
          10000,
        ).map((value) => BitcoinOwnedAmount.fromJson(bitcoinJsonObject(value))),
      ),
      ownedOutputs = List.unmodifiable(
        _list(
          json['ownedOutputs'],
          10000,
        ).map((value) => BitcoinOwnedAmount.fromJson(bitcoinJsonObject(value))),
      ),
      inputs = _observations(json['inputs']),
      outputs = _observations(json['outputs']),
      netWalletDeltaSats = bitcoinJsonSats(
        json['netWalletDeltaSats'],
        signed: true,
      ),
      feeSats = bitcoinJsonSats(json['feeSats']),
      direction = bitcoinJsonString(json['direction'], maxLength: 16) {
    final incoming = ownedOutputs.fold(
      BigInt.zero,
      (sum, output) => sum + output.valueSats,
    );
    final outgoing = ownedInputs.fold(
      BigInt.zero,
      (sum, input) => sum + input.valueSats,
    );
    final inputTotal = inputs.fold(
      BigInt.zero,
      (sum, input) => sum + input.valueSats,
    );
    final outputTotal = outputs.fold(
      BigInt.zero,
      (sum, output) => sum + output.valueSats,
    );
    if (outputs.isEmpty ||
        inputTotal > bitcoinMaxMoneySats ||
        outputTotal > bitcoinMaxMoneySats ||
        inputs.isNotEmpty && inputTotal - outputTotal != feeSats ||
        inputs.isEmpty && feeSats != BigInt.zero) {
      throw const FormatException('Inconsistent Bitcoin history observations');
    }
    final expectedDirection = netWalletDeltaSats.isNegative
        ? 'outgoing'
        : netWalletDeltaSats > BigInt.zero
        ? 'incoming'
        : 'self';
    if (direction != expectedDirection ||
        incoming - outgoing != netWalletDeltaSats ||
        incoming > bitcoinMaxMoneySats ||
        outgoing > bitcoinMaxMoneySats ||
        confirmations == 0 && (blockHeight != null || blockHash != null) ||
        confirmations > 0 && (blockHeight == null || blockHash == null)) {
      throw const FormatException('Invalid Bitcoin history response');
    }
  }
}

class BitcoinHistoryBatch {
  final BitcoinProductNetwork network;
  final List<BitcoinHistoryTransaction> transactions;
  final bool truncated;
  BitcoinHistoryBatch(
    this.network,
    Iterable<BitcoinHistoryTransaction> transactions,
    this.truncated,
  ) : transactions = List.unmodifiable(transactions);
}
