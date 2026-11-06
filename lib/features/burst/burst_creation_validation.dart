import 'dart:typed_data';

import 'package:web3dart/crypto.dart';

/// Independently checks the factory call and approval against the user's draft.
void validateBurstCreation({
  required Map<String, dynamic> campaign,
  required Map<String, dynamic> draft,
  required List<Map<String, dynamic>> transactions,
  required String factory,
  required String wallet,
  String? proxyInitCodeHash,
}) {
  final kind = switch (draft['assetKind']) {
    'native' => 0,
    'erc20' => 1,
    'erc721' => 2,
    'erc1155' => 3,
    _ => throw const FormatException('Unsupported Burst asset.'),
  };
  final nft = kind >= 2;
  final create = transactions
      .where((tx) => tx['operation'] == 'create')
      .toList();
  if (create.length != 1 ||
      !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(factory) ||
      !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(wallet)) {
    throw const FormatException('Invalid Burst factory or wallet.');
  }
  final data = create.single['calldata']?.toString().toLowerCase() ?? '';
  final count = nft ? 8 : 9;
  final selector = nft ? 'fc50ee32' : 'a4be8afd';
  if (data.length != 10 + count * 64 ||
      !RegExp(r'^0x[0-9a-f]+$').hasMatch(data) ||
      data.substring(2, 10) != selector) {
    throw const FormatException('Invalid Burst creation calldata.');
  }
  String word(int index) => data.substring(10 + index * 64, 74 + index * 64);
  BigInt number(int index) => BigInt.parse(word(index), radix: 16);
  final token = kind == 0
      ? '0x${'0' * 40}'
      : draft['assetAddress']?.toString().toLowerCase() ?? '';
  if (!RegExp(r'^0x[0-9a-f]{40}$').hasMatch(token)) {
    throw const FormatException('Invalid Burst asset address.');
  }
  if (number(1) != BigInt.from(kind) ||
      word(2) != '${'0' * 24}${token.substring(2)}' ||
      (!nft && number(3).toString() != draft['totalAmountBaseUnits']) ||
      number(nft ? 3 : 4) != BigInt.from(draft['maxParticipants'] as int) ||
      number(nft ? 4 : 5) != BigInt.from(draft['startTime'] as int) ||
      number(nft ? 5 : 6) != BigInt.from(draft['endTime'] as int) ||
      number(nft ? 6 : 7) != BigInt.zero ||
      number(nft ? 7 : 8) != BigInt.zero) {
    throw const FormatException(
      'The creation transaction does not match your Burst.',
    );
  }
  final preimage =
      '${wallet.substring(2).toLowerCase().padLeft(64, '0')}${word(0)}${BigInt.from(draft['chainId'] as int).toRadixString(16).padLeft(64, '0')}${factory.substring(2).toLowerCase().padLeft(64, '0')}';
  final campaignId =
      '0x${bytesToHex(keccak256(Uint8List.fromList(hexToBytes(preimage))))}';
  if (campaign['campaignId']?.toString().toLowerCase() != campaignId) {
    throw const FormatException(
      'The campaign identity does not match your wallet.',
    );
  }
  final approvals = transactions
      .where((tx) => tx['operation'] == 'approve')
      .toList();
  final deposits = transactions
      .where((tx) => tx['operation'] == 'push')
      .toList();
  final expectedOrder = kind == 0
      ? 'create'
      : nft
      ? 'approve,create,push'
      : 'approve,create';
  if (transactions.map((tx) => tx['operation']).join(',') != expectedOrder) {
    throw const FormatException('Unexpected Burst transaction order.');
  }
  if (kind == 0) {
    if (approvals.isNotEmpty ||
        deposits.isNotEmpty ||
        transactions.length != 1) {
      throw const FormatException('Unexpected Burst transactions.');
    }
    return;
  }
  if (proxyInitCodeHash == null ||
      !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(proxyInitCodeHash) ||
      approvals.length != 1 ||
      transactions.length != (nft ? 3 : 2) ||
      deposits.length != (nft ? 1 : 0)) {
    throw const FormatException('Burst contract verification is unavailable.');
  }
  final preimage2 =
      'ff${factory.substring(2)}${campaignId.substring(2)}${proxyInitCodeHash.substring(2)}';
  final predicted =
      '0x${bytesToHex(keccak256(Uint8List.fromList(hexToBytes(preimage2)))).substring(24)}';
  final approval = approvals.single;
  final approvalData = approval['calldata']?.toString().toLowerCase() ?? '';
  final selector2 = nft ? 'a22cb465' : '095ea7b3';
  final amount = nft
      ? BigInt.one
      : BigInt.parse(draft['totalAmountBaseUnits'] as String);
  final expected =
      '0x$selector2${predicted.substring(2).padLeft(64, '0')}${amount.toRadixString(16).padLeft(64, '0')}';
  if (approval['toAddress']?.toString().toLowerCase() != token ||
      approvalData != expected ||
      approval['valueBaseUnits'] != '0' ||
      (nft &&
          (deposits.single['toAddress']?.toString().toLowerCase() !=
                  predicted ||
              deposits.single['valueBaseUnits'] != '0'))) {
    throw const FormatException(
      'The asset approval does not match this Burst.',
    );
  }
  if (nft) {
    final allocations = draft['nftAllocations'];
    if (allocations is! List ||
        allocations.length != draft['maxParticipants']) {
      throw const FormatException('Invalid NFT allocations.');
    }
    final inventory = <BigInt, BigInt>{};
    final orderedIds = <BigInt>[];
    for (final entry in allocations) {
      if (entry is! Map) throw const FormatException('Invalid NFT allocation.');
      final id = BigInt.tryParse(entry['tokenId']?.toString() ?? '');
      final amount = BigInt.tryParse(entry['amount']?.toString() ?? '');
      if (id == null ||
          id.isNegative ||
          id.bitLength > 256 ||
          amount == null ||
          amount <= BigInt.zero ||
          amount.bitLength > 256 ||
          (kind == 2 && (amount != BigInt.one || inventory.containsKey(id)))) {
        throw const FormatException('Invalid NFT allocation.');
      }
      orderedIds.add(id);
      inventory[id] = (inventory[id] ?? BigInt.zero) + amount;
      if (inventory[id]!.bitLength > 256) {
        throw const FormatException('Invalid NFT quantity.');
      }
    }
    String hexWord(BigInt value) => value.toRadixString(16).padLeft(64, '0');
    late final String depositData;
    if (kind == 2) {
      depositData =
          '0x9ad88796${hexWord(BigInt.from(32))}${hexWord(BigInt.from(orderedIds.length))}${orderedIds.map(hexWord).join()}';
    } else {
      final ids = inventory.keys.toList()..sort();
      depositData =
          '0xc78a7f37${hexWord(BigInt.from(64))}${hexWord(BigInt.from(96 + ids.length * 32))}${hexWord(BigInt.from(ids.length))}${ids.map(hexWord).join()}${hexWord(BigInt.from(ids.length))}${ids.map((id) => hexWord(inventory[id]!)).join()}';
    }
    if (deposits.single['calldata']?.toString().toLowerCase() != depositData) {
      throw const FormatException(
        'The NFT deposit does not match your selected inventory.',
      );
    }
  }
}
