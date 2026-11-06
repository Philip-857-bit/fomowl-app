import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_create_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_draft_store.dart';
import 'package:fomowl_wallet/features/burst/burst_history_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_join_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_nft_gallery_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_review_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_transaction_executor.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/nft_service.dart';
import 'package:fomowl_wallet/theme/theme_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'burst_draft_store_test.dart' show MemoryStorage;
import 'helpers/test_fonts.dart';

class _DesignChain extends BlockchainService {
  @override
  List<Token> get tokens => [activeNativeToken];
}

class _ClassicTheme extends ChangeNotifier implements ThemeController {
  @override
  bool get isClassic => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Journal implements BurstSubmissionJournal {
  @override
  Future<void> clear(String reference) async {}
  @override
  Future<Map<String, String>?> read(String reference) async => null;
  @override
  Future<void> write(String reference, Map<String, String> entry) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    final font = File('C:/Windows/Fonts/arial.ttf');
    final bytes = Platform.isWindows && font.existsSync()
        ? ByteData.sublistView(await font.readAsBytes())
        : null;
    await installTestFonts(fontBytes: bytes);
  });
  testWidgets('render Burst screens at the Figma phone width', (tester) async {
    if (Platform.isWindows && File('C:/Windows/Fonts/arial.ttf').existsSync()) {
      await tester.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
        final textFont = FontLoader('BurstDesignReview')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await textFont.load();
        final icons = File(
          'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        );
        if (icons.existsSync()) {
          final iconFont = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(ByteData.sublistView(await icons.readAsBytes())),
            );
          await iconFont.load();
        }
      });
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chain = _DesignChain();
    const wallet = '0x1111111111111111111111111111111111111111';
    final transaction = {
      'reference': 'confirmed',
      'operation': 'create',
      'chainId': 56,
      'toAddress': '0x2222222222222222222222222222222222222222',
      'valueBaseUnits': '0',
      'calldata': '0xa4be8afd',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    };
    final transport = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/execution')) {
        return http.Response(
          jsonEncode({
            'status': 'confirmed',
            'walletAddress': wallet,
            'campaignId': 'one',
            'transaction': transaction,
            'transactionHash': '0x${'ab' * 32}',
          }),
          200,
        );
      }
      if (path.endsWith('/proof')) {
        return http.Response(
          jsonEncode({
            'claimStatus': 'claimed',
            'assetKind': 'native',
            'amountBaseUnits': '1000000000000000000',
            'claimTransactionHash': '0x${'ab' * 32}',
          }),
          200,
        );
      }
      if (path.endsWith('/config')) {
        return http.Response(
          '{"chainName":"BNB Smart Chain","explorerUrl":"https://bscscan.com"}',
          200,
        );
      }
      if (path.contains('/participations/')) {
        return http.Response(
          jsonEncode({
            'id': 'one',
            'chainId': 56,
            'assetDecimals': 18,
            'assetSymbol': 'BNB',
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: transport,
      authorize: (request) async =>
          http.Response.fromStream(await transport.send(request)),
    );
    final executor = BurstTransactionExecutor(
      api: api,
      journal: _Journal(),
      wallet: wallet,
      chainId: 56,
      isCurrent: () async => true,
      approve: (_) async => true,
      broadcast: (_) async => '0x${'ab' * 32}',
    );
    const nft = NftAsset(
      name: 'Owllet #1',
      collection: 'Owllet',
      description: '',
      count: 1,
      chainName: 'BNB',
      chainId: 56,
      imageUrl: '',
      contractAddress: wallet,
      tokenId: '1',
      isProjectNft: false,
    );
    final screens = <String, Widget>{
      'create': BurstCreateScreen(
        api: api,
        wallet: wallet,
        profileId: 'profile',
        store: BurstDraftStore(storage: MemoryStorage()),
        config: const {
          'supportedAssetKinds': ['native'],
          'maxParticipants': 500,
          'gaslessClaimsEnabled': true,
        },
        onPrepared: (_) async {},
      ),
      'gallery': const BurstNftGalleryScreen(inventory: [nft], selected: []),
      'history': BurstHistoryScreen(
        api: api,
        initialCampaigns: const [
          {
            'id': 'one',
            'title': 'Community Airdrop',
            'status': 'active',
            'participantCount': 23,
            'maxParticipants': 50,
          },
        ],
        openCampaign: (_) async {},
      ),
      'join': BurstJoinScreen(api: api, walletAddress: wallet, chainId: 56),
      'success': BurstReviewScreen(
        executor: executor,
        nativeSymbol: 'BNB',
        onCompleted: () async {},
        prepared: {
          'campaign': {
            'id': 'one',
            'assetKind': 'native',
            'assetSymbol': 'BNB',
          },
          'joinCode': 'ABCDE-FGHIJ',
          'transactions': [transaction],
        },
      ),
      'receipt': BurstWaitingScreen(
        api: api,
        campaignId: 'one',
        title: 'Community Airdrop',
      ),
    };
    // Re-render the first screen after the shared image has warmed up.
    for (final entry in [...screens.entries, screens.entries.first]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: chain),
            ChangeNotifierProvider<ThemeController>(
              create: (_) => _ClassicTheme(),
            ),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                brightness: Brightness.dark,
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xffea2a33),
                  secondary: Color(0xffea2a33),
                ),
                fontFamily: 'BurstDesignReview',
              ),
              home: entry.value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (entry.key == 'success') {
        await tester.scrollUntilVisible(
          find.text('Create Burst'),
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text('Create Burst'));
        await tester.tap(find.text('Create Burst'));
        await tester.pumpAndSettle();
        expect(find.text('Burst Created!'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Burst Created!')).dy,
          lessThan(844),
        );
      }
      if (entry.key == 'receipt') {
        expect(find.text('Burst Received!'), findsOneWidget);
      }
      expect(tester.takeException(), isNull, reason: entry.key);
      if (entry.key == 'create') {
        final selector = tester.widget<SegmentedButton<bool>>(
          find.byType(SegmentedButton<bool>),
        );
        expect(
          selector.style!.backgroundColor!.resolve({WidgetState.selected}),
          Colors.transparent,
        );
        expect(find.text('Token Burst'), findsOneWidget);
      }
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${Directory.systemTemp.path}/owllet_burst_${entry.key}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
    }
    transport.close();
    chain.dispose();
  });
}
