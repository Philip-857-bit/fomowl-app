import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/widgets/chain_logo_image.dart';
import 'package:fomowl_wallet/widgets/token_icon.dart';

void main() {
  testWidgets('ChainLogoImage resolves assetchain.png for chainId 42420', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChainLogoImage(
            chainId: 42420,
            logoUrl:
                'https://scan.assetchain.org/assets/configs/network_icon.png',
            width: 32,
            height: 32,
            fallback: SizedBox.shrink(),
          ),
        ),
      ),
    );

    // Verify Image widget is built with AssetImage pointing to assetchain.png
    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.image, isA<AssetImage>());
    final assetImage = imageWidget.image as AssetImage;
    expect(assetImage.assetName, 'assets/images/chains/assetchain.png');
  });

  testWidgets(
    'TokenIcon with chainId 42420 renders chain badge or native icon',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TokenIcon(tokenSymbol: 'RWA', chainId: 42420)),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
