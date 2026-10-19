import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_environment.dart';
import '../../models/bitcoin_bill_funding_plan.dart';
import '../../models/bitcoin_network_data.dart';
import '../http_client_service.dart';
import '../wallet_backend_auth_service.dart';

/// Native wallet-session transport. The hosted app never receives this session.
class BitcoinBillApi {
  final WalletBackendAuthService auth;
  final http.Client client;
  BitcoinBillApi({WalletBackendAuthService? auth, http.Client? client})
    : auth = auth ?? WalletBackendAuthService(),
      client = client ?? HttpClientService().client;

  Uri _endpoint(String reference, String action) {
    if (!BitcoinBillFundingPlan.validReference(reference)) {
      throw const FormatException('Invalid Bitcoin bill reference');
    }
    return AppEnvironment.api(
      '/cash-in/bitcoin-bills/${Uri.encodeComponent(reference)}/$action',
    );
  }

  Map<String, dynamic> _data(http.Response response) {
    if (response.statusCode != 200 || response.body.length > 65536) {
      throw const FormatException('Unable to load Bitcoin bill state');
    }
    final Object? body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw const FormatException('Invalid Bitcoin bill response');
    }
    if (body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid Bitcoin bill response');
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<BitcoinBillFundingPlan> fetchIntent(
    String identity,
    String reference,
  ) async {
    final wallet = identity.trim().toLowerCase();
    if (wallet.isEmpty) throw const FormatException('Missing wallet identity');
    final response = await auth
        .sendAuthorized(
          wallet,
          (headers) =>
              client.get(_endpoint(reference, 'wallet-plan'), headers: headers),
          const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    return BitcoinBillFundingPlan.fromServer(
      reference,
      wallet,
      _data(response),
    );
  }

  /// Receipt polling must not sign a fresh authentication challenge.
  Future<void> acknowledgeReadOnly(
    String identity,
    String reference,
    String txid,
  ) async {
    final wallet = identity.trim().toLowerCase();
    if (wallet.isEmpty) throw const FormatException('Missing wallet identity');
    final token = await auth.getValidSessionToken(wallet);
    if (token == null || token.isEmpty) {
      throw const FormatException('Wallet session unavailable');
    }
    final hash = bitcoinTxid(txid);
    final response = await client
        .post(
          _endpoint(reference, 'transaction'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'transactionHash': hash}),
        )
        .timeout(const Duration(seconds: 15));
    final data = _data(response);
    if (data['reference'] != reference || data['transactionHash'] != hash) {
      throw const FormatException('Bitcoin bill acknowledgement mismatch');
    }
  }

  /// Acknowledges an existing broadcast only; never signs or resends Bitcoin.
  Future<void> acknowledge(
    String identity,
    String reference,
    String txid,
  ) async {
    final wallet = identity.trim().toLowerCase();
    if (wallet.isEmpty) throw const FormatException('Missing wallet identity');
    final hash = bitcoinTxid(txid);
    final response = await auth
        .sendAuthorized(
          wallet,
          (headers) => client.post(
            _endpoint(reference, 'transaction'),
            headers: headers,
            body: jsonEncode({'transactionHash': hash}),
          ),
          const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));
    final data = _data(response);
    if (data['reference'] != reference || data['transactionHash'] != hash) {
      throw const FormatException('Bitcoin bill acknowledgement mismatch');
    }
  }
}
