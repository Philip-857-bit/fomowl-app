import 'burst_creation_validation.dart';

/// Validates the fee quote and campaign identity before any transaction review.
class BurstPreparedCampaign {
  const BurstPreparedCampaign({
    required this.id,
    required this.code,
    required this.transactions,
    required this.platformFee,
    required this.sponsorshipFee,
  });
  final String id;
  final String code;
  final List<Map<String, dynamic>> transactions;
  final BigInt platformFee;
  final BigInt sponsorshipFee;

  static BurstPreparedCampaign parse(
    Map<String, dynamic> response,
    Map<String, dynamic> draft, {
    required String factoryAddress,
    required String wallet,
    String? proxyInitCodeHash,
  }) {
    final campaign = response['campaign'];
    final rawTransactions = response['transactions'];
    final code = response['joinCode'];
    if (campaign is! Map ||
        rawTransactions is! List ||
        rawTransactions.isEmpty ||
        code is! String ||
        code.isEmpty ||
        campaign['id'] is! String ||
        (campaign['id'] as String).isEmpty) {
      throw const FormatException('The prepared Burst is incomplete.');
    }
    final isNft =
        draft['assetKind'] == 'erc721' || draft['assetKind'] == 'erc1155';
    for (final field in [
      'chainId',
      'title',
      'assetKind',
      'assetSymbol',
      'assetDecimals',
      'totalAmountBaseUnits',
      if (!isNft) 'amountPerParticipantBaseUnits',
      'maxParticipants',
      'startTime',
      'endTime',
    ]) {
      if (campaign[field] != draft[field]) {
        throw const FormatException(
          'The prepared Burst does not match your selection.',
        );
      }
    }
    if (draft['assetKind'] != 'native' &&
        campaign['assetAddress']?.toString().toLowerCase() !=
            draft['assetAddress']?.toString().toLowerCase()) {
      throw const FormatException(
        'The prepared asset does not match your selection.',
      );
    }
    final transactions = rawTransactions
        .map((value) {
          if (value is! Map) {
            throw const FormatException(
              'The prepared transactions are invalid.',
            );
          }
          return Map<String, dynamic>.from(value);
        })
        .toList(growable: false);
    final creations = transactions
        .where((item) => item['operation'] == 'create')
        .toList();
    final platform = _amount(campaign['platformFeeBaseUnits']);
    final sponsorship = _amount(campaign['gasSponsorshipFeeBaseUnits']);
    if (creations.length != 1) {
      throw const FormatException('The creation transaction is missing.');
    }
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(factoryAddress) ||
        RegExp(r'^0x0{40}$', caseSensitive: false).hasMatch(factoryAddress) ||
        creations.single['toAddress']?.toString().toLowerCase() !=
            factoryAddress.toLowerCase()) {
      throw const FormatException(
        'The creation transaction targets an unexpected factory.',
      );
    }
    final creation = _amount(creations.single['valueBaseUnits']);
    final distribution = draft['assetKind'] == 'native'
        ? _amount(draft['totalAmountBaseUnits'])
        : BigInt.zero;
    if (creation != distribution + platform + sponsorship) {
      throw const FormatException(
        'The campaign fee does not match the creation transaction.',
      );
    }
    validateBurstCreation(
      campaign: Map<String, dynamic>.from(campaign),
      draft: draft,
      transactions: transactions,
      factory: factoryAddress,
      wallet: wallet,
      proxyInitCodeHash: proxyInitCodeHash,
    );
    return BurstPreparedCampaign(
      id: campaign['id'] as String,
      code: code,
      transactions: transactions,
      platformFee: platform,
      sponsorshipFee: sponsorship,
    );
  }

  static BigInt _amount(dynamic input) {
    if (input is! String || !RegExp(r'^\d+$').hasMatch(input)) {
      throw const FormatException('Invalid Burst fee.');
    }
    final result = BigInt.parse(input);
    if (result.bitLength > 256) {
      throw const FormatException('Invalid Burst fee.');
    }
    return result;
  }
}
