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
}
