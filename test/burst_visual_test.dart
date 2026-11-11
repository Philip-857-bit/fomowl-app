import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_home_components.dart';
import 'package:fomowl_wallet/features/burst/burst_join_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_review_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_transaction_executor.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class VisualJournal implements BurstSubmissionJournal {
  @override
  Future<void> clear(String reference) async {}
  @override
  Future<Map<String, String>?> read(String reference) async => null;
  @override
  Future<void> write(String reference, Map<String, String> entry) async {}
}

void main() {
  testWidgets('home campaign card shows actual allocation and opens controls', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BurstHomeCampaignCard(
              campaign: const {
                'title': 'Community',
                'status': 'active',
                'assetKind': 'erc20',
                'assetDecimals': 6,
                'assetSymbol': 'USDC',
                'amountPerParticipantBaseUnits': '2500000',
                'participantCount': 2,
                'maxParticipants': 5,
              },
              onTap: () => opened = true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('2.5 USDC each'), findsOneWidget);
    expect(find.text('2 / 5 guests'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.4,
    );
    await tester.tap(find.text('Community'));
    expect(opened, isTrue);
  });

  testWidgets('Burst home artwork and actions fit a phone viewport', (
    tester,
  ) async {
    if (Platform.isWindows && File('C:/Windows/Fonts/arial.ttf').existsSync()) {
      await tester.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
        final font = FontLoader('BurstHomeVisualFont')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await font.load();
      });
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    var actions = 0;
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'BurstHomeVisualFont'),
          home: Scaffold(
            backgroundColor: const Color(0xff0a0a0a),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const BurstHomeHero(),
                Row(
                  children: [
                    Expanded(
                      child: BurstHomeAction(
                        iconAsset: 'assets/burst/create_icon.png',
                        title: 'Start Burst',
                        subtitle: 'Start a new Burst',
                        onTap: () => actions++,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BurstHomeAction(
                        iconAsset: 'assets/burst/join_icon.png',
                        title: 'Join Burst',
                        subtitle: 'Enter code to join',
                        onTap: () => actions++,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future.wait(
        [
          'assets/burst/home_illustration.png',
          'assets/burst/create_icon.png',
          'assets/burst/join_icon.png',
        ].map((path) => precacheImage(AssetImage(path), key.currentContext!)),
      );
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNWidgets(3));
    await tester.tap(find.text('Start Burst'));
    await tester.tap(find.text('Join Burst'));
    expect(actions, 2);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${Directory.systemTemp.path}/owllet_burst_home.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('waiting screen fits a phone viewport', (tester) async {
    if (Platform.isWindows &&
        File('C:/Windows/Fonts/arial.ttf').existsSync() &&
        File(
          'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ).existsSync()) {
      await tester.runAsync(() async {
        final textFont = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
        final iconFont = await File(
          'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ).readAsBytes();
        final textLoader = FontLoader('BurstVisualFont')
          ..addFont(Future.value(ByteData.sublistView(textFont)));
        final iconLoader = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(iconFont)));
        await textLoader.load();
        await iconLoader.load();
      });
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) return http.Response('{}', 404);
      return http.Response(
        jsonEncode({
          'id': 'campaign',
          'title': 'Community Airdrop',
          'participantCount': 24,
          'maxParticipants': 36,
        }),
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: transport,
      authorize: (request) async =>
          http.Response.fromStream(await transport.send(request)),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'BurstVisualFont'),
          home: BurstWaitingScreen(
            api: api,
            campaignId: 'campaign',
            title: 'Community Airdrop',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting for host to Burst…'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${Directory.systemTemp.path}/owllet_burst_waiting.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    transport.close();
  });

  testWidgets('review screen fits a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = MockClient((_) async => http.Response('{}', 200));
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: transport,
      authorize: (request) async =>
          http.Response.fromStream(await transport.send(request)),
    );
    final executor = BurstTransactionExecutor(
      api: api,
      journal: VisualJournal(),
      wallet: '0x1111111111111111111111111111111111111111',
      chainId: 56,
      isCurrent: () async => true,
      approve: (_) async => false,
      broadcast: (_) async => '',
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'BurstVisualFont'),
          home: BurstReviewScreen(
            executor: executor,
            nativeSymbol: 'BNB',
            chainName: 'BNB Smart Chain',
            prepared: {
              'campaign': {
                'id': 'campaign',
                'assetKind': 'erc20',
                'assetSymbol': 'FOWL',
                'assetDecimals': 18,
                'totalAmountBaseUnits': '250000000000000000000',
                'chainId': 56,
                'maxParticipants': 20,
                'platformFeeBaseUnits': '10000000000000000',
                'gasSponsorshipFeeBaseUnits': '20000000000000000',
              },
              'joinCode': 'ABCDE-FGHIJ',
              'transactions': [],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total. Burst Amount + Fees'), findsOneWidget);
    expect(find.text('Upfront native cost'), findsNothing);
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${Directory.systemTemp.path}/owllet_burst_review.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    transport.close();
  });
}
