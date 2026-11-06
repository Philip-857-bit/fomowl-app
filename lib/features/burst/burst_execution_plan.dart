/// Validated backend transaction details, captured before user approval.
class BurstExecutionPlan {
  const BurstExecutionPlan({
    required this.reference,
    required this.wallet,
    required this.campaignId,
    required this.operation,
    required this.chainId,
    required this.to,
    required this.value,
    required this.data,
  });
  final String reference;
  final String wallet;
  final String campaignId;
  final String operation;
  final int chainId;
  final String to;
  final BigInt value;
  final String data;

  /// Approvals are shown explicitly because NFT approval grants broad access.
  String? get approvalDescription {
    if (operation != 'approve') return null;
    if (data.length != 138 ||
        !RegExp(r'^0x(?:095ea7b3|a22cb465)[0-9a-f]{128}$').hasMatch(data)) {
      throw const FormatException('Invalid Burst approval transaction.');
    }
    final addressWord = data.substring(10, 74);
    if (!RegExp(r'^0{24}[0-9a-f]{40}$').hasMatch(addressWord)) {
      throw const FormatException('Invalid Burst approval recipient.');
    }
    final spender = '0x${addressWord.substring(24)}';
    if (RegExp(r'^0x0{40}$').hasMatch(spender)) {
      throw const FormatException('Invalid Burst approval recipient.');
    }
    final amount = BigInt.parse(data.substring(74), radix: 16);
    if (data.startsWith('0xa22cb465')) {
      if (amount != BigInt.one) {
        throw const FormatException('Invalid NFT approval.');
      }
      return 'Allows $spender to transfer all NFTs in this collection until approval is revoked.';
    }
    if (amount == BigInt.zero) {
      throw const FormatException('Invalid token approval.');
    }
    return 'Allows $spender to transfer up to $amount token base units.';
  }

  static BurstExecutionPlan parse(
    Map<String, dynamic> response, {
    required String reference,
    required String wallet,
    required int chainId,
    DateTime? now,
    bool allowExpired = false,
  }) {
    final transaction = response['transaction'];
    if (transaction is! Map ||
        response['walletAddress']?.toString().toLowerCase() !=
            wallet.toLowerCase() ||
        response['campaignId'] is! String ||
        (response['campaignId'] as String).isEmpty) {
      throw const FormatException('Invalid Burst execution identity.');
    }
    final network = transaction['chainId'];
    final actualReference = transaction['reference'];
    final destination = transaction['toAddress']?.toString() ?? '';
    final operation = transaction['operation']?.toString() ?? '';
    final data = transaction['calldata']?.toString() ?? '';
    final amount = transaction['valueBaseUnits']?.toString() ?? '';
    final expiry = DateTime.tryParse(
      transaction['expiresAt']?.toString() ?? '',
    );
    final selectors = switch (operation) {
      'approve' => const {'095ea7b3', 'a22cb465'},
      'create' => const {'a4be8afd', 'fc50ee32'},
      'push' => const {'9ad88796', 'c78a7f37'},
      'set_root' => const {'7cb64759'},
      'cancel' => const {'ea8a1af0'},
      'sweep' => const {'c44337b4', 'f44ae513'},
      _ => const <String>{},
    };
    final value = BigInt.tryParse(amount);
    if (actualReference != reference ||
        network != chainId ||
        chainId <= 0 ||
        expiry == null ||
        (!allowExpired &&
            !expiry.toUtc().isAfter((now ?? DateTime.now()).toUtc())) ||
        !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(destination) ||
        RegExp(r'^0x0{40}$', caseSensitive: false).hasMatch(destination) ||
        !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(data) ||
        data.length < 10 ||
        data.length.isOdd ||
        !selectors.contains(data.substring(2, 10).toLowerCase()) ||
        !RegExp(r'^\d+$').hasMatch(amount) ||
        value == null ||
        value.bitLength > 256) {
      throw const FormatException('Invalid or expired Burst transaction.');
    }
    final plan = BurstExecutionPlan(
      reference: reference,
      wallet: wallet.toLowerCase(),
      campaignId: response['campaignId'] as String,
      operation: operation,
      chainId: chainId,
      to: destination.toLowerCase(),
      value: value,
      data: data.toLowerCase(),
    );
    plan.approvalDescription;
    return plan;
  }

  /// A refreshed plan may extend its expiry, but may not alter what was approved.
  bool sameTransaction(BurstExecutionPlan other) =>
      reference == other.reference &&
      wallet == other.wallet &&
      campaignId == other.campaignId &&
      operation == other.operation &&
      chainId == other.chainId &&
      to == other.to &&
      value == other.value &&
      data == other.data;
}
