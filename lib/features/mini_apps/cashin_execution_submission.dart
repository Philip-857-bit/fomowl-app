import 'dart:convert';

import '../../services/secure_store.dart';

String cashinExecutionSubmissionKey({
  required String reference,
  required String routeId,
  required String stepId,
  required String walletAddress,
  required int chainId,
}) =>
    'cashin.execution.v1:${jsonEncode([reference, routeId, stepId, walletAddress.toLowerCase(), chainId])}';

String cashinExecutionSubmissionContextKey({
  required String reference,
  required String routeId,
  required String walletAddress,
}) =>
    'cashin.execution.context.v1:${jsonEncode([reference, routeId, walletAddress.toLowerCase()])}';

class CashinExecutionPendingException implements Exception {
  const CashinExecutionPendingException(this.transactionHash, this.cause);
  final String transactionHash;
  final Object cause;

  @override
  String toString() =>
      'This transaction is awaiting verification. Check its receipt before sending again.';
}

/// Stores only public hashes, never signatures or signed transaction bytes.
/// Reservations are retained even after recording: a stale plan cannot resend.
class CashinExecutionSubmission {
  CashinExecutionSubmission([this._store = const FlutterSecureStoreAdapter()]);
  final SecureStore _store;
  static final _active = <String, Future<String>>{};
  static final _hashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');

  Future<String?> savedHash(String key) async {
    final hash = await _store.read(key: key);
    if (hash != null && !_hashPattern.hasMatch(hash)) {
      throw StateError(
        'The saved transaction reference needs review before retrying.',
      );
    }
    return hash;
  }

  Future<String> run({
    required String key,
    String? contextKey,
    required Future<String> Function(
      Future<void> Function(String) beforeBroadcast,
      Future<void> Function() abortedBeforeBroadcast,
    )
    broadcast,
    required Future<void> Function(String) record,
  }) {
    final active = _active[key];
    if (active != null) return active;
    final operation = _run(key, contextKey, broadcast, record);
    _active[key] = operation;
    return operation.whenComplete(() => _active.remove(key));
  }

  Future<String> _run(
    String key,
    String? contextKey,
    Future<String> Function(
      Future<void> Function(String),
      Future<void> Function(),
    )
    broadcast,
    Future<void> Function(String) record,
  ) async {
    String? hash = await savedHash(key);
    final priorContextHash = contextKey == null
        ? null
        : await savedHash(contextKey);
    try {
      if (hash == null) {
        final returned = await broadcast(
          (preparedHash) async {
            if (!_hashPattern.hasMatch(preparedHash)) {
              throw const FormatException('Invalid prepared transaction hash.');
            }
            // This write must succeed BEFORE the provider receives signed bytes.
            await _store.write(key: key, value: preparedHash);
            if (await _store.read(key: key) != preparedHash) {
              throw StateError('Unable to save this transaction safely.');
            }
            hash = preparedHash;
            if (contextKey != null) {
              await _store.write(key: contextKey, value: preparedHash);
              if (await _store.read(key: contextKey) != preparedHash) {
                throw StateError(
                  'Unable to save the payment recovery reference.',
                );
              }
            }
          },
          () async {
            // Called only when the signing service proves no provider send occurred.
            await _store.delete(key: key);
            if (await _store.read(key: key) != null) {
              throw StateError(
                'Unable to release the transaction reservation.',
              );
            }
            hash = null;
            if (contextKey != null) {
              if (priorContextHash == null) {
                await _store.delete(key: contextKey);
              } else {
                await _store.write(key: contextKey, value: priorContextHash);
              }
            }
          },
        );
        if (hash == null || returned.toLowerCase() != hash!.toLowerCase()) {
          throw StateError(
            'The provider returned a different transaction hash.',
          );
        }
      }
      await record(hash!);
      return hash!;
    } catch (error) {
      if (hash != null) throw CashinExecutionPendingException(hash!, error);
      rethrow;
    }
  }
}
