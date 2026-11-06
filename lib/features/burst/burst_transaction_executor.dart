import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'burst_api_client.dart';
import 'burst_execution_plan.dart';

abstract interface class BurstSubmissionJournal {
  Future<Map<String, String>?> read(String reference);
  Future<void> write(String reference, Map<String, String> entry);
  Future<void> clear(String reference);
}

/// A pre-broadcast marker survives app restarts; unknown submission outcomes are
/// deliberately not retried automatically because the transaction may exist.
class BurstPreferencesJournal implements BurstSubmissionJournal {
  String _key(String reference) => 'burst_submission_v1_$reference';
  @override
  Future<void> clear(String reference) async {
    final removed = await (await SharedPreferences.getInstance()).remove(
      _key(reference),
    );
    if (!removed) {
      throw StateError('Could not clear Burst recovery information.');
    }
  }

  @override
  Future<Map<String, String>?> read(String reference) async {
    final value = (await SharedPreferences.getInstance()).getString(
      _key(reference),
    );
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Invalid Burst recovery record.');
    }
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  @override
  Future<void> write(String reference, Map<String, String> entry) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key(reference),
      jsonEncode(entry),
    );
    if (!saved) throw StateError('Could not save Burst recovery information.');
  }
}

class BurstTransactionResult {
  const BurstTransactionResult({required this.hash, required this.confirmed});
  final String hash;
  final bool confirmed;
}

class BurstUnknownSubmission implements Exception {
  const BurstUnknownSubmission(this.reference);
  final String reference;
  @override
  String toString() =>
      'The previous broadcast outcome is unknown. Find its transaction hash in wallet history to recover it.';
}

class BurstTransactionExecutor {
  BurstTransactionExecutor({
    required this.api,
    required this.journal,
    required this.wallet,
    required this.chainId,
    required this.isCurrent,
    required this.approve,
    required this.broadcast,
    this.verifyBroadcast,
    this.allowNewTransactions = true,
  });
  final BurstApiClient api;
  final BurstSubmissionJournal journal;
  final String wallet;
  final int chainId;
  final Future<bool> Function() isCurrent;
  final Future<bool> Function(BurstExecutionPlan plan) approve;
  final Future<String> Function(BurstExecutionPlan plan) broadcast;
  final Future<bool> Function(BurstExecutionPlan plan, String hash)?
  verifyBroadcast;
  final bool allowNewTransactions;
  bool _busy = false;

  Future<BurstTransactionResult> execute(
    String reference, {
    Map<String, dynamic>? expectedTransaction,
    String? expectedCampaignId,
  }) async {
    if (_busy) throw StateError('A Burst transaction is already in progress.');
    _busy = true;
    try {
      if (!await isCurrent()) {
        throw StateError('The wallet or network changed.');
      }
      final snapshot = await api.execution(reference);
      final status = snapshot['status'];
      final prepared = BurstExecutionPlan.parse(
        snapshot,
        reference: reference,
        wallet: wallet,
        chainId: chainId,
        allowExpired: status == 'submitted' || status == 'confirmed',
      );
      if (expectedTransaction != null) {
        final expected = BurstExecutionPlan.parse(
          {
            'walletAddress': wallet,
            'campaignId': expectedCampaignId,
            'transaction': expectedTransaction,
          },
          reference: reference,
          wallet: wallet,
          chainId: chainId,
          allowExpired: true,
        );
        if (!expected.sameTransaction(prepared)) {
          throw StateError(
            'The Burst transaction no longer matches the reviewed campaign.',
          );
        }
      }
      final saved = await journal.read(reference);
      if (saved != null &&
          (saved['wallet'] != wallet.toLowerCase() ||
              saved['campaignId'] != prepared.campaignId ||
              saved['operation'] != prepared.operation ||
              saved['chainId'] != '$chainId')) {
        throw StateError(
          'Burst recovery information does not match this wallet.',
        );
      }
      final backendHash = snapshot['transactionHash']?.toString();
      final recordedHash = saved?['hash'];
      if (backendHash != null &&
          recordedHash != null &&
          backendHash.toLowerCase() != recordedHash.toLowerCase()) {
        throw StateError('Burst transaction hashes do not match.');
      }
      if (status == 'confirmed') {
        final hash = _validHash(backendHash);
        return BurstTransactionResult(hash: hash, confirmed: true);
      }
      if (status == 'submitted') {
        return _confirm(prepared, _validHash(backendHash));
      }
      if (status != 'prepared') {
        throw StateError('This Burst transaction is unavailable.');
      }
      if (saved != null) {
        if (recordedHash == null) throw BurstUnknownSubmission(reference);
        return _recordAndConfirm(prepared, _validHash(recordedHash));
      }
      if (!allowNewTransactions) {
        throw StateError('Burst is paused. New transactions are unavailable.');
      }
      if (!await approve(prepared)) {
        throw StateError('Burst transaction cancelled.');
      }
      if (!await isCurrent()) {
        throw StateError('The wallet or network changed.');
      }
      final refreshed = await api.execution(reference);
      if (refreshed['status'] != 'prepared') {
        throw StateError(
          'Burst transaction status changed. Refresh before continuing.',
        );
      }
      final current = BurstExecutionPlan.parse(
        refreshed,
        reference: reference,
        wallet: wallet,
        chainId: chainId,
      );
      if (!prepared.sameTransaction(current)) {
        throw StateError('The Burst transaction changed. Review it again.');
      }
      if (!await isCurrent()) {
        throw StateError('The wallet or network changed.');
      }
      final entry = {
        'wallet': wallet.toLowerCase(),
        'chainId': '$chainId',
        'campaignId': current.campaignId,
        'operation': current.operation,
      };
      await journal.write(reference, entry);
      final bool currentWallet;
      try {
        currentWallet = await isCurrent();
      } catch (_) {
        await journal.clear(reference);
        rethrow;
      }
      if (!currentWallet) {
        await journal.clear(reference);
        throw StateError(
          'The wallet or network changed. Select the original wallet and network before retrying.',
        );
      }
      final hash = _validHash(await broadcast(current));
      await journal.write(reference, {...entry, 'hash': hash});
      return _recordAndConfirm(current, hash);
    } finally {
      _busy = false;
    }
  }

