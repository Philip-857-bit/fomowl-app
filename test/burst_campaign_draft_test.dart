import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_campaign_draft.dart';
import 'package:fomowl_wallet/services/nft_service.dart';

void main() {
  const contract = '0x1111111111111111111111111111111111111111';
  NftAsset nft({required String id, int count = 1, String type = 'ERC721'}) =>
      NftAsset(
        name: 'NFT',
        collection: 'Collection',
        description: '',
        count: count,
        chainName: 'BNB',
        chainId: 56,
        imageUrl: '',
        contractAddress: contract,
        tokenId: id,
        tokenType: type,
        isProjectNft: false,
        rarity: '',
      );
  BurstCampaignDraft draft({
    String kind = 'native',
    String amount = '1',
    int participants = 2,
    List<BurstNftAllocation> nfts = const [],
    bool randomizeNfts = false,
  }) => BurstCampaignDraft(
    chainId: 56,
    title: 'Rewards',
    description: '',
    kind: kind,
    symbol: 'TOKEN',
    decimals: kind.startsWith('erc7') || kind == 'erc1155' ? 0 : 18,
    participants: participants,
    amount: amount,
    assetAddress: kind == 'native' ? null : contract,
    nfts: nfts,
    randomizeNfts: randomizeNfts,
  );
  Map<String, dynamic> request(BurstCampaignDraft value) => value.toRequest(
    idempotencyKey: 'request-123',
    maxParticipants: 500,
    now: DateTime.utc(2026, 1, 1),
  );

  test(
    'uses exact units and rejects amounts that cannot be evenly allocated',
    () {
      final result = request(draft(amount: '0.000000000000000002'));
      expect(result['totalAmountBaseUnits'], '2');
      expect(result['amountPerParticipantBaseUnits'], '1');
      expect(burstPerParticipant('0.000000000000000002', 18, 2), BigInt.one);
      expect(burstPerParticipant('0.000000000000000003', 18, 2), isNull);
      expect(burstPerParticipant('1', 18, 0), isNull);
      expect(
        () => request(draft(amount: '0.000000000000000003')),
        throwsFormatException,
      );
      expect(
        () => burstBaseUnits('0.0000000000000000001', 18),
        throwsFormatException,
      );
    },
  );

  test('checks ERC721 uniqueness and ERC1155 available quantities', () {
    final a = nft(id: '1');
    expect(
      () => request(
        draft(
          kind: 'erc721',
          nfts: [
            BurstNftAllocation(asset: a, quantity: 1),
            BurstNftAllocation(asset: a, quantity: 1),
          ],
        ),
      ),
      throwsFormatException,
    );
    final b = nft(id: '4', count: 3, type: 'ERC1155');
    final valid = request(
      draft(
        kind: 'erc1155',
        nfts: [
          BurstNftAllocation(asset: b, quantity: 1),
          BurstNftAllocation(asset: b, quantity: 2),
        ],
      ),
    );
    expect((valid['nftAllocations'] as List).length, 2);
    expect(
      () => request(
        draft(
          kind: 'erc1155',
          nfts: [
            BurstNftAllocation(asset: b, quantity: 2),
            BurstNftAllocation(asset: b, quantity: 2),
          ],
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'random assignment shuffles selected allocations without changing them',
    () {
      final items = List.generate(
        5,
        (index) => BurstNftAllocation(asset: nft(id: '$index'), quantity: 1),
      );
      final value = draft(
        kind: 'erc721',
        participants: 5,
        nfts: items,
        randomizeNfts: true,
      );
      final result = value.toRequest(
        idempotencyKey: 'request-123',
        maxParticipants: 500,
        now: DateTime.utc(2026),
        random: Random(7),
      );
      final shuffled = (result['nftAllocations'] as List)
          .map((item) => item['tokenId'] as String)
          .toList();
      expect(shuffled, isNot(['0', '1', '2', '3', '4']));
      expect(shuffled.toSet(), {'0', '1', '2', '3', '4'});
      expect(items.map((item) => item.asset.tokenId).toList(), [
        '0',
        '1',
        '2',
        '3',
        '4',
      ]);
    },
  );
}
