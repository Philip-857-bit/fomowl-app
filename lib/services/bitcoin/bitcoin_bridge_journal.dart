import 'dart:convert';
import 'dart:math';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_bridge_quote.dart';
import '../../models/bitcoin_network_data.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_submission_journal.dart';

class BitcoinBridgeSubmission {
  final Object _store;
  final String walletIdentity;
  final BitcoinBridgeQuote quote;
  final String txid;
  final String _nonce;
  final bool accepted;
  final String? resolution;
  bool get completed => resolution != null;
  const BitcoinBridgeSubmission._(
    this._store,
    this.walletIdentity,
    this.quote,
    this.txid,
    this._nonce,
    this.accepted,
    this.resolution,
  );
  Map<String, dynamic> _json() => {
    'quote': quote.toJson(),
    'txid': txid,
    'nonce': _nonce,
    'accepted': accepted,
    'resolution': resolution,
  };
}

/// Process-local capability linking a definitive rejection to one live attempt.
class BitcoinBridgeAttempt {
  final BitcoinBridgeJournal _owner;
  final BitcoinBridgeSubmission submission;
  bool _live = true;
  BitcoinBridgeAttempt._(this._owner, this.submission);
}

/// One unresolved BTC bridge per wallet, even if a new provider quote is fetched.
/// Public metadata only; never releases common input reservations or signs.
class BitcoinBridgeJournal {
  final BitcoinAccountStore store;
  final DateTime Function() _now;
  BitcoinBridgeJournal(this.store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  String _identity(String value) {
    final identity = value.trim().toLowerCase();
    if (identity.isEmpty || identity.length > 128) {
      throw const FormatException('Invalid Bitcoin bridge wallet');
    }
    return identity;
  }

  List<BitcoinBridgeSubmission> _decode(String identity, String? encoded) {
    if (encoded == null) {
      return [];
    }
    try {
      if (encoded.length > 131072) {
        throw const FormatException();
      }
      final raw = jsonDecode(encoded);
      if (raw is! Map ||
          raw.length != 3 ||
          raw['version'] != 1 ||
          raw['version'] is! int ||
          raw['walletIdentity'] != identity ||
          raw['attempts'] is! List ||
          (raw['attempts'] as List).length > 256) {
        throw const FormatException();
      }
      final ids = <String>{};
      final hashes = <String>{};
      final result = <BitcoinBridgeSubmission>[];
      for (final entry in raw['attempts'] as List) {
        if (entry is! Map ||
            entry.length != 5 ||
            entry['quote'] is! Map<String, dynamic> ||
            entry['accepted'] is! bool ||
            !entry.containsKey('resolution') ||
            entry['resolution'] != null &&
                !{'delivered', 'refunded'}.contains(entry['resolution']) ||
            entry['nonce'] is! String ||
            !RegExp(r'^[0-9a-f]{32}$').hasMatch(entry['nonce'] as String)) {
          throw const FormatException();
        }
        final quote = BitcoinBridgeQuote.fromRecord(
          entry['quote'] as Map<String, dynamic>,
        );
        if (!quote.committed ||
            !quote.request.bitcoinOrigin ||
            quote.depositAddress == null ||
            !ids.add(quote.requestId) ||
            !hashes.add(bitcoinTxid(entry['txid'])) ||
            entry['resolution'] != null && entry['accepted'] != true) {
          throw const FormatException();
        }
        result.add(
          BitcoinBridgeSubmission._(
            store.secureStore,
            identity,
            quote,
            bitcoinTxid(entry['txid']),
            entry['nonce'] as String,
            entry['accepted'] as bool,
            entry['resolution'] as String?,
          ),
        );
      }
      if (result.where((entry) => !entry.completed).length > 1) {
        throw const FormatException();
      }
      return result;
    } catch (_) {
      throw const FormatException('Invalid saved Bitcoin bridge state');
    }
  }

  String _encode(String identity, List<BitcoinBridgeSubmission> entries) =>
      jsonEncode({
        'version': 1,
        'walletIdentity': identity,
        'attempts': entries.map((entry) => entry._json()).toList(),
      });

  Future<BitcoinBridgeSubmission?> pending(String walletIdentity) {
    final identity = _identity(walletIdentity);
    return store.updateBridgeState(identity, (encoded) {
      final entries = _decode(
        identity,
        encoded,
      ).where((entry) => !entry.completed);
      return (entries.isEmpty ? null : entries.single, null);
    });
  }

  Future<BitcoinBridgeSubmission?> latest(String walletIdentity) {
    final identity = _identity(walletIdentity);
    return store.updateBridgeState(identity, (encoded) {
      final entries = _decode(identity, encoded);
      return (entries.isEmpty ? null : entries.last, null);
    });
  }

  Future<bool> canPrepare(String walletIdentity, String requestId) {
    final identity = _identity(walletIdentity);
    return store.updateBridgeState(identity, (encoded) {
      final entries = _decode(identity, encoded);
      return (
        !entries.any(
          (entry) => !entry.completed || entry.quote.requestId == requestId,
        ),
        null,
      );
    });
  }

  Future<BitcoinBridgeAttempt> reserve(
    String walletIdentity,
    BitcoinBridgeQuote quote,
    String txid,
  ) {
    final identity = _identity(walletIdentity);
    if (!quote.committed ||
        !quote.request.bitcoinOrigin ||
        quote.depositAddress == null ||
        !_now().isBefore(quote.approvalExpiresAt)) {
      throw StateError('Bitcoin bridge approval changed or expired');
    }
    final hash = bitcoinTxid(txid);
    return store.updateBridgeState(identity, (encoded) {
      if (!_now().isBefore(quote.approvalExpiresAt)) {
        throw StateError('Bitcoin bridge approval expired');
      }
      final entries = _decode(identity, encoded);
      if (entries.any(
        (entry) => !entry.completed || entry.quote.requestId == quote.requestId,
      )) {
        throw StateError('A Bitcoin bridge already has a saved payment');
      }
      // Retain completed request identities for the whole provider order window,
      // even if a refreshed quote gives the same order a new approval deadline.
      // Expiry alone NEVER removes an unresolved submission.
      entries.removeWhere(
        (entry) =>
            entry.completed && !_now().isBefore(entry.quote.providerDeadline),
      );
      if (entries.length >= 256) {
        throw StateError('Bitcoin bridge history requires reconciliation');
      }
      final random = Random.secure();
      final nonce = List.generate(
        16,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final saved = BitcoinBridgeSubmission._(
        store.secureStore,
        identity,
        quote,
        hash,
        nonce,
        false,
        null,
      );
      entries.add(saved);
      return (BitcoinBridgeAttempt._(this, saved), _encode(identity, entries));
    });
  }

  bool _same(BitcoinBridgeSubmission left, BitcoinBridgeSubmission right) =>
      identical(right._store, store.secureStore) &&
      left.walletIdentity == right.walletIdentity &&
      left.quote.requestId == right.quote.requestId &&
      left.txid == right.txid &&
      left._nonce == right._nonce;

  void retainPending(BitcoinBridgeAttempt attempt) {
    if (identical(attempt._owner, this)) {
      attempt._live = false;
    }
  }

  Future<void> markAccepted(BitcoinBridgeAttempt attempt) {
    if (!identical(attempt._owner, this) || !attempt._live) {
      throw StateError('Bitcoin bridge attempt is no longer live');
    }
    attempt._live = false;
    final saved = attempt.submission;
    return store.updateBridgeState(saved.walletIdentity, (encoded) {
      final entries = _decode(saved.walletIdentity, encoded);
      final index = entries.indexWhere((entry) => _same(entry, saved));
      if (index < 0 || entries[index].completed) {
        throw StateError('Bitcoin bridge state changed');
      }
      entries[index] = BitcoinBridgeSubmission._(
        saved._store,
        saved.walletIdentity,
        saved.quote,
        saved.txid,
        saved._nonce,
        true,
        null,
      );
      return (null, _encode(saved.walletIdentity, entries));
    });
  }

  Future<bool> releaseRejected(
    BitcoinBridgeAttempt attempt,
    BitcoinPreProviderRejection proof,
  ) {
    if (!identical(attempt._owner, this) || !attempt._live) {
      return Future.value(false);
    }
    attempt._live = false;
    final saved = attempt.submission;
    return store.updateBridgeState(saved.walletIdentity, (encoded) {
      final entries = _decode(saved.walletIdentity, encoded);
      final index = entries.indexWhere((entry) => _same(entry, saved));
      if (index < 0 || entries[index].accepted || entries[index].completed) {
        return (false, null);
      }
      entries.removeAt(index);
      return (true, _encode(saved.walletIdentity, entries));
    });
  }

  /// Called by the read-only host observer after independently querying chain
  /// and provider. Missing transactions or elapsed time cannot close it.
  Future<bool> completeDelivered(
    BitcoinBridgeSubmission saved, {
    required String observedTxid,
    required BitcoinTransactionStatus chainStatus,
    required String providerRequestId,
    required String providerStatus,
    BitcoinVerifiedResolvedPayment? replacementProof,
  }) => _complete(
    saved,
    observedTxid: observedTxid,
    chainStatus: chainStatus,
    providerRequestId: providerRequestId,
    providerStatus: providerStatus,
    resolution: 'delivered',
    replacementProof: replacementProof,
  );

  /// Relay's terminal refund state closes only the bridge guard after positive
  /// source confirmation. It does not clear inputs, assert a wallet balance,
  /// or authorize an automatic replacement payment.
  Future<bool> completeRefunded(
    BitcoinBridgeSubmission saved, {
    required String observedTxid,
    required BitcoinTransactionStatus chainStatus,
    required String providerRequestId,
    required String providerStatus,
    BitcoinVerifiedResolvedPayment? replacementProof,
  }) => _complete(
    saved,
    observedTxid: observedTxid,
    chainStatus: chainStatus,
    providerRequestId: providerRequestId,
    providerStatus: providerStatus,
    resolution: 'refunded',
    replacementProof: replacementProof,
  );

  Future<bool> _complete(
    BitcoinBridgeSubmission saved, {
    required String observedTxid,
    required BitcoinTransactionStatus chainStatus,
    required String providerRequestId,
    required String providerStatus,
    required String resolution,
    BitcoinVerifiedResolvedPayment? replacementProof,
  }) {
    final observed = bitcoinTxid(observedTxid);
    final replacement = replacementProof?.transaction;
    final replacementMatches =
        replacementProof != null &&
        replacementProof.belongsTo(
          store.secureStore,
          saved.walletIdentity,
          BitcoinProductNetwork.mainnet,
          saved.txid,
        ) &&
        replacement!.signed.txid == observed &&
        replacement.plan.recipients.length == 1 &&
        replacement.plan.recipients.single.address ==
            saved.quote.depositAddress &&
        replacement.plan.recipients.single.amountSat ==
            saved.quote.request.amount &&
        replacement.plan.recipientTotalSat == saved.quote.request.amount;
    if (!identical(saved._store, store.secureStore) ||
        observed != saved.txid && !replacementMatches ||
        providerRequestId != saved.quote.requestId ||
        !(resolution == 'delivered'
            ? providerStatus == 'success'
            : {'refund', 'refunded'}.contains(providerStatus)) ||
        !chainStatus.found ||
        !chainStatus.confirmed ||
        chainStatus.confirmations < 1) {
      return Future.value(false);
    }
    return store.updateBridgeState(saved.walletIdentity, (encoded) {
      final entries = _decode(saved.walletIdentity, encoded);
      final index = entries.indexWhere((entry) => _same(entry, saved));
      if (index < 0 || entries[index].completed) {
        return (false, null);
      }
      entries[index] = BitcoinBridgeSubmission._(
        saved._store,
        saved.walletIdentity,
        saved.quote,
        saved.txid,
        saved._nonce,
        true,
        resolution,
      );
      return (true, _encode(saved.walletIdentity, entries));
    });
  }
}
