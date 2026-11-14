import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_campaign_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_transaction_executor.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Journal implements BurstSubmissionJournal {
  final entries = <String, Map<String, String>>{};
  @override
  Future<void> clear(String reference) async => entries.remove(reference);
  @override
  Future<Map<String, String>?> read(String reference) async =>
      entries[reference];
  @override
  Future<void> write(String reference, Map<String, String> entry) async {
    entries[reference] = entry;
  }
}

void main() {
  const wallet = '0x1111111111111111111111111111111111111111';
  const destination = '0x2222222222222222222222222222222222222222';
  testWidgets('another wallet or network can view but cannot manage a Burst', (
    tester,
  ) async {
    for (final mismatch in ['wallet', 'network']) {
      var writes = 0;
      final client = MockClient((request) async {
        if (request.method != 'GET') writes++;
        return http.Response(
          jsonEncode({
            'id': 'one',
            'title': 'Community Burst',
            'status': 'active',
            'hostWalletAddress': mismatch == 'wallet' ? destination : wallet,
            'chainId': mismatch == 'network' ? 1 : 56,
            'campaignAddress': destination,
            'participantCount': 1,
            'maxParticipants': 2,
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
      final executor = BurstTransactionExecutor(
        api: api,
        journal: Journal(),
        wallet: wallet,
        chainId: 56,
        isCurrent: () async => true,
        approve: (_) async => true,
        broadcast: (_) async => '0x${'aa' * 32}',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BurstCampaignScreen(
            api: api,
            executor: executor,
            campaignId: 'one',
            wallet: wallet,
            chainId: 56,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Community Burst'), findsOneWidget);
      expect(
        find.textContaining('Choose the wallet and network'),
        findsOneWidget,
      );
      expect(find.text('Trigger Burst'), findsNothing);
      expect(find.text('Show join code'), findsNothing);
      expect(find.text('Cancel Burst'), findsNothing);
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox());
      client.close();
    }
  });
  testWidgets('trigger finalizes and executes the confirmed root transaction', (
    tester,
  ) async {
    final root = '0x${'ab' * 32}';
    final tx = {
      'reference': 'ref',
      'chainId': 56,
      'toAddress': destination,
      'operation': 'set_root',
      'valueBaseUnits': '0',
      'calldata': '0x7cb64759${root.substring(2)}',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    };
    var broadcasts = 0;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/messages')) {
        return http.Response(
          jsonEncode({
            'messages': [
              {
                'message': request.url.queryParameters.containsKey('after')
                    ? 'Another message'
                    : 'Thank you!',
                'walletAddress': wallet,
              },
            ],
            'nextCursor': request.url.queryParameters.containsKey('after')
                ? null
                : 'cursor-1',
          }),
          200,
        );
      }
      if (path.endsWith('/finalize')) {
        return http.Response(
          jsonEncode({
            'campaignId': 'one',
            'merkleRoot': root,
            'transaction': tx,
          }),
          200,
        );
      }
      if (path.endsWith('/execution')) {
        return http.Response(
          jsonEncode({
            'status': 'prepared',
            'walletAddress': wallet,
            'campaignId': 'one',
            'transaction': tx,
          }),
          200,
        );
      }
      if (path.endsWith('/confirm')) {
        return http.Response('{"status":"confirmed"}', 200);
      }
      if (path.endsWith('/submit')) {
        return http.Response('{"status":"submitted"}', 202);
      }
      return http.Response(
        jsonEncode({
          'id': 'one',
          'title': 'Drop',
          'status': broadcasts == 0 ? 'active' : 'claiming',
          'hostWalletAddress': wallet,
          'chainId': 56,
          'campaignAddress': destination,
          'participantCount': 1,
          'maxParticipants': 2,
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
    final executor = BurstTransactionExecutor(
      api: api,
      journal: Journal(),
      wallet: wallet,
      chainId: 56,
      isCurrent: () async => true,
      approve: (_) async => true,
      broadcast: (_) async {
        broadcasts++;
        return '0x${'aa' * 32}';
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstCampaignScreen(
          api: api,
          executor: executor,
          campaignId: 'one',
          wallet: wallet,
          chainId: 56,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trigger Burst'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(broadcasts, 1);
    expect(
      find.text('Delivering Burst rewards to guests…'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('View thank-you messages'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('View thank-you messages'));
    await tester.pumpAndSettle();
    expect(find.text('Thank you!'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Load more messages'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Load more messages'));
    await tester.pumpAndSettle();
    expect(find.text('Another message'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('creator can review and confirm a cancellation', (tester) async {
    var cancelled = false;
    var sent = 0;
    final tx = {
      'reference': 'cancel-ref',
      'operation': 'cancel',
      'chainId': 56,
      'toAddress': destination,
      'valueBaseUnits': '0',
      'calldata': '0xea8a1af0',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    };
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/recovery')) {
        return http.Response(jsonEncode({'transaction': tx}), 200);
      }
      if (path.endsWith('/execution')) {
        return http.Response(
          jsonEncode({
            'walletAddress': wallet,
            'campaignId': 'one',
            'status': 'prepared',
            'transaction': tx,
          }),
          200,
        );
      }
      if (path.endsWith('/submit')) {
        return http.Response('{"status":"submitted"}', 202);
      }
      if (path.endsWith('/confirm')) {
        cancelled = true;
        return http.Response('{"status":"confirmed"}', 200);
      }
      return http.Response(
        jsonEncode({
          'id': 'one',
          'title': 'Drop',
          'status': cancelled ? 'cancelled' : 'active',
          'hostWalletAddress': wallet,
          'chainId': 56,
          'campaignAddress': destination,
          'assetKind': 'native',
          'participantCount': 0,
          'maxParticipants': 2,
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
    final executor = BurstTransactionExecutor(
      api: api,
      journal: Journal(),
      wallet: wallet,
      chainId: 56,
      isCurrent: () async => true,
      approve: (_) async => true,
      broadcast: (_) async {
        sent++;
        return '0x${'ab' * 32}';
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstCampaignScreen(
          api: api,
          executor: executor,
          campaignId: 'one',
          wallet: wallet,
          chainId: 56,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cancel Burst'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cancel Burst'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(sent, 1);
    expect(find.text('CANCELLED'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('automatically transitions from claiming to completed via polling', (
    tester,
  ) async {
    var campaignStatus = 'claiming';
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'id': 'one',
          'title': 'Drop',
          'status': campaignStatus,
          'hostWalletAddress': wallet,
          'chainId': 56,
          'campaignAddress': destination,
          'participantCount': 1,
          'maxParticipants': 1,
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
    final executor = BurstTransactionExecutor(
      api: api,
      journal: Journal(),
      wallet: wallet,
      chainId: 56,
      isCurrent: () async => true,
      approve: (_) async => true,
      broadcast: (_) async => '0x${'ab' * 32}',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BurstCampaignScreen(
          api: api,
          executor: executor,
          campaignId: 'one',
          wallet: wallet,
          chainId: 56,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delivering Burst rewards to guests…'), findsOneWidget);
    campaignStatus = 'completed';
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('All Burst rewards have been delivered.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
}
