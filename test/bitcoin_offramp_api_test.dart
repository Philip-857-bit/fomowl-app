import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_offramp_api.dart';
import 'package:fomowl_wallet/services/cashin_profile_auth_service.dart';
import 'package:fomowl_wallet/services/wallet_backend_auth_service.dart';

class WalletAuth extends WalletBackendAuthService {
  final List<String> identities = [];
  @override
  Future<http.Response> sendAuthorized(
    String identity,
    Future<http.Response> Function(Map<String, String>) send,
    Map<String, String> headers,
  ) {
    identities.add(identity);
    return send({...headers, 'Authorization': 'Bearer wallet-session-fixture'});
  }
}

class ProfileAuth extends CashinProfileAuthService {
  final List<String> identities = [];
  @override
  Future<http.Response> sendAuthorized(
    String identity,
    Future<http.Response> Function(Map<String, String>) send,
    Map<String, String> headers,
  ) {
    identities.add(identity);
    return send({
      ...headers,
      'Authorization': 'Bearer profile-session-fixture',
    });
  }
}

void main() {
  const reference = 'OWL-PAY-1234567890';
  const destination =
      'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr';
  Map<String, dynamic> plan() => {
    'reference': reference,
    'action': 'transfer',
    'networkKey': 'bitcoin:mainnet',
    'chainFamily': 'bitcoin',
    'assetSymbol': 'BTC',
    'nativeSymbol': 'BTC',
    'decimals': 8,
    'toAddress': destination,
    'amountBaseUnits': '4730',
    'fundingExpiresAt': '2099-01-01T00:00:00Z',
  };
  test(
    'plan uses wallet session; acknowledgement uses profile session and exact txid',
    () async {
      final wallet = WalletAuth();
      final profile = ProfileAuth();
      final requests = <http.Request>[];
      final api = BitcoinOfframpApi(
        walletAuth: wallet,
        profileAuth: profile,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': request.method == 'GET'
                  ? plan()
                  : {'message': 'Wallet transfer submitted.'},
            }),
            200,
          );
        }),
      );
      final intent = await api.fetchIntent(' 0xAbC ', reference);
      expect(intent.amountSat, BigInt.from(4730));
      await api.acknowledge(' 0xAbC ', reference, 'AB' * 32);
      expect(wallet.identities, ['0xabc']);
      expect(profile.identities, ['0xabc']);
      expect(
        requests[0].headers['Authorization'],
        'Bearer wallet-session-fixture',
      );
      expect(
        requests[1].headers['Authorization'],
        'Bearer profile-session-fixture',
      );
      expect(
        requests[0].url.path.endsWith('/$reference/wallet-transfer-plan'),
        isTrue,
      );
      expect(
        requests[1].url.path.endsWith('/$reference/confirm-wallet-transfer'),
        isTrue,
      );
      expect(jsonDecode(requests[1].body), {'transactionHash': 'ab' * 32});
    },
  );
  test(
    'malformed and unsuccessful responses never acknowledge payment',
    () async {
      for (final response in [
        http.Response('private fixture content', 200),
        http.Response('{"success":false,"data":{}}', 200),
        http.Response('{"success":true,"data":{}}', 503),
      ]) {
        var calls = 0;
        final api = BitcoinOfframpApi(
          walletAuth: WalletAuth(),
          profileAuth: ProfileAuth(),
          client: MockClient((_) async {
            calls++;
            return response;
          }),
        );
        await expectLater(
          api.acknowledge('0xabc', reference, '11' * 32),
          throwsFormatException,
        );
        expect(calls, 1);
      }
    },
  );
  test(
    'foreign reference, network and non-integer amount fail closed',
    () async {
      for (final changed in [
        {'reference': 'other'},
        {'networkKey': 'bitcoin:testnet4'},
        {'amountBaseUnits': 4730},
      ]) {
        final api = BitcoinOfframpApi(
          walletAuth: WalletAuth(),
          profileAuth: ProfileAuth(),
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'success': true,
                'data': {...plan(), ...changed},
              }),
              200,
            ),
          ),
        );
        await expectLater(
          api.fetchIntent('0xabc', reference),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'invalid public identifiers are rejected before authentication or transport',
    () async {
      final wallet = WalletAuth();
      final profile = ProfileAuth();
      final api = BitcoinOfframpApi(
        walletAuth: wallet,
        profileAuth: profile,
        client: MockClient(
          (_) async => throw StateError('Unexpected transport'),
        ),
      );
      await expectLater(
        api.fetchIntent('0xabc', '../other'),
        throwsFormatException,
      );
      await expectLater(
        api.acknowledge('0xabc', reference, 'invalid'),
        throwsFormatException,
      );
      expect(wallet.identities, isEmpty);
      expect(profile.identities, isEmpty);
    },
  );
}
