import 'dart:convert';
import 'evm_fee_quote.dart';

enum EvmOutboundState { unknown, submitted, rejected, settled }

enum EvmReplacementKind { speedUp, cancel }

class EvmReplacementException implements Exception {
  final String message;
  const EvmReplacementException(this.message);
  @override
  String toString() => message;
}

class EvmSubmissionUnknown extends EvmReplacementException {
  final String hash;
  const EvmSubmissionUnknown(this.hash)
    : super(
        'Submission outcome is unknown. Check its status before trying again.',
      );
}

/// Exact public fields supplied to the opaque Rust signer. No keys or signatures.
class EvmTransactionFields {
  final int chainId;
  final String sender;
  final int nonce;
  final String destination;
  final BigInt valueWei;
  final String dataHex;
  final int gasLimit;
  final BigInt? gasPriceWei;
  final BigInt? maxFeePerGasWei;
  final BigInt? maxPriorityFeePerGasWei;
  EvmTransactionFields({
    required this.chainId,
    required String sender,
    required this.nonce,
    required String destination,
    required this.valueWei,
    required String dataHex,
    required this.gasLimit,
    this.gasPriceWei,
    this.maxFeePerGasWei,
    this.maxPriorityFeePerGasWei,
  }) : sender = sender.toLowerCase(),
       destination = destination.toLowerCase(),
       dataHex = dataHex.toLowerCase() {
    final address = RegExp(r'^0x[0-9a-f]{40}$');
    final typed = maxFeePerGasWei != null || maxPriorityFeePerGasWei != null;
    if (chainId <= 0 ||
        chainId.bitLength > 63 ||
        nonce < 0 ||
        nonce.bitLength > 63 ||
        !address.hasMatch(this.sender) ||
        !address.hasMatch(this.destination) ||
        valueWei < BigInt.zero ||
        valueWei.bitLength > 256 ||
        gasLimit <= 0 ||
        gasLimit.bitLength > 63 ||
        this.dataHex.length > 32770 ||
        !RegExp(r'^0x(?:[0-9a-f]{2})*$').hasMatch(this.dataHex) ||
        [
          gasPriceWei,
          maxFeePerGasWei,
          maxPriorityFeePerGasWei,
        ].any((v) => v != null && (v < BigInt.zero || v.bitLength > 128)) ||
        (typed
            ? gasPriceWei != null ||
                  maxFeePerGasWei == null ||
                  maxPriorityFeePerGasWei == null ||
                  maxPriorityFeePerGasWei! > maxFeePerGasWei!
            : gasPriceWei == null)) {
      throw const EvmReplacementException(
        'Invalid outbound transaction metadata',
      );
    }
  }
  EvmTransactionType get type => gasPriceWei == null
      ? EvmTransactionType.dynamicFee
      : EvmTransactionType.legacy;
  BigInt get maximumFeeWei =>
      BigInt.from(gasLimit) * (gasPriceWei ?? maxFeePerGasWei!);
  BigInt effectivePrice(BigInt base) {
    if (gasPriceWei != null) return gasPriceWei!;
    final current = base + maxPriorityFeePerGasWei!;
    return current > maxFeePerGasWei! ? maxFeePerGasWei! : current;
  }

  Map<String, dynamic> toJson() => {
    'chainId': chainId,
    'sender': sender,
    'nonce': nonce,
    'destination': destination,
    'valueWei': valueWei.toString(),
    'dataHex': dataHex,
    'gasLimit': gasLimit,
    'gasPriceWei': gasPriceWei?.toString(),
    'maxFeePerGasWei': maxFeePerGasWei?.toString(),
    'maxPriorityFeePerGasWei': maxPriorityFeePerGasWei?.toString(),
  };
  static BigInt _integer(Object? value) {
    if (value is! String ||
        value.length > 78 ||
        !RegExp(r'^(?:0|[1-9][0-9]*)$').hasMatch(value)) {
      throw const EvmReplacementException(
        'Invalid outbound transaction metadata',
      );
    }
    return BigInt.parse(value);
  }

