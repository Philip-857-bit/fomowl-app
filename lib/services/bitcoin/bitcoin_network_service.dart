import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_environment.dart';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../http_client_service.dart';
import '../wallet_backend_auth_service.dart';

abstract interface class BitcoinNetworkApi {
  Future<bool> available(BitcoinProductNetwork network);
  Future<List<BitcoinAddressActivity>> fetchAccountState(
    String walletIdentity,
    BitcoinProductNetwork network,
    List<String> addresses,
  );
  Future<BitcoinFeeRates> fetchFeeRates(BitcoinProductNetwork network);
  Future<String> broadcast(
    String walletIdentity,
    BitcoinProductNetwork network,
    String signedTransaction,
  );
  Future<BitcoinTransactionStatus> fetchTransactionStatus(
    BitcoinProductNetwork network,
    String txid,
  );
  Future<BitcoinHistoryBatch> fetchAccountHistory(
    String walletIdentity,
    BitcoinProductNetwork network,
    List<String> addresses, {
    int limit = 100,
  });
}

class BitcoinNetworkException implements Exception {
  final int? statusCode;
  const BitcoinNetworkException([this.statusCode]);
  @override
  String toString() => 'Bitcoin network data is unavailable';
}

/// Chain facts only. Fixed request schemas transmit public addresses, never XPUB/seed/private data.
class BitcoinNetworkService implements BitcoinNetworkApi {
  final http.Client client;
  final WalletBackendAuthService auth;
  final Duration timeout;
  BitcoinNetworkService({
    http.Client? client,
    WalletBackendAuthService? auth,
    this.timeout = const Duration(seconds: 35),
  }) : client = client ?? HttpClientService().client,
       auth = auth ?? WalletBackendAuthService();
  Uri _uri(
    BitcoinProductNetwork network,
    String suffix, [
    Map<String, String>? query,
  ]) => AppEnvironment.blockchain(
    '/networks/${network.networkKey}/$suffix',
    query,
  );
  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final abort = Completer<void>();
    final timer = Timer(timeout, () {
      if (!abort.isCompleted) abort.complete();
    });
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    );
    request.headers.addAll(headers);
    if (body != null) request.body = body;
    try {
      final response = await client.send(request).timeout(timeout);
      const maximum = 16 * 1024 * 1024;
      if (response.contentLength != null && response.contentLength! > maximum) {
        throw const FormatException('Oversized Bitcoin network response');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > maximum) {
          throw const FormatException('Oversized Bitcoin network response');
        }
        bytes.add(chunk);
      }
      return http.Response.bytes(
        bytes.takeBytes(),
        response.statusCode,
        headers: response.headers,
      );
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode != 200) {
      throw BitcoinNetworkException(response.statusCode);
    }
    if (response.bodyBytes.length > 16 * 1024 * 1024) {
      throw const FormatException('Oversized Bitcoin network response');
    }
    try {
      return bitcoinJsonObject(jsonDecode(response.body));
    } on FormatException {
      throw const FormatException('Invalid Bitcoin network response');
    }
  }

  Future<Map<String, dynamic>> _get(
    BitcoinProductNetwork network,
    String path,
  ) async {
    try {
      return _decode(await _send('GET', _uri(network, path)));
    } on BitcoinNetworkException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const BitcoinNetworkException();
    }
  }

  List<String> _addresses(BitcoinProductNetwork network, List<String> input) {
    if (input.isEmpty || input.length > 40) {
      throw ArgumentError(
        'Bitcoin address batches must contain 1..40 addresses',
      );
    }
    final prefix = network == BitcoinProductNetwork.mainnet ? 'bc1' : 'tb1';
    for (final address in input) {
      // Shape/data-boundary guard only. Rust is authoritative about address validity.
      if (address.length > 90 ||
          !address.startsWith(prefix) ||
          RegExp(r'\s').hasMatch(address)) {
        throw ArgumentError('Invalid Bitcoin address batch');
      }
    }
    return input.toSet().toList()..sort();
  }

  Future<Map<String, dynamic>> _post(
    String identity,
    BitcoinProductNetwork network,
    String path,
    Map<String, Object?> body, [
    Map<String, String>? query,
  ]) async {
    // Owllet's stable wallet identity uses the same canonical form as backend
    // session creation. Bitcoin receive addresses and signed bytes stay intact.
    final canonicalIdentity = identity.trim().toLowerCase();
    if (canonicalIdentity.isEmpty || canonicalIdentity.length > 128) {
      throw ArgumentError('Invalid wallet identity');
    }
    try {
      final response = await auth.sendAuthorized(
        canonicalIdentity,
        (headers) => _send(
          'POST',
          _uri(network, path, query),
          headers: headers,
          body: jsonEncode({...body, 'walletAddress': canonicalIdentity}),
        ),
        {'Content-Type': 'application/json'},
      );
      return _decode(response);
    } on BitcoinNetworkException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const BitcoinNetworkException();
    }
  }

  @override
  Future<bool> available(BitcoinProductNetwork network) async {
    final data = await _get(network, 'capabilities');
    if (data['networkKey'] != network.networkKey ||
        data['maxAddresses'] != 40) {
      throw const FormatException('Incompatible Bitcoin backend');
    }
    return bitcoinJsonBool(data['available']);
  }

  @override
  Future<List<BitcoinAddressActivity>> fetchAccountState(
    String walletIdentity,
    BitcoinProductNetwork network,
    List<String> addresses,
  ) async {
    final requested = _addresses(network, addresses);
    final data = await _post(walletIdentity, network, 'account-state', {
      'walletAddress': walletIdentity,
      'addresses': requested,
    });
    if (data['networkKey'] != network.networkKey ||
        data['addresses'] is! List) {
      throw const FormatException('Bitcoin account network mismatch');
    }
    final raw = data['addresses'] as List;
    if (raw.length != requested.length) {
      throw const FormatException('Incomplete Bitcoin address response');
    }
    final known = requested.toSet();
    final observed = <String>{};
    final outpoints = <String>{};
    final result = <BitcoinAddressActivity>[];
    for (final row in raw) {
      final activity = BitcoinAddressActivity.fromJson(bitcoinJsonObject(row));
      if (!known.contains(activity.address) ||
          !observed.add(activity.address)) {
        throw const FormatException('Bitcoin address response mismatch');
      }
      for (final utxo in activity.utxos) {
        if (!outpoints.add(utxo.outpoint)) {
          throw const FormatException('Duplicate Bitcoin outpoint');
        }
      }
      result.add(activity);
    }
    return List.unmodifiable(result);
  }

  @override
  Future<BitcoinFeeRates> fetchFeeRates(BitcoinProductNetwork network) async =>
      BitcoinFeeRates.fromJson(await _get(network, 'fees'));
  @override
  Future<String> broadcast(
    String walletIdentity,
    BitcoinProductNetwork network,
    String signedTransaction,
  ) async {
    if (signedTransaction.isEmpty ||
        signedTransaction.length > 2000000 ||
        !RegExp(r'^(?:[0-9a-fA-F]{2})+$').hasMatch(signedTransaction)) {
      throw ArgumentError('Invalid signed Bitcoin transaction');
    }
    final data = await _post(walletIdentity, network, 'broadcast', {
      'walletAddress': walletIdentity,
      'signedTransaction': signedTransaction,
    });
    if (data['success'] != true || data['networkKey'] != network.networkKey) {
      throw const FormatException('Invalid Bitcoin broadcast response');
    }
    return bitcoinTxid(data['transactionHash']);
  }

  @override
  Future<BitcoinTransactionStatus> fetchTransactionStatus(
    BitcoinProductNetwork network,
    String txid,
  ) async => BitcoinTransactionStatus.fromJson(
    await _get(network, 'transaction/${bitcoinTxid(txid)}'),
  );
  @override
  Future<BitcoinHistoryBatch> fetchAccountHistory(
    String walletIdentity,
    BitcoinProductNetwork network,
    List<String> addresses, {
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('Invalid Bitcoin history limit');
    }
    final requested = _addresses(network, addresses);
    final data = await _post(
      walletIdentity,
      network,
      'account-history',
      {'walletAddress': walletIdentity, 'addresses': requested},
      {'limit': '$limit'},
    );
    if (data['networkKey'] != network.networkKey ||
        data['transactions'] is! List) {
      throw const FormatException('Bitcoin history network mismatch');
    }
    final raw = data['transactions'] as List;
    if (raw.length > limit) {
      throw const FormatException('Oversized Bitcoin history response');
    }
    final hashes = <String>{};
    final known = requested.toSet();
    final result = <BitcoinHistoryTransaction>[];
    for (final row in raw) {
      final transaction = BitcoinHistoryTransaction.fromJson(
        bitcoinJsonObject(row),
      );
      if (!hashes.add(transaction.txid) ||
          [
            ...transaction.ownedInputs,
            ...transaction.ownedOutputs,
          ].any((entry) => !known.contains(entry.address))) {
        throw const FormatException('Invalid Bitcoin history ownership');
      }
      result.add(transaction);
    }
    return BitcoinHistoryBatch(
      network,
      result,
      bitcoinJsonBool(data['truncated']),
    );
  }
}
