import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_history_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('history keeps joined Bursts accessible after refresh', (
    tester,
  ) async {
    final client = MockClient((request) async {
      final joined = request.url.path.endsWith('/participations');
      return http.Response(
        jsonEncode({
          'campaigns': [
            {
              'id': joined ? 'joined' : 'created',
              'title': joined ? 'Joined Burst' : 'Created Burst',
              'status': 'active',
              'participantCount': joined ? 50 : 3,
              'createdAt': joined ? '2026-11-02' : '2026-11-01',
            },
          ],
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
    Map<String, dynamic>? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: BurstHistoryScreen(
          api: api,
          includeParticipations: true,
          initialCampaigns: const [
            {'id': 'joined', 'title': 'Joined Burst', '_isParticipation': true},
          ],
          openCampaign: (campaign) async {
            opened = campaign;
          },
        ),
      ),
    );
    await tester.tap(find.text('Joined Burst'));
    await tester.pumpAndSettle();
    expect(opened?['_isParticipation'], isTrue);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('burst-history-created-count')),
          )
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('burst-history-guest-entries')),
          )
          .data,
      '3',
    );
    expect(find.text('Joined Burst'), findsOneWidget);
    expect(find.text('Created Burst'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('history filters real campaigns and opens details', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response('{"campaigns":[]}', 200),
    );
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: BurstHistoryScreen(
          api: api,
          initialCampaigns: const [
            {
              'id': 'a',
              'title': 'Active tokens',
              'status': 'active',
              'assetKind': 'erc20',
            },
            {
              'id': 'b',
              'title': 'Finished NFT',
              'status': 'completed',
              'assetKind': 'erc721',
            },
          ],
          openCampaign: (campaign) async {
            opened = campaign['id'] as String;
          },
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('burst-history-created-count')),
          )
          .data,
      '2',
    );
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Active tokens'), findsOneWidget);
    expect(find.text('Finished NFT'), findsNothing);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Finished NFT'), findsOneWidget);
    expect(find.text('Active tokens'), findsNothing);
    await tester.tap(find.text('Finished NFT'));
    await tester.pumpAndSettle();
    expect(opened, 'b');
    expect(find.text('No Bursts in this view.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
}
