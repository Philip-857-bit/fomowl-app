import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/nft_service.dart';

void main() {
  group('NftService.resolveTokenId', () {
    test('reads Alchemy v3 top-level tokenId', () {
      final service = NftService();

      expect(
        service.resolveTokenId({'tokenId': '22125'}, const {}, 'Nexus Key'),
        '22125',
      );
    });

    test('falls back to legacy id.tokenId', () {
      final service = NftService();

      expect(
        service.resolveTokenId(const {}, {'tokenId': '0x566d'}, 'Nexus Key'),
        '22125',
      );
    });

    test('falls back to trailing token id in NFT name', () {
      final service = NftService();

      expect(
        service.resolveTokenId(const {}, const {}, 'Nexus Key #22125'),
        '22125',
      );
    });
  });

  group('NftService.resolveRarity', () {
    test('reads rarity from Alchemy raw metadata attributes', () {
      final service = NftService();
      final nft = <String, dynamic>{
        'raw': {
          'metadata': {
            'attributes': [
              {'trait_type': 'Background', 'value': 'Red'},
              {'trait_type': 'Rarity', 'value': 'Legendary'},
            ],
          },
        },
      };

      expect(service.resolveRarity(nft), 'Legendary');
    });

    test('reads structured rarity and rank', () {
      final service = NftService();
      final nft = <String, dynamic>{
        'rarity': {'tier': 'Epic', 'rank': 12},
      };

      expect(service.resolveRarity(nft), 'Epic');
      expect(service.resolveRarityRank(nft), 12);
    });

    test('does not guess rarity from unrelated traits', () {
      final service = NftService();
      final nft = <String, dynamic>{
        'metadata': {
          'attributes': [
            {'trait_type': 'Background', 'value': 'Rare Red'},
          ],
        },
      };

      expect(service.resolveRarity(nft), isEmpty);
      expect(service.resolveRarityRank(nft), isNull);
    });
  });

  test('groups assets by contract even when metadata names differ', () {
    NftAsset asset(String name) => NftAsset(
      name: name,
      collection: name,
      description: '',
      count: 1,
      chainName: 'Base',
      chainId: 8453,
      imageUrl: '',
      contractAddress: '0xABC',
      tokenId: name,
      isProjectNft: true,
    );

    final groups = groupNftsByCollection([
      asset('FOMOwl'),
      asset('FOMOwl NFT'),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.totalCount, 2);
  });
}
