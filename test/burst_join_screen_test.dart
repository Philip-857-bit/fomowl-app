import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_join_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const wallet = '0x1111111111111111111111111111111111111111';
  testWidgets('guest joins, claims, and sees a confirmed receipt', (
    tester,
  ) async {
    var status = 'active';
    var claimStatus = 'allocated';
    var jobStatus = '';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/proof')) {
        if (status == 'active') return http.Response('{}', 404);
        return http.Response(
          jsonEncode({
            'claimStatus': claimStatus,
            'claimJobStatus': jobStatus,
            'assetKind': 'native',
            'amountBaseUnits': '1250000000000000000',
          }),
          200,
        );
      }
      if (path.endsWith('/claim')) {
        claimStatus = 'claim_queued';
        jobStatus = 'queued';
        return http.Response('{"status":"queued"}', 202);
      }
      final campaign = {
        'id': 'campaign-1',
        'title': 'Community',
        'chainId': 56,
        'status': status,
        'startTime': now - 60,
        'endTime': now + 3600,
        'participantCount': 1,
        'maxParticipants': 2,
        'assetDecimals': 18,
        'assetSymbol': 'BNB',
      };
      if (path.contains('/join/')) {
        return request.method == 'POST'
            ? http.Response(
                jsonEncode({
                  'campaignId': 'campaign-1',
                  'walletAddress': wallet,
                }),
                200,
              )
            : http.Response(
                jsonEncode({'campaign': campaign, 'canJoin': true}),
                200,
              );
      }
      if (path.endsWith('/config')) return http.Response('{}', 200);
      return http.Response(jsonEncode(campaign), 200);
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstJoinScreen(api: api, walletAddress: wallet, chainId: 56),
      ),
    );
    await tester.enterText(find.byType(TextField), 'ABC234');
    await tester.tap(find.text('Join Burst').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm join'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for host to Burst…'), findsOneWidget);
    status = 'claiming';
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Your reward is ready'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Claim reward'), 200);
    await tester.tap(find.text('Claim reward'));
    await tester.pumpAndSettle();
    expect(find.text('Reward processing'), findsOneWidget);
    claimStatus = 'claimed';
    jobStatus = 'confirmed';
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Burst Received!'), findsOneWidget);
    expect(find.text('1.25 BNB'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
  testWidgets('joins with a code and displays current participant progress', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) return http.Response('{}', 404);
      if (request.url.path.contains('/participations/')) {
        return http.Response(
          jsonEncode({
            'id': 'campaign-1',
            'chainId': 56,
            'title': 'Community',
            'participantCount': 2,
            'maxParticipants': 5,
          }),
          200,
        );
      }
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({'campaignId': 'campaign-1', 'walletAddress': wallet}),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'canJoin': false,
          'campaign': {
            'id': 'campaign-1',
            'chainId': 56,
            'title': 'Community',
            'participantCount': 2,
            'maxParticipants': 5,
          },
        }),
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstJoinScreen(api: api, walletAddress: wallet, chainId: 56),
      ),
    );
    await tester.enterText(find.byType(TextField), 'ABC234');
    await tester.tap(find.text('Join Burst').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm join'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for host to Burst…'), findsOneWidget);
    expect(find.text('2 of 5 guests joined'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('requires the right network and explicit confirmation', (
    tester,
  ) async {
    var chainId = 1;
    var joins = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') joins++;
      return http.Response(
        jsonEncode({
          'campaign': {
            'id': 'campaign-1',
            'title': 'Community',
            'chainId': chainId,
          },
        }),
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstJoinScreen(api: api, walletAddress: wallet, chainId: 56),
      ),
    );
    await tester.enterText(find.byType(TextField), 'ABC234');
    await tester.tap(find.text('Join Burst').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Switch to that network'), findsOneWidget);
    expect(joins, 0);
    chainId = 56;
    await tester.tap(find.text('Join Burst').last);
    await tester.pumpAndSettle();
    expect(find.textContaining(wallet), findsWidgets);
    expect(joins, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(joins, 0);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('does not navigate if backend joins a different wallet', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(
          request.method == 'POST'
              ? {
                  'campaignId': 'campaign-1',
                  'walletAddress': '0x2222222222222222222222222222222222222222',
                }
              : {
                  'canJoin': true,
                  'campaign': {
                    'id': 'campaign-1',
                    'title': 'Community',
                    'chainId': 56,
                  },
                },
        ),
        200,
      ),
    );
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstJoinScreen(api: api, walletAddress: wallet, chainId: 56),
      ),
    );
    await tester.enterText(find.byType(TextField), 'ABC234');
    await tester.tap(find.text('Join Burst').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm join'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not match'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('a confirmed claim displays the actual reward receipt', (
    tester,
  ) async {
    final hash = '0x${'ab' * 32}';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) {
        return http.Response(
          jsonEncode({
            'claimStatus': 'claimed',
            'assetKind': 'erc20',
            'amountBaseUnits': '1500000',
            'claimTransactionHash': hash,
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/config')) {
        return http.Response(
          jsonEncode({'explorerUrl': 'https://bscscan.com'}),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'id': 'campaign-1',
          'chainId': 56,
          'title': 'Community',
          'assetSymbol': 'USDC',
          'assetDecimals': 6,
        }),
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Burst Received!'), findsOneWidget);
    expect(find.text('1.5 USDC'), findsOneWidget);
    expect(find.text('View on block explorer'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == 'Transaction: 0xababab…abab',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('an NFT claim displays its token ID and quantity', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) {
        return http.Response(
          '{"claimStatus":"claimed","assetKind":"erc1155","tokenId":"12345678901234567890","tokenAmount":"3"}',
          200,
        );
      }
      return http.Response('{"id":"campaign-1","title":"Community"}', 200);
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 NFT · #12345678901234567890'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('claim remains pending until the backend confirms delivery', (
    tester,
  ) async {
    var claimState = 'allocated';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) {
        return http.Response(
          jsonEncode({
            'claimStatus': claimState,
            'claimJobStatus': claimState == 'allocated' ? null : 'submitted',
            'assetKind': 'native',
            'amountBaseUnits': '1000000000000000000',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/claim')) {
        claimState = 'claim_queued';
        return http.Response('{"status":"queued"}', 202);
      }
      return http.Response(
        jsonEncode({
          'id': 'campaign-1',
          'chainId': 56,
          'title': 'Community',
          'status': 'claiming',
          'startTime': 0,
          'endTime': 4102444800,
          'assetSymbol': 'BNB',
          'assetDecimals': 18,
        }),
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your reward is ready'), findsOneWidget);
    await tester.tap(find.text('Claim reward'));
    await tester.pumpAndSettle();
    expect(find.text('Reward processing'), findsOneWidget);
    expect(find.text('Burst Received!'), findsNothing);
    claimState = 'claimed';
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Burst Received!'), findsOneWidget);
    expect(find.text('1 BNB'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('waits for on-chain activation before offering a claim', (
    tester,
  ) async {
    var status = 'root_pending';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    var startTime = now + 3600;
    var endTime = now + 7200;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) {
        return http.Response('{"claimStatus":"allocated"}', 200);
      }
      return http.Response(
        jsonEncode({
          'id': 'campaign-1',
          'status': status,
          'startTime': startTime,
          'endTime': endTime,
        }),
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting for host to Burst…'), findsOneWidget);
    expect(find.text('Claim reward'), findsNothing);
    status = 'claiming';
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Claims open soon'), findsOneWidget);
    expect(find.text('Claim reward'), findsNothing);
    startTime = now - 1;
    await tester.ensureVisible(find.text('Refresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Your reward is ready'), findsOneWidget);
    expect(find.text('Claim reward'), findsOneWidget);
    startTime = now - 3600;
    endTime = now - 1;
    await tester.ensureVisible(find.text('Refresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Burst ended'), findsOneWidget);
    expect(find.text('Claim reward'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('claim availability uses the backend when device time differs', (
    tester,
  ) async {
    var queued = false;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) {
        return http.Response(
          jsonEncode({
            'claimStatus': queued ? 'claim_queued' : 'allocated',
            'claimJobStatus': queued ? 'queued' : null,
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/claim')) {
        queued = true;
        return http.Response('{"status":"queued"}', 202);
      }
      return http.Response(
        jsonEncode({
          'id': 'campaign-1',
          'status': 'claiming',
          'startTime': now + 3600,
          'endTime': now + 7200,
        }),
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Claims open soon'), findsOneWidget);
    await tester.ensureVisible(find.text('Try claiming'));
    await tester.tap(find.text('Try claiming'));
    await tester.pumpAndSettle();
    expect(queued, isTrue);
    expect(find.text('Reward processing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('a guest can confirm leaving an open Burst', (tester) async {
    var attempts = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        attempts++;
        return http.Response(attempts == 1 ? '{}' : '{"left":true}', 200);
      }
      if (request.url.path.endsWith('/proof')) return http.Response('{}', 404);
      return http.Response('{"id":"campaign-1","status":"active"}', 200);
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BurstWaitingScreen(
                  api: api,
                  campaignId: 'campaign-1',
                  title: 'Community',
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leave Burst'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave Burst'));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Leave Burst'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to confirm that you left this Burst.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Leave Burst'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave Burst'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Leave Burst'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Open'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('automatic refresh keeps claim errors visible', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) {
        return http.Response('{"claimStatus":"allocated"}', 200);
      }
      if (request.url.path.endsWith('/claim')) {
        return http.Response('{"message":"Claim service unavailable."}', 503);
      }
      return http.Response(
        '{"id":"campaign-1","status":"claiming","startTime":0,"endTime":4102444800}',
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Claim reward'));
    await tester.tap(find.text('Claim reward'));
    await tester.pumpAndSettle();
    expect(find.text('Claim service unavailable.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Claim service unavailable.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('a failed relayer claim is not shown as ready to claim', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) {
        return http.Response(
          '{"claimStatus":"allocated","claimJobStatus":"failed"}',
          200,
        );
      }
      return http.Response(
        '{"id":"campaign-1","title":"Community","status":"claiming","startTime":0,"endTime":4102444800}',
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reward needs attention'), findsOneWidget);
    expect(find.text('Claim reward'), findsNothing);
    expect(find.text('Burst Received!'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('a cancelled campaign no longer offers a claim', (tester) async {
    final client = MockClient(
      (request) async => request.url.path.endsWith('/proof')
          ? http.Response('{"claimStatus":"allocated"}', 200)
          : http.Response('{"id":"campaign-1","status":"cancelled"}', 200),
    );
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Burst cancelled'), findsOneWidget);
    expect(find.text('Claim reward'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('view in wallet returns to the wallet route', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/proof')) {
        return http.Response(
          jsonEncode({
            'claimStatus': 'claimed',
            'assetKind': 'native',
            'amountBaseUnits': '1',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/config')) {
        return http.Response('{}', 200);
      }
      return http.Response(
        jsonEncode({
          'id': 'campaign-1',
          'chainId': 56,
          'assetSymbol': 'BNB',
          'assetDecimals': 18,
        }),
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/shell',
        routes: {
          '/shell': (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/receipt'),
              child: const Text('Open receipt'),
            ),
          ),
          '/receipt': (_) => BurstWaitingScreen(
            api: api,
            campaignId: 'campaign-1',
            title: 'Community',
          ),
        },
      ),
    );
    await tester.tap(find.text('Open receipt'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('View in Wallet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('View in Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Open receipt'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('a claimed participant can send a thank-you message', (
    tester,
  ) async {
    String? sent;
    final client = MockClient((request) async {
      if (request.method == 'PUT') {
        sent = (jsonDecode(request.body) as Map)['message'] as String;
        return http.Response('{"saved":true}', 200);
      }
      if (request.url.path.endsWith('/proof')) {
        return http.Response(
          '{"claimStatus":"claimed","assetKind":"native","amountBaseUnits":"1"}',
          200,
        );
      }
      if (request.url.path.endsWith('/config')) return http.Response('{}', 200);
      return http.Response(
        '{"id":"campaign-1","chainId":56,"assetSymbol":"BNB","assetDecimals":18}',
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstWaitingScreen(
          api: api,
          campaignId: 'campaign-1',
          title: 'Community',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Send message'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'Thank you!');
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(sent, 'Thank you!');
    expect(find.text('Message sent to the host.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
}
