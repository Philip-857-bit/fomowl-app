import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/nft_detail_sheet.dart';
import 'package:fomowl_wallet/services/nft_service.dart';

void main() {
  Widget buildTestApp(NftAsset nft) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: NftDetailSheet(nft: nft)),
    );
  }

  testWidgets('renders core NFT details', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const NftAsset(
          name: 'Genesis Owl',
          collection: 'FOMOwl Genesis',
          description: 'Rare founding NFT.',
          count: 2,
          chainName: 'BNB Smart Chain',
          imageUrl: '',
          contractAddress: '0x1234567890abcdef1234567890abcdef12345678',
          tokenId: '42',
          isProjectNft: true,
          rarity: 'Legendary',
          rarityRank: 7,
        ),
      ),
    );

    expect(find.text('Genesis Owl'), findsOneWidget);
    expect(find.text('FOMOwl Genesis'), findsOneWidget);
    expect(find.text('BNB Smart Chain'), findsAtLeastNWidgets(1));
    expect(find.text('#42'), findsOneWidget);
    expect(find.text('Rare founding NFT.'), findsOneWidget);
    expect(find.text('Legendary · Rank #7'), findsOneWidget);
    expect(
      find.text('0x1234567890abcdef1234567890abcdef12345678'),
      findsOneWidget,
    );
  });

  testWidgets('hides optional sections when metadata is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        const NftAsset(
          name: 'Mystery NFT',
          collection: '',
          description: '',
          count: 1,
          chainName: 'Ethereum',
          imageUrl: '',
          contractAddress: '',
          tokenId: '',
          isProjectNft: false,
        ),
      ),
    );

    expect(find.text('Mystery NFT'), findsOneWidget);
    expect(find.text('Ethereum'), findsAtLeastNWidgets(1));
    expect(find.text('Contract Address'), findsNothing);
    expect(find.textContaining('#'), findsNothing);
  });
}
