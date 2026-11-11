import 'dart:typed_data';

import 'package:web3dart/crypto.dart';

const testBurstWallet = '0x1111111111111111111111111111111111111111';
const testBurstFactory = '0x2222222222222222222222222222222222222222';
const testBurstInitHash =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> burstFixture(Map<String, dynamic> draft) {
  final kind = {
    'native': 0,
    'erc20': 1,
    'erc721': 2,
    'erc1155': 3,
  }[draft['assetKind']]!;
  final nft = kind >= 2;
  String uintWord(dynamic number) =>
      BigInt.parse(number.toString()).toRadixString(16).padLeft(64, '0');
  final salt = '1'.padLeft(64, '0');
  final asset = kind == 0
      ? '0' * 40
      : (draft['assetAddress'] as String).substring(2).toLowerCase();
  final nowSeconds = 1731234567;
  final startTime = draft['startTime'] ?? nowSeconds;
  final endTime = draft['endTime'] ?? (nowSeconds + 7 * 86400);
  final words = [
    salt,
    uintWord(kind),
    asset.padLeft(64, '0'),
    if (!nft) uintWord(draft['totalAmountBaseUnits']),
    uintWord(draft['maxParticipants']),
    uintWord(startTime),
    uintWord(endTime),
    uintWord(0),
    uintWord(0),
  ];
  final idInput =
      '${testBurstWallet.substring(2).padLeft(64, '0')}$salt${uintWord(draft['chainId'])}${testBurstFactory.substring(2).padLeft(64, '0')}';
  final id =
      '0x${bytesToHex(keccak256(Uint8List.fromList(hexToBytes(idInput))))}';
  final create2 =
      'ff${testBurstFactory.substring(2)}${id.substring(2)}${testBurstInitHash.substring(2)}';
  final predicted =
      '0x${bytesToHex(keccak256(Uint8List.fromList(hexToBytes(create2)))).substring(24)}';
  final expiry = DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 5))
      .toIso8601String();
  Map<String, dynamic> tx(
    String operation,
    String to,
    String data,
    String value,
  ) => {
    'reference': '$operation-ref',
    'operation': operation,
    'chainId': draft['chainId'],
    'toAddress': to,
    'valueBaseUnits': value,
    'calldata': data,
    'expiresAt': expiry,
  };
  final transactions = <Map<String, dynamic>>[];
  if (kind != 0) {
    transactions.add(
      tx(
        'approve',
        '0x$asset',
        '0x${nft ? 'a22cb465' : '095ea7b3'}${predicted.substring(2).padLeft(64, '0')}${uintWord(nft ? 1 : draft['totalAmountBaseUnits'])}',
        '0',
      ),
    );
  }
  transactions.add(
    tx(
      'create',
      testBurstFactory,
      '0x${nft ? 'fc50ee32' : 'a4be8afd'}${words.join()}',
      kind == 0 ? draft['totalAmountBaseUnits'] as String : '0',
    ),
  );
  if (nft) {
    final entries = (draft['nftAllocations'] as List).cast<Map>();
    String w(dynamic value) => uintWord(value);
    final ids = entries
        .map((e) => BigInt.parse(e['tokenId'] as String))
        .toList();
    final counts = <BigInt, BigInt>{};
    for (final entry in entries) {
      final id = BigInt.parse(entry['tokenId'] as String);
      counts[id] =
          (counts[id] ?? BigInt.zero) + BigInt.parse(entry['amount'] as String);
    }
    final sorted = counts.keys.toList()..sort();
    final data = kind == 2
        ? '0x9ad88796${w(32)}${w(ids.length)}${ids.map(w).join()}'
        : '0xc78a7f37${w(64)}${w(96 + sorted.length * 32)}${w(sorted.length)}${sorted.map(w).join()}${w(sorted.length)}${sorted.map((id) => w(counts[id])).join()}';
    transactions.add(tx('push', predicted, data, '0'));
  }
  return {'campaignId': id, 'transactions': transactions};
}
