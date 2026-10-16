/// Public receipt facts only. Missing resource values are never treated as zero.
class NonEvmReceiptFacts {
  final String networkKey;
  final String transactionHash;
  final bool pending;
  final bool? success;
  final BigInt? blockHeight;
  final BigInt? feeBaseUnits;
  final BigInt? priorityFeeLamports;
  final BigInt? computeUnitsConsumed;
  final BigInt? energyUsed;
  final BigInt? bandwidthUsed;
  final BigInt? energyFeeSun;
  final BigInt? bandwidthFeeSun;
  final BigInt? feeLimitSun;

  const NonEvmReceiptFacts._({
    required this.networkKey,
    required this.transactionHash,
    required this.pending,
    required this.success,
    this.blockHeight,
    this.feeBaseUnits,
    this.priorityFeeLamports,
    this.computeUnitsConsumed,
    this.energyUsed,
    this.bandwidthUsed,
    this.energyFeeSun,
    this.bandwidthFeeSun,
    this.feeLimitSun,
  });

  static String canonicalNetwork(String key) => switch (key) {
    'solana:mainnet' || 'solana:mainnet-beta' => 'solana:mainnet',
    'tron:mainnet' => key,
    _ => throw const FormatException('Unsupported receipt network'),
  };

  static String checkedHash(String key, String hash) {
    final network = canonicalNetwork(key);
    final valid = network == 'tron:mainnet'
        ? RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)
        : RegExp(r'^[1-9A-HJ-NP-Za-km-z]{64,88}$').hasMatch(hash);
    if (!valid) {
      throw const FormatException('Invalid transaction identifier');
    }
    return network == 'tron:mainnet' ? hash.toLowerCase() : hash;
  }

  static BigInt? unsigned(Object? value) {
    if (value is! int && value is! String) {
      return null;
    }
    final text = value.toString();
    if (!RegExp(r'^(0|[1-9][0-9]{0,19})$').hasMatch(text)) {
      return null;
    }
    final number = BigInt.parse(text);
    return number.bitLength <= 64 ? number : null;
  }

  factory NonEvmReceiptFacts.fromJson(
    Map<String, dynamic> json, {
    required String networkKey,
    required String transactionHash,
  }) {
    final key = canonicalNetwork(networkKey);
    final hash = checkedHash(key, transactionHash);
    final returnedHash = json['transactionHash'];
    if (json['networkKey'] != key ||
        returnedHash is! String ||
        checkedHash(key, returnedHash) != hash ||
        json['pending'] != null && json['pending'] is! bool) {
      throw const FormatException(
        'Transaction details do not match the request',
      );
    }
    final pending = json['pending'] == true;
    if (pending) {
      return NonEvmReceiptFacts._(
        networkKey: key,
        transactionHash: hash,
        pending: true,
        success: null,
      );
    }
    if (key == 'solana:mainnet') {
      final fee = unsigned(json['feeLamports']);
      final priority = unsigned(json['priorityFeeLamports']);
      final status = json['status'];
      return NonEvmReceiptFacts._(
        networkKey: key,
        transactionHash: hash,
        pending: false,
        success: status is int && status == 1
            ? true
            : status is int && status == 0
            ? false
            : null,
        blockHeight: unsigned(json['slot']),
        feeBaseUnits: fee,
        priorityFeeLamports: priority != null && fee != null && priority <= fee
            ? priority
            : null,
        computeUnitsConsumed: unsigned(json['computeUnitsConsumed']),
      );
    }
    final receipt = json['receipt'] is Map<String, dynamic>
        ? json['receipt'] as Map<String, dynamic>
        : <String, dynamic>{};
    final results = [
      json['result'],
      receipt['result'],
    ].whereType<String>().map((value) => value.toUpperCase()).toSet();
    final succeeded = results.any({'SUCCESS', 'SUCESS'}.contains);
    final failed = results.any(
      {
        'FAILED',
        'FAIL',
        'REVERT',
        'OUT_OF_ENERGY',
        'OUT_OF_TIME',
        'BAD_JUMP_DESTINATION',
        'TRANSFER_FAILED',
      }.contains,
    );
    return NonEvmReceiptFacts._(
      networkKey: key,
      transactionHash: hash,
      pending: false,
      success: succeeded == failed ? null : succeeded,
      blockHeight: unsigned(json['blockNumber']),
      feeBaseUnits: unsigned(json['feeSun'] ?? json['fee']),
      energyUsed: unsigned(receipt['energy_usage_total']),
      bandwidthUsed: unsigned(receipt['net_usage']),
      energyFeeSun: unsigned(receipt['energy_fee']),
      bandwidthFeeSun: unsigned(receipt['net_fee']),
      feeLimitSun: unsigned(json['feeLimitSun']),
    );
  }
}
