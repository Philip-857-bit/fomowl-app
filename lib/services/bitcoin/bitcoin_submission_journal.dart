import 'dart:convert';
import '../../models/bitcoin_account_state.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_account_store.dart';

/// Public outpoints only. Uncertain broadcasts remain reserved across restarts.
/// No elapsed-time release: a timeout is not evidence that a transaction failed.
class BitcoinSubmissionJournal {
  final BitcoinAccountStore store;
  const BitcoinSubmissionJournal(this.store);
  static final _hash = RegExp(r'^[0-9a-f]{64}$');
  static final _outpoint = RegExp(r'^[0-9a-f]{64}:[0-9]{1,10}$');
  Map<String, dynamic> _decode(String? raw, String identity) {
    if (raw == null) {
      return {
        'version': 1,
        'identity': identity.toLowerCase(),
        'entries': <String, dynamic>{},
      };
    }
    if (raw.length > 524288) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['version'] != 1 ||
        value['identity'] != identity.toLowerCase() ||
        value['entries'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    final entries = value['entries'] as Map<String, dynamic>;
    if (entries.length > 1024) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    final seen = <String>{};
    for (final entry in entries.entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2 ||
          !['mainnet', 'testnet4'].contains(parts[0]) ||
          !_hash.hasMatch(parts[1]) ||
          entry.value is! List ||
          (entry.value as List).isEmpty ||
          (entry.value as List).length > 1000) {
        throw const FormatException('Invalid Bitcoin submission journal');
      }
      for (final point in entry.value as List) {
        if (point is! String ||
            !_outpoint.hasMatch(point) ||
            int.parse(point.split(':').last) > 0xffffffff ||
            !seen.add('${parts[0]}|$point')) {
          throw const FormatException('Invalid Bitcoin submission journal');
        }
      }
    }
    return value;
  }

  Future<Set<String>> reserved(
    String identity,
    BitcoinProductNetwork network,
  ) => store.updateSubmissionState(identity, (raw) {
    final entries = _decode(raw, identity)['entries'] as Map<String, dynamic>;
    return (
      {
        for (final entry in entries.entries)
          if (entry.key.startsWith('${network.id}|'))
            ...List<String>.from(entry.value as List),
      },
      null,
    );
  });

  /// Returns false if this exact transaction already had a submission attempt.
  Future<bool> reserve(
    String identity,
    BitcoinProductNetwork network,
    String txid,
    List<BitcoinUtxoDto> inputs,
  ) => store.updateSubmissionState(identity, (raw) {
    if (!_hash.hasMatch(txid) || inputs.isEmpty) {
      throw const FormatException('Invalid Bitcoin submission');
    }
    final value = _decode(raw, identity);
    final entries = value['entries'] as Map<String, dynamic>;
    final key = '${network.id}|$txid';
    final points = inputs
        .map((input) => '${input.txid}:${input.vout}')
        .toList();
    if (points.toSet().length != points.length) {
      throw const FormatException('Duplicate Bitcoin submission input');
    }
    if (entries.containsKey(key)) {
      if (jsonEncode(entries[key]) != jsonEncode(points)) {
        throw StateError('Bitcoin submission identity mismatch');
      }
      return (false, null);
    }
    final existing = {
      for (final entry in entries.entries)
        if (entry.key.startsWith('${network.id}|'))
          ...List<String>.from(entry.value as List),
    };
    if (points.any(existing.contains)) {
      throw StateError('Bitcoin inputs already have a pending submission');
    }
    if (entries.length >= 1024) {
      throw StateError('Bitcoin submission journal requires reconciliation');
    }
    entries[key] = points;
    final encoded = jsonEncode(value);
    _decode(encoded, identity);
    return (true, encoded);
  });
}
