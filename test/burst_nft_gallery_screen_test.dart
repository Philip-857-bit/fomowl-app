import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_campaign_draft.dart';
import 'package:fomowl_wallet/features/burst/burst_nft_gallery_screen.dart';
import 'package:fomowl_wallet/services/nft_service.dart';

void main() {
  testWidgets('ERC-1155 selections respect already allocated quantities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const asset = NftAsset(
      name: 'Copies',
      collection: 'Collection',
      description: '',
      count: 3,
      chainName: 'BNB',
      chainId: 56,
      imageUrl: '',
      contractAddress: '0x1111111111111111111111111111111111111111',
      tokenId: '4',
      tokenType: 'ERC1155',
      isProjectNft: false,
    );
    BurstNftSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<BurstNftSelection>(
                context,
                MaterialPageRoute(
                  builder: (_) => const BurstNftGalleryScreen(
                    inventory: [asset],
                    selected: [BurstNftAllocation(asset: asset, quantity: 2)],
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copies'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove NFT allocation'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Copies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copies'));
    await tester.pumpAndSettle();
    expect(
      find.text('All available copies are already selected.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm selection'));
    await tester.pumpAndSettle();
    expect(result!.allocations.map((item) => item.quantity), [2, 1]);
  });

  testWidgets('gallery selects inventory and returns allocations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const first = NftAsset(
      name: 'First',
      collection: 'Collection',
      description: '',
      count: 1,
      chainName: 'BNB',
      chainId: 56,
      imageUrl: '',
      contractAddress: '0x1111111111111111111111111111111111111111',
      tokenId: '1',
      isProjectNft: false,
    );
    const second = NftAsset(
      name: 'Other collection',
      collection: 'Other',
      description: '',
      count: 1,
      chainName: 'BNB',
      chainId: 56,
      imageUrl: '',
      contractAddress: '0x2222222222222222222222222222222222222222',
      tokenId: '2',
      isProjectNft: false,
    );
    BurstNftSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<BurstNftSelection>(
                context,
                MaterialPageRoute(
                  builder: (_) => const BurstNftGalleryScreen(
                    inventory: [first, second],
                    selected: [],
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Other collection'));
    await tester.pumpAndSettle();
    expect(find.text('Choose NFTs from the same collection.'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm selection'));
    await tester.pumpAndSettle();
    expect(result!.allocations, hasLength(1));
    expect(result!.allocations.single.asset.tokenId, '1');
    expect(result!.randomize, isTrue);
  });
}
