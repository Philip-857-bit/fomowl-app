import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/blockchain/blockchain_catalog.dart';
import 'package:fomowl_wallet/widgets/chain_logo_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Milestone 3 Adversarial Verification: Asset Bundle & Image Decoding',
    () {
      test(
        'rootBundle loads assetchain.png as packaged by pubspec.yaml',
        () async {
          final ByteData byteData = await rootBundle.load(
            'assets/images/chains/assetchain.png',
          );
          expect(byteData.lengthInBytes, greaterThan(0));
          expect(byteData.lengthInBytes, equals(35134));

          final Uint8List bytes = byteData.buffer.asUint8List();
          // Verify PNG magic bytes: \x89 P N G \r \n \x1a \n
          expect(
            bytes.sublist(0, 8),
            equals(<int>[137, 80, 78, 71, 13, 10, 26, 10]),
          );
        },
      );

      test(
        'ui.instantiateImageCodec decodes assetchain.png to 512x512 RGBA',
        () async {
          final ByteData byteData = await rootBundle.load(
            'assets/images/chains/assetchain.png',
          );
          final Uint8List bytes = byteData.buffer.asUint8List();

          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image image = frameInfo.image;

          expect(image.width, equals(512));
          expect(image.height, equals(512));

          // Obtain raw RGBA pixels to verify uncompressed rasterization
          final ByteData? rawRgba = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(rawRgba, isNotNull);
          // 512 * 512 * 4 bytes per pixel = 1,048,576 bytes
          expect(rawRgba!.lengthInBytes, equals(512 * 512 * 4));

          // Verify the presence of alpha transparency in corners (pixel (0,0))
          final int cornerR = rawRgba.getUint8(0);
          final int cornerG = rawRgba.getUint8(1);
          final int cornerB = rawRgba.getUint8(2);
          final int cornerA = rawRgba.getUint8(3);
          expect(
            cornerA,
            equals(0),
            reason: 'Corner pixel must be fully transparent',
          );
          expect(cornerR, equals(0));
          expect(cornerG, equals(0));
          expect(cornerB, equals(0));

          // Verify center region contains non-transparent symbol pixels
          // Center coordinate (256, 256) -> offset (256 * 512 + 256) * 4
          final int centerOffset = (256 * 512 + 256) * 4;
          final int centerA = rawRgba.getUint8(centerOffset + 3);
          expect(
            centerA,
            equals(255),
            reason: 'Center pixel must be fully opaque',
          );
        },
      );
    },
  );

  group(
    'Milestone 3 Adversarial Verification: BlockchainCatalog localChainLogoAsset',
    () {
      test('resolves chain 42420 to assets/images/chains/assetchain.png', () {
        final asset = BlockchainCatalog.localChainLogoAsset(42420);
        expect(asset, equals('assets/images/chains/assetchain.png'));
      });

      test('returns null for standard L1 chains that use remote URLs', () {
        expect(BlockchainCatalog.localChainLogoAsset(1), isNull); // Ethereum
        expect(BlockchainCatalog.localChainLogoAsset(56), isNull); // BSC
        expect(BlockchainCatalog.localChainLogoAsset(137), isNull); // Polygon
        expect(BlockchainCatalog.localChainLogoAsset(8453), isNull); // Base
      });

      test(
        'returns null for retired, negative, and extreme boundary chain IDs',
        () {
          expect(BlockchainCatalog.localChainLogoAsset(0), isNull);
          expect(BlockchainCatalog.localChainLogoAsset(-1), isNull);
          expect(BlockchainCatalog.localChainLogoAsset(-42420), isNull);
          expect(
            BlockchainCatalog.localChainLogoAsset(8217),
            isNull,
          ); // Retired Kaia
          expect(
            BlockchainCatalog.localChainLogoAsset(-9223372036854775808),
            isNull,
          ); // Int64 min
          expect(
            BlockchainCatalog.localChainLogoAsset(9223372036854775807),
            isNull,
          ); // Int64 max
        },
      );

      test(
        'fuzzing stress test: 2000 arbitrary pseudo-random chain IDs safely evaluate',
        () {
          final knownBundledIds = <int>{
            130,
            143,
            146,
            480,
            999,
            2741,
            4663,
            5000,
            5042,
            9745,
            33139,
            34443,
            57073,
            59144,
            80094,
            81457,
            534352,
            1135,
            42220,
            42420,
          };

          final rng = Random(42420);
          for (int i = 0; i < 2000; i++) {
            final randomId = rng.nextInt(2000000) - 1000000;
            final result = BlockchainCatalog.localChainLogoAsset(randomId);
            if (knownBundledIds.contains(randomId)) {
              expect(result, isNotNull);
            } else {
              expect(result, isNull);
            }
          }
        },
      );
    },
  );

  group(
    'Milestone 3 Adversarial Verification: BlockchainCatalog findChain & Metadata',
    () {
      test('findChain(42420) returns verified Asset Chain EVM metadata', () {
        final chain = BlockchainCatalog.findChain(42420);
        expect(chain, isNotNull);
        expect(chain!.chainId, equals(42420));
        expect(chain.name, equals('Asset Chain'));
        expect(chain.symbol, equals('RWA'));
        expect(
          chain.logoUrl,
          equals(
            'https://ipfs.io/ipfs/QmXc4bxuyWvQFqjuunXmvZZs1AwGChyY7sGYK6tgCkp3nJ',
          ),
        );
        expect(chain.explorerUrl, equals('https://scan.assetchain.org'));
        expect(chain.rpcUrl, contains('/42420/rpc'));
      });

      test(
        'findChain with invalid/unregistered chain IDs safely returns null without throwing',
        () {
          expect(BlockchainCatalog.findChain(0), isNull);
          expect(BlockchainCatalog.findChain(-1), isNull);
          expect(BlockchainCatalog.findChain(99999999), isNull);
          expect(BlockchainCatalog.findChain(8217), isNull);
        },
      );
    },
  );

  group(
    'Milestone 3 Adversarial Verification: ChainLogoImage Widget Integration',
    () {
      testWidgets('renders Image.asset for chain 42420', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ChainLogoImage(
                chainId: 42420,
                logoUrl:
                    'https://scan.assetchain.org/assets/configs/network_icon.png',
                width: 48,
                height: 48,
                fallback: Text('FALLBACK'),
              ),
            ),
          ),
        );

        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);

        final Image imageWidget = tester.widget<Image>(imageFinder);
        expect(imageWidget.image, isA<AssetImage>());
        final AssetImage assetImage = imageWidget.image as AssetImage;
        expect(
          assetImage.assetName,
          equals('assets/images/chains/assetchain.png'),
        );
        expect(imageWidget.width, equals(48));
        expect(imageWidget.height, equals(48));
      });

      testWidgets(
        'renders fallback widget when chainId is invalid and logoUrl is empty',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: ChainLogoImage(
                  chainId: -1,
                  logoUrl: '',
                  width: 48,
                  height: 48,
                  fallback: Text('FALLBACK_TRIGGERED'),
                ),
              ),
            ),
          );

          expect(find.text('FALLBACK_TRIGGERED'), findsOneWidget);
        },
      );
    },
  );
}
