import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_bill_api.dart';
import 'package:fomowl_wallet/services/wallet_backend_auth_service.dart';

class BillWalletAuth extends WalletBackendAuthService {
  final identities = <String>[];
  @override
  Future<http.Response> sendAuthorized(
    String identity,
    Future<http.Response> Function(Map<String, String>) send,
    Map<String, String> headers,
  ) {
    identities.add(identity);
    return send({...headers, 'Authorization': 'Bearer ws_fixture'});
  }
}

class RetainedBillAuth extends BillWalletAuth {
  final bool valid;
  RetainedBillAuth(this.valid);
  @override
  Future<String?> getValidSessionToken(String identity) async {
    expect(identity, 'wallet');
    return valid ? 'ws_retained_fixture' : null;
  }

  @override
  Future<http.Response> sendAuthorized(
    String identity,
    Future<http.Response> Function(Map<String, String>) send,
    Map<String, String> headers,
  ) async {
    throw StateError('Read-only recovery must not refresh authentication');
  }
}

void main() {
  const reference = 'OWL-BTC-BILL-11111111111111111111111111111111';
  test(
    'read-only acknowledgement uses retained session and never creates or retries authentication',
    () async {
      for (final valid in [true, false]) {
        var calls = 0;
        final api = BitcoinBillApi(
          auth: RetainedBillAuth(valid),
          client: MockClient((request) async {
            calls++;
            expect(
              request.headers['Authorization'],
              'Bearer ws_retained_fixture',
            );
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'reference': reference, 'transactionHash': 'ab' * 32},
              }),
              200,
            );
          }),
        );
        if (valid) {
          await api.acknowledgeReadOnly(' WALLET ', reference, 'ab' * 32);
        } else {
          await expectLater(
            api.acknowledgeReadOnly('wallet', reference, 'ab' * 32),
            throwsFormatException,
          );
        }
        expect(calls, valid ? 1 : 0);
      }
    },
  );
  test(
    'bill acknowledgement uses canonical wallet session and exact public txid only',
    () async {
      final auth = BillWalletAuth();
      final api = BitcoinBillApi(
        auth: auth,
        client: MockClient((request) async {
          expect(
            request.url.path,
            endsWith('/bitcoin-bills/$reference/transaction'),
          );
          expect(request.headers['Authorization'], 'Bearer ws_fixture');
          expect(jsonDecode(request.body), {'transactionHash': 'ab' * 32});
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'reference': reference, 'transactionHash': 'ab' * 32},
            }),
            200,
          );
        }),
      );
      await api.acknowledge(' 0xWALLET ', reference, 'AB' * 32);
      expect(auth.identities, ['0xwallet']);
    },
  );
  test(
    'failed or mismatched acknowledgement never retries a payment',
    () async {
      for (final status in [200, 403, 503]) {
        var requests = 0;
        final api = BitcoinBillApi(
          auth: BillWalletAuth(),
          client: MockClient((_) async {
            requests++;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'reference': reference, 'transactionHash': 'cd' * 32},
              }),
              status,
            );
          }),
        );
        await expectLater(
          api.acknowledge('wallet', reference, 'ab' * 32),
          throwsFormatException,
        );
        expect(requests, 1);
      }
    },
  );
}
