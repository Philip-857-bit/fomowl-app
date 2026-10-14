import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_environment.dart';
import '../../models/bitcoin_offramp_intent.dart';
import '../../models/bitcoin_network_data.dart';
import '../cashin_profile_auth_service.dart';
import '../http_client_service.dart';
import '../wallet_backend_auth_service.dart';

/// Public withdrawal transport. The native plan endpoint uses a wallet session;
/// the bookkeeping endpoint uses the existing cash-out profile JWT.
class BitcoinOfframpApi {
  final WalletBackendAuthService walletAuth;
  final CashinProfileAuthService profileAuth;
  final http.Client client;
  BitcoinOfframpApi({
    WalletBackendAuthService? walletAuth,
    CashinProfileAuthService? profileAuth,
    http.Client? client,
  }) : walletAuth = walletAuth ?? WalletBackendAuthService(),
       profileAuth = profileAuth ?? CashinProfileAuthService(),
       client = client ?? HttpClientService().client;

  String _identity(String value) {
    final identity = value.trim().toLowerCase();
    if (identity.isEmpty) {
      throw const FormatException('Missing wallet identity');
    }
    return identity;
  }

  Uri _endpoint(String reference, String action) {
    if (!BitcoinOfframpIntent.validReference(reference)) {
      throw const FormatException('Invalid Bitcoin cash-out reference');
    }
    return AppEnvironment.api(
      '/cash-in/withdrawals/${Uri.encodeComponent(reference)}/$action',
    );
  }

  Map<String, dynamic> _data(http.Response response) {
    if (response.statusCode != 200 || response.body.length > 65536) {
      throw const FormatException('Unable to load Bitcoin cash-out state');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['success'] != true ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return body['data'] as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Invalid Bitcoin cash-out response');
    }
  }

  Future<BitcoinOfframpIntent> fetchIntent(
    String identity,
    String reference,
  ) async {
    final wallet = _identity(identity);
    final uri = _endpoint(reference, 'wallet-transfer-plan');
    final response = await walletAuth
        .sendAuthorized(
          wallet,
          (headers) => client.get(uri, headers: headers),
          const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    return BitcoinOfframpIntent.fromWithdrawalPlan(reference, _data(response));
  }

  /// Records an already submitted txid; never signs, broadcasts or retries BTC.
  Future<void> acknowledge(
    String identity,
    String reference,
    String txid,
  ) async {
    final wallet = _identity(identity);
    final hash = bitcoinTxid(txid);
    final uri = _endpoint(reference, 'confirm-wallet-transfer');
    final response = await profileAuth
        .sendAuthorized(
          wallet,
          (headers) => client.post(
            uri,
            headers: headers,
            body: jsonEncode({'transactionHash': hash}),
          ),
          const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));
    _data(response);
  }
}