  Future<BurstTransactionResult> recoverUnknown(
    String reference,
    String hash, {
    required Map<String, dynamic> expectedTransaction,
    required String expectedCampaignId,
  }) async {
    if (_busy) throw StateError('A Burst transaction is already in progress.');
    _busy = true;
    try {
      if (verifyBroadcast == null || !await isCurrent()) {
        throw StateError('Burst recovery is unavailable for this wallet.');
      }
      final saved = await journal.read(reference);
      if (saved == null ||
          saved['hash'] != null ||
          saved['wallet'] != wallet.toLowerCase() ||
          saved['chainId'] != '$chainId' ||
          saved['campaignId'] != expectedCampaignId) {
        throw StateError('No matching unknown submission can be recovered.');
      }
      final snapshot = await api.execution(reference);
      if (snapshot['status'] != 'prepared') {
        throw StateError(
          'The Burst status changed. Refresh before recovering.',
        );
      }
      final plan = BurstExecutionPlan.parse(
        snapshot,
        reference: reference,
        wallet: wallet,
        chainId: chainId,
      );
      final expected = BurstExecutionPlan.parse(
        {
          'walletAddress': wallet,
          'campaignId': expectedCampaignId,
          'transaction': expectedTransaction,
        },
        reference: reference,
        wallet: wallet,
        chainId: chainId,
        allowExpired: true,
      );
      if (!plan.sameTransaction(expected) ||
          saved['operation'] != plan.operation) {
        throw StateError('The recovery transaction does not match this Burst.');
      }
      final normalized = _validHash(hash.trim());
      if (!await verifyBroadcast!(plan, normalized) || !await isCurrent()) {
        throw StateError(
          'The transaction was not found or does not match this Burst.',
        );
      }
      await journal.write(reference, {...saved, 'hash': normalized});
      return _recordAndConfirm(plan, normalized);
    } finally {
      _busy = false;
    }
  }

  String _validHash(String? value) {
    if (value == null || !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(value)) {
      throw const FormatException('Invalid Burst transaction hash.');
    }
    return value.toLowerCase();
  }

  Future<BurstTransactionResult> _recordAndConfirm(
    BurstExecutionPlan plan,
    String hash,
  ) async {
    await api.recordTransaction(plan.campaignId, plan.operation, false, {
      'transactionHash': hash,
    });
    return _confirm(plan, hash);
  }

  Future<BurstTransactionResult> _confirm(
    BurstExecutionPlan plan,
    String hash,
  ) async {
    final result = await api.recordTransaction(
      plan.campaignId,
      plan.operation,
      true,
      {'transactionHash': hash},
    );
    return BurstTransactionResult(
      hash: hash,
      confirmed: result['status'] == 'confirmed',
    );
  }
}
