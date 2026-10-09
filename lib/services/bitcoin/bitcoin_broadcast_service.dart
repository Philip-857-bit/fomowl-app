import 'dart:async';
import '../../src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_signing_service.dart';

enum BitcoinSubmissionStatus { accepted, unknown }

class BitcoinBroadcastOutcome {
  final String txid;
  final BitcoinSubmissionStatus status;
  const BitcoinBroadcastOutcome(this.txid, this.status);
}

class BitcoinBroadcastMismatch implements Exception {
  const BitcoinBroadcastMismatch();
  @override
  String toString() => 'Bitcoin provider returned a different transaction ID';
}

/// One submission per authorized object. Ambiguous transport failures are never retried automatically.
class BitcoinBroadcastService {
  final BitcoinNetworkApi network;
  BitcoinBroadcastService({BitcoinNetworkApi? network})
    : network = network ?? BitcoinNetworkService();
  static final Expando<Future<BitcoinBroadcastOutcome>> _attempts = Expando();
  Future<BitcoinBroadcastOutcome> broadcast(
    BitcoinSignedTransfer signed, {
    required bool Function() isCurrent,
  }) async {
    signed.checkAuthorization();
    if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    final result = await (_attempts[signed] ??= _submit(signed, isCurrent));
    if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    return result;
  }

  Future<BitcoinBroadcastOutcome> _submit(
    BitcoinSignedTransfer signed,
    bool Function() isCurrent,
  ) async {
    final transfer = signed.transfer;
    final transaction = signed.transaction;
    final verified = await verifyBitcoinTransfer(
      plan: transfer.plan,
      rawTransactionHex: transaction.rawTransactionHex,
    );
    if (verified.txid != transaction.txid ||
        verified.wtxid != transaction.wtxid) {
      throw const BitcoinBroadcastMismatch();
    }
    signed.checkAuthorization();
    if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    final firstAttempt = await signed.submissionJournal.reserve(
      transfer.walletIdentity,
      transfer.network,
      transaction.txid,
      transfer.plan.selectedUtxos,
    );
    if (!firstAttempt) {
      return BitcoinBroadcastOutcome(
        transaction.txid,
        BitcoinSubmissionStatus.unknown,
      );
    }
    signed.checkAuthorization();
    if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    String txid;
    try {
      txid = await network.broadcast(
        transfer.walletIdentity,
        transfer.network,
        transaction.rawTransactionHex,
      );
    } on BitcoinNetworkException catch (error) {
      if (error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500 &&
          error.statusCode != 429) {
        rethrow;
      }
      return BitcoinBroadcastOutcome(
        transaction.txid,
        BitcoinSubmissionStatus.unknown,
      );
    } on FormatException {
      return BitcoinBroadcastOutcome(
        transaction.txid,
        BitcoinSubmissionStatus.unknown,
      );
    } on TimeoutException {
      return BitcoinBroadcastOutcome(
        transaction.txid,
        BitcoinSubmissionStatus.unknown,
      );
    }
    if (txid.toLowerCase() != transaction.txid) {
      throw const BitcoinBroadcastMismatch();
    }
    return BitcoinBroadcastOutcome(
      transaction.txid,
      BitcoinSubmissionStatus.accepted,
    );
  }
}
