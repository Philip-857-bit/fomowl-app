import 'package:reown_walletkit/reown_walletkit.dart';

class WalletConnectPolicyException implements Exception {
  const WalletConnectPolicyException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => message;
}

/// Pure validation helpers for the WalletConnect trust boundary.
class WalletConnectPolicy {
  const WalletConnectPolicy._();

  static const solanaMainnetChain = 'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp';
  static const tronMainnetChain = 'tron:0x2b6653dc';

  static const evmMethods = <String>{
    'eth_sendTransaction',
    'personal_sign',
    'eth_signTypedData_v4',
  };

  static const solanaMethods = <String>{
    'solana_signMessage',
    'solana_signTransaction',
    'solana_signAndSendTransaction',
    'solana_signAllTransactions',
  };

  static const tronMethods = <String>{
    'tron_signMessage',
    'tron_signTransaction',
  };

  static const evmEvents = <String>{'chainChanged', 'accountsChanged'};

  static List<dynamic> normalizeParams(dynamic params) {
    if (params == null) return const [];
    return params is List ? params : <dynamic>[params];
  }

  static String namespaceForChain(String chainId) {
    final separator = chainId.indexOf(':');
    if (separator <= 0) {
      throw const WalletConnectPolicyException(
        -32602,
        'The request contains an invalid chain identifier.',
      );
    }
    return chainId.substring(0, separator);
  }

  static void validateSessionRequest({
    required Map<String, Namespace> namespaces,
    required String chainId,
    required String method,
  }) {
    final namespace = namespaceForChain(chainId);
    final authorized = namespaces.entries.any((entry) {
      if (entry.key != namespace && entry.key != chainId) return false;
      final approvedChains = <String>{
        ...?entry.value.chains,
        ...chainsFromAccounts(entry.value.accounts),
      };
      return approvedChains.contains(chainId) &&
          entry.value.methods.contains(method);
    });
    if (!authorized) {
      throw const WalletConnectPolicyException(
        4200,
        'This request was not authorized by the connected session.',
      );
    }
  }

  static String approvedAddress({
    required Map<String, Namespace> namespaces,
    required String chainId,
  }) {
    final namespace = namespaceForChain(chainId);
    final prefix = '$chainId:';
    for (final entry in namespaces.entries) {
      if (entry.key != namespace && entry.key != chainId) continue;
      for (final account in entry.value.accounts) {
        if (account.startsWith(prefix) && account.length > prefix.length) {
          return account.substring(prefix.length);
        }
      }
    }
    throw const WalletConnectPolicyException(
      4100,
      'The requested account is not connected.',
    );
  }

  static void requireMatchingAddress({
    required String requested,
    required String approved,
    required bool caseSensitive,
  }) {
    final matches = caseSensitive
        ? requested == approved
        : requested.toLowerCase() == approved.toLowerCase();
    if (!matches) {
      throw const WalletConnectPolicyException(
        4100,
        'The request does not belong to the connected account.',
      );
    }
  }

  static String extractEvmSigningPayload({
    required String method,
    required dynamic params,
    required String approvedAddress,
  }) {
    final values = normalizeParams(params);
    if (values.length < 2) {
      throw const WalletConnectPolicyException(
        -32602,
        'The signing request is missing required parameters.',
      );
    }

    final first = values[0]?.toString().trim() ?? '';
    final second = values[1]?.toString().trim() ?? '';
    final firstIsAddress = _isMatchingEvmAddress(first, approvedAddress);
    final secondIsAddress = _isMatchingEvmAddress(second, approvedAddress);

    if (method == 'eth_sign') {
      if (!firstIsAddress || second.isEmpty) {
        throw const WalletConnectPolicyException(
          4100,
          'The signature request does not belong to the connected account.',
        );
      }
      return second;
    }

    if (firstIsAddress && second.isNotEmpty) return second;
    if (secondIsAddress && first.isNotEmpty) return first;
    throw const WalletConnectPolicyException(
      4100,
      'The signature request does not belong to the connected account.',
    );
  }

  static dynamic extractTypedData({
    required dynamic params,
    required String approvedAddress,
  }) {
    final values = normalizeParams(params);
    if (values.length < 2) {
      throw const WalletConnectPolicyException(
        -32602,
        'The typed-data request is missing required parameters.',
      );
    }

    final requestedAddress = values.first?.toString().trim() ?? '';
    requireMatchingAddress(
      requested: requestedAddress,
      approved: approvedAddress,
      caseSensitive: false,
    );
    final payload = values[1];
    if (payload is String && payload.trim().isNotEmpty) return payload;
    if (payload is Map) return payload;
    throw const WalletConnectPolicyException(
      -32602,
      'The typed-data payload is invalid.',
    );
  }

  static Map<String, dynamic> requireTransactionMap(
    dynamic params, {
    required String key,
  }) {
    final values = normalizeParams(params);
    if (values.isEmpty || values.first is! Map) {
      throw const WalletConnectPolicyException(
        -32602,
        'The transaction request is invalid.',
      );
    }
    final outer = Map<String, dynamic>.from(values.first as Map);
    if (key.isEmpty) return outer;
    final nested = outer[key];
    if (nested is! Map) {
      throw const WalletConnectPolicyException(
        -32602,
        'The transaction request is invalid.',
      );
    }
    return Map<String, dynamic>.from(nested);
  }

  static Map<String, dynamic> tronTransaction(dynamic params) {
    final outer = requireTransactionMap(params, key: '');
    var transaction = outer['transaction'] is Map
        ? Map<String, dynamic>.from(outer['transaction'] as Map)
        : outer;
    if (transaction['transaction'] is Map) {
      transaction = Map<String, dynamic>.from(
        transaction['transaction'] as Map,
      );
    }
    return transaction;
  }

  static Map<String, String>? approvedSessionProperties({
    required Map<String, String>? requested,
    required Iterable<String> namespaceKeys,
  }) {
    final approved = <String, String>{...?requested};
    final hasTron = namespaceKeys.any(
      (key) => key == 'tron' || key.startsWith('tron:'),
    );
    if (hasTron) {
      approved['tron_method_version'] = 'v1';
    }
    return approved.isEmpty ? null : approved;
  }

  static Set<String> chainsFromAccounts(Iterable<String> accounts) {
    final chains = <String>{};
    for (final account in accounts) {
      final first = account.indexOf(':');
      final second = first < 0 ? -1 : account.indexOf(':', first + 1);
      if (first > 0 && second > first + 1) {
        chains.add(account.substring(0, second));
      }
    }
    return chains;
  }

  static String redactedPairingLog(Uri uri) => '${uri.scheme}:<redacted>';

  static bool _isMatchingEvmAddress(String value, String address) =>
      value.toLowerCase() == address.toLowerCase();
}
