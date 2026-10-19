import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_environment.dart';
import '../models/non_evm_receipt_facts.dart';
import 'http_client_service.dart';

/// Read-only chain facts. No signing, retries, or transaction-state mutations.
class NonEvmReceiptService {
  final http.Client _client;
  final Duration timeout;
  NonEvmReceiptService({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? HttpClientService().client;

  Future<NonEvmReceiptFacts> fetch({
    required String networkKey,
    required String transactionHash,
  }) async {
    final key = NonEvmReceiptFacts.canonicalNetwork(networkKey);
    final hash = NonEvmReceiptFacts.checkedHash(key, transactionHash);
    final uri = AppEnvironment.blockchain(
      '/networks/${Uri.encodeComponent(key)}/transaction/${Uri.encodeComponent(hash)}',
    );
    final response = await _client.get(uri).timeout(timeout);
    if ((response.statusCode != 200 && response.statusCode != 202) ||
        response.bodyBytes.length > 65536) {
      throw const FormatException('Transaction details unavailable');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        response.statusCode == 202 && decoded['pending'] != true) {
      throw const FormatException('Invalid transaction details');
    }
    return NonEvmReceiptFacts.fromJson(
      decoded,
      networkKey: key,
      transactionHash: hash,
    );
  }
}