  factory EvmTransactionFields.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json.length != 10 ||
        json['chainId'] is! int ||
        json['sender'] is! String ||
        json['nonce'] is! int ||
        json['destination'] is! String ||
        json['dataHex'] is! String ||
        json['gasLimit'] is! int) {
      throw const EvmReplacementException(
        'Invalid outbound transaction metadata',
      );
    }
    return EvmTransactionFields(
      chainId: json['chainId'],
      sender: json['sender'],
      nonce: json['nonce'],
      destination: json['destination'],
      valueWei: _integer(json['valueWei']),
      dataHex: json['dataHex'],
      gasLimit: json['gasLimit'],
      gasPriceWei: json['gasPriceWei'] == null
          ? null
          : _integer(json['gasPriceWei']),
      maxFeePerGasWei: json['maxFeePerGasWei'] == null
          ? null
          : _integer(json['maxFeePerGasWei']),
      maxPriorityFeePerGasWei: json['maxPriorityFeePerGasWei'] == null
          ? null
          : _integer(json['maxPriorityFeePerGasWei']),
    );
  }
  bool sameAs(EvmTransactionFields other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());
  @override
  String toString() => 'EvmTransactionFields(chain: $chainId, nonce: $nonce)';
}

class EvmOutboundTransaction {
  final EvmTransactionFields fields;
  final String hash;
  final String rootHash;
  final String? replacesHash;
  final EvmOutboundState state;
  final DateTime createdAt;
  EvmOutboundTransaction({
    required this.fields,
    required String hash,
    String? rootHash,
    this.replacesHash,
    required this.state,
    required DateTime createdAt,
  }) : hash = hash.toLowerCase(),
       rootHash = (rootHash ?? hash).toLowerCase(),
       createdAt = createdAt.toUtc() {
    final pattern = RegExp(r'^0x[0-9a-f]{64}$');
    if (!pattern.hasMatch(this.hash) ||
        !pattern.hasMatch(this.rootHash) ||
        replacesHash != null && !pattern.hasMatch(replacesHash!) ||
        (replacesHash == null) != (this.rootHash == this.hash) ||
        replacesHash == this.hash) {
      throw const EvmReplacementException(
        'Invalid outbound transaction identity',
      );
    }
  }
  bool get unresolved =>
      state == EvmOutboundState.unknown || state == EvmOutboundState.submitted;
  EvmOutboundTransaction withState(EvmOutboundState value) =>
      EvmOutboundTransaction(
        fields: fields,
        hash: hash,
        rootHash: rootHash,
        replacesHash: replacesHash,
        state: value,
        createdAt: createdAt,
      );
  Map<String, dynamic> toJson() => {
    'fields': fields.toJson(),
    'hash': hash,
    'rootHash': rootHash,
    'replacesHash': replacesHash,
    'state': state.name,
    'createdAt': createdAt.toIso8601String(),
  };
  factory EvmOutboundTransaction.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json.length != 6 ||
        json['hash'] is! String ||
        json['rootHash'] is! String ||
        json['state'] is! String ||
        json['createdAt'] is! String ||
        (json['createdAt'] as String).length > 64 ||
        json['replacesHash'] != null && json['replacesHash'] is! String) {
      throw const EvmReplacementException(
        'Invalid outbound transaction record',
      );
    }
    final states = EvmOutboundState.values.where(
      (s) => s.name == json['state'],
    );
    final date = DateTime.tryParse(json['createdAt']);
    if (states.length != 1 || date == null) {
      throw const EvmReplacementException(
        'Invalid outbound transaction record',
      );
    }
    return EvmOutboundTransaction(
      fields: EvmTransactionFields.fromJson(json['fields']),
      hash: json['hash'],
      rootHash: json['rootHash'],
      replacesHash: json['replacesHash'],
      state: states.single,
      createdAt: date,
    );
  }
  @override
  String toString() =>
      'EvmOutboundTransaction(chain: ${fields.chainId}, state: ${state.name})';
}
