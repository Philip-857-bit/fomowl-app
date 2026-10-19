import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:web3dart/web3dart.dart';
import '../models/evm_fee_quote.dart';
import '../models/evm_outbound_transaction.dart';
import 'evm_fee_service.dart';
import 'evm_outbound_store.dart';
import 'evm_transaction_service.dart';

class EvmPreparedReplacement {
  final EvmReplacementService _owner;
  final EvmOutboundSnapshot _snapshot;
  final EvmReplacementKind kind;
  final EvmTransactionFields fields;
  final EvmFeeQuote _quote;
  final BigInt oldEstimatedFeeWei;
  final BigInt newEstimatedFeeWei;
  EvmPreparedReplacement._(
    this._owner,
    this._snapshot,
    this.kind,
    this.fields,
    this._quote,
    this.oldEstimatedFeeWei,
    this.newEstimatedFeeWei,
  );
  EvmOutboundTransaction get original => _snapshot.transaction;
  BigInt get additionalEstimatedFeeWei =>
      newEstimatedFeeWei > oldEstimatedFeeWei
      ? newEstimatedFeeWei - oldEstimatedFeeWei
      : BigInt.zero;
  BigInt get maximumFeeWei => fields.maximumFeeWei;
}

class EvmReplacementAvailability {
  final bool pending;
  final bool canCancel;
  const EvmReplacementAvailability({
    required this.pending,
    required this.canCancel,
  });
}

/// Replacements use stored Rust-signed fields, never explorer display rows.
class EvmReplacementService {
  final EvmOutboundStore journal;
  final Web3Client client;
  final Future<String?> Function() currentSender;
  final Future<EvmSigningAccount> Function() openSigner;
  final DateTime Function() now;
  EvmReplacementService({
    required this.journal,
    required this.client,
    required this.currentSender,
    required this.openSigner,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  Future<Object?> _rpc(String method, List<dynamic> params) => client
      .makeRPCCall<Object?>(method, params)
      .timeout(const Duration(seconds: 12));
  Future<void> _current(String sender, bool Function() isCurrent) async {
    if (!isCurrent() ||
        (await currentSender())?.toLowerCase() != sender ||
        !isCurrent()) {
      throw const EvmReplacementException('Wallet or network context changed');
    }
  }

  static BigInt bumped(BigInt original) =>
      ((original * BigInt.from(1125) + BigInt.from(999)) ~/ BigInt.from(1000)) >
          original
      ? (original * BigInt.from(1125) + BigInt.from(999)) ~/ BigInt.from(1000)
      : original + BigInt.one;
  static BigInt _max(BigInt a, BigInt b) => a > b ? a : b;
  Future<void> _pending(EvmOutboundTransaction entry) async {
    final fields = entry.fields;
    final observations = await Future.wait<Object?>([
      _rpc('eth_chainId', []),
      _rpc('eth_getTransactionReceipt', [entry.hash]),
      _rpc('eth_getTransactionByHash', [entry.hash]),
      _rpc('eth_getTransactionCount', [fields.sender, 'latest']),
    ]);
    if (EvmFeeService.quantity(observations[0], bits: 63) !=
        BigInt.from(fields.chainId)) {
      throw const EvmReplacementException(
        'Provider does not match this transaction network',
      );
    }
    if (observations[1] != null ||
        EvmFeeService.quantity(observations[3], bits: 63) >
            BigInt.from(fields.nonce)) {
      throw const EvmReplacementException(
        'The original nonce is already confirmed',
      );
    }
    final tx = observations[2];
    if (tx is! Map<String, dynamic> ||
        !tx.containsKey('blockHash') ||
        !tx.containsKey('blockNumber') ||
        tx['blockHash'] != null ||
        tx['blockNumber'] != null) {
      throw const EvmReplacementException(
        'The original transaction is not observable as pending',
      );
    }
    final type = tx.containsKey('type')
        ? EvmFeeService.quantity(tx['type'])
        : BigInt.zero;
    if (tx['hash']?.toString().toLowerCase() != entry.hash ||
        tx['from']?.toString().toLowerCase() != fields.sender ||
        tx['to']?.toString().toLowerCase() != fields.destination ||
        EvmFeeService.quantity(tx['nonce'], bits: 63) !=
            BigInt.from(fields.nonce) ||
        EvmFeeService.quantity(tx['gas'], bits: 63) !=
            BigInt.from(fields.gasLimit) ||
        EvmFeeService.quantity(tx['value'], bits: 256) != fields.valueWei ||
        tx['input']?.toString().toLowerCase() != fields.dataHex ||
        type != BigInt.from(fields.type == EvmTransactionType.legacy ? 0 : 2) ||
        tx.containsKey('chainId') &&
            EvmFeeService.quantity(tx['chainId'], bits: 63) !=
                BigInt.from(fields.chainId) ||
        (fields.type == EvmTransactionType.legacy
            ? EvmFeeService.quantity(tx['gasPrice']) != fields.gasPriceWei
            : EvmFeeService.quantity(tx['maxFeePerGas']) !=
                      fields.maxFeePerGasWei ||
                  EvmFeeService.quantity(tx['maxPriorityFeePerGas']) !=
                      fields.maxPriorityFeePerGasWei)) {
      throw const EvmReplacementException(
        'Pending transaction does not match saved signing metadata',
      );
    }
  }

  Future<bool> _plainSender(String sender) async =>
      await _rpc('eth_getCode', [sender, 'latest']) == '0x';
  Future<EvmReplacementAvailability> availability(
    String sender,
    int chainId,
    String hash, {
    required bool Function() isCurrent,
  }) async {
    try {
      await _current(sender.toLowerCase(), isCurrent);
      final snapshot = await journal.snapshot(sender, chainId, hash);
      if (snapshot == null || !snapshot.transaction.unresolved) {
        return const EvmReplacementAvailability(
          pending: false,
          canCancel: false,
        );
      }
      await journal.validate(snapshot);
      await _pending(snapshot.transaction);
      bool canCancel = false;
      try {
        canCancel = await _plainSender(sender.toLowerCase());
      } catch (_) {
        /* Cancel is unavailable without positive proof. */
      }
      await _current(sender.toLowerCase(), isCurrent);
      await journal.validate(snapshot);
      return EvmReplacementAvailability(pending: true, canCancel: canCancel);
    } catch (_) {
      return const EvmReplacementAvailability(pending: false, canCancel: false);
    }
  }

  Future<EvmPreparedReplacement> prepare(
    String sender,
    int chainId,
    String hash,
    EvmReplacementKind kind, {
    required bool Function() isCurrent,
  }) async {
    try {
      sender = sender.toLowerCase();
      await _current(sender, isCurrent);
      final snapshot = await journal.snapshot(sender, chainId, hash);
      if (snapshot == null) {
        throw const EvmReplacementException(
          'This transaction has no trusted outbound record',
        );
      }
      await journal.validate(snapshot);
      final original = snapshot.transaction;
      await _pending(original);
      if (kind == EvmReplacementKind.cancel && !await _plainSender(sender)) {
        throw const EvmReplacementException(
          'Cancellation is unavailable for this account',
        );
      }
      final old = original.fields;
      final cancel = kind == EvmReplacementKind.cancel;
      final destination = cancel ? sender : old.destination;
      final value = cancel ? BigInt.zero : old.valueWei;
      final data = Uint8List.fromList(
        HEX.decode((cancel ? '0x' : old.dataHex).substring(2)),
      );
      final observed =
          (await EvmFeeService(rpc: _rpc, rpcScope: client, now: now).quote(
            chainId: chainId,
            sender: sender,
            destination: destination,
            valueWei: value,
            data: data,
          )).forTier(EvmFeeTier.priority);
      if (!cancel && observed.gasLimit > old.gasLimit) {
        throw const EvmReplacementException(
          'Gas requirements changed. This transaction cannot be safely sped up.',
        );
      }
      if (!cancel) {
        final block = await _rpc('eth_getBlockByNumber', ['latest', false]);
        if (block is! Map<String, dynamic> ||
            EvmFeeService.quantity(block['gasLimit'], bits: 63) <
                BigInt.from(old.gasLimit)) {
          throw const EvmReplacementException(
            'The original gas limit exceeds the current block limit',
          );
        }
      }
      final gasLimit = cancel ? observed.gasLimit : old.gasLimit;
      final BigInt? price;
      final BigInt? tip;
      final BigInt? cap;
      if (old.type == EvmTransactionType.legacy) {
        price = _max(bumped(old.gasPriceWei!), observed.effectivePriceWei);
        tip = null;
        cap = null;
      } else {
        if (observed.type != EvmTransactionType.dynamicFee) {
          throw const EvmReplacementException(
            'Dynamic fees are unavailable for this network',
          );
        }
        price = null;
        tip = _max(
          bumped(old.maxPriorityFeePerGasWei!),
          observed.maxPriorityFeePerGasWei!,
        );
        cap = _max(
          bumped(old.maxFeePerGasWei!),
          observed.baseFeePerGasWei! * BigInt.two + tip,
        );
      }
      final quote = EvmFeeQuote(
        intent: observed.intent,
        tier: EvmFeeTier.priority,
        type: old.type,
        gasLimit: gasLimit,
        quotedAt: observed.quotedAt,
        gasPriceWei: price,
        baseFeePerGasWei: price == null ? observed.baseFeePerGasWei : null,
        maxPriorityFeePerGasWei: tip,
        maxFeePerGasWei: cap,
      );
      final fields = EvmTransactionFields(
        chainId: chainId,
        sender: sender,
        nonce: old.nonce,
        destination: destination,
        valueWei: value,
        dataHex: '0x${HEX.encode(data)}',
        gasLimit: gasLimit,
        gasPriceWei: price,
        maxFeePerGasWei: cap,
        maxPriorityFeePerGasWei: tip,
      );
      final base = observed.baseFeePerGasWei ?? BigInt.zero;
      if (fields.effectivePrice(base) <= old.effectivePrice(base)) {
        throw const EvmReplacementException('Replacement fee must be higher');
      }
      final balance = EvmFeeService.quantity(
        await _rpc('eth_getBalance', [sender, 'latest']),
        bits: 256,
      );
      if (balance < value + fields.maximumFeeWei) {
        throw const EvmReplacementException(
          'Insufficient native balance for replacement fees',
        );
      }
      await _current(sender, isCurrent);
      await journal.validate(snapshot);
      quote.requireFresh(now());
      return EvmPreparedReplacement._(
        this,
        snapshot,
        kind,
        fields,
        quote,
        BigInt.from(old.gasLimit) * old.effectivePrice(base),
        BigInt.from(fields.gasLimit) * fields.effectivePrice(base),
      );
    } on EvmReplacementException {
      rethrow;
    } on EvmFeeQuoteException {
      rethrow;
    } catch (_) {
      throw const EvmReplacementException(
        'Unable to prepare replacement. Check transaction status and network.',
      );
    }
  }

  Future<String> submit(
    EvmPreparedReplacement approved, {
    required bool Function() isCurrent,
  }) async {
    if (!identical(approved._owner, this)) {
      throw const EvmReplacementException('Foreign replacement approval');
    }
    final fields = approved.fields;
    EvmSigningAccount? signer;
    EvmOutboundReservation? reservation;
    try {
      await _current(fields.sender, isCurrent);
      await journal.validate(approved._snapshot);
      approved._quote.requireFresh(now());
      await _pending(approved.original);
      if (approved.kind == EvmReplacementKind.cancel &&
          !await _plainSender(fields.sender)) {
        throw const EvmReplacementException(
          'Cancellation is unavailable for this account',
        );
      }
      await _current(fields.sender, isCurrent);
      signer = await openSigner();
      if (signer.address.hex.toLowerCase() != fields.sender ||
          signer.isClosed) {
        throw const EvmReplacementException(
          'Signing account does not match this wallet',
        );
      }
      await _current(fields.sender, isCurrent);
      final hash = await EvmTransactionService.broadcastTransaction(
        client: client,
        account: signer,
        chainId: fields.chainId,
        nonce: fields.nonce,
        to: EthereumAddress.fromHex(fields.destination),
        valueWei: fields.valueWei,
        data: Uint8List.fromList(HEX.decode(fields.dataHex.substring(2))),
        gasLimit: fields.gasLimit,
        gasPriceWei: fields.gasPriceWei,
        maxFeePerGasWei: fields.maxFeePerGasWei,
        maxPriorityFeePerGasWei: fields.maxPriorityFeePerGasWei,
        broadcastTimeout: const Duration(seconds: 20),
        beforeProviderSend: () => journal.beginProviderSend(reservation!),
        validateBeforeSigning: () {
          if (!isCurrent()) {
            throw const EvmReplacementException('Wallet context changed');
          }
          approved._quote.requireFresh(now());
        },
        beforeBroadcast: (signed) async {
          await _current(fields.sender, isCurrent);
          if (!signed.fields.sameAs(fields)) {
            throw const EvmReplacementException(
              'Signed replacement does not match approval',
            );
          }
          await journal.validate(approved._snapshot);
          reservation = await journal.reserve(
            EvmOutboundTransaction(
              fields: signed.fields,
              hash: signed.hash,
              rootHash: approved.original.rootHash,
              replacesHash: approved.original.hash,
              state: EvmOutboundState.unknown,
              createdAt: now(),
            ),
            replacing: approved._snapshot,
          );

          await _current(fields.sender, isCurrent);
        },
        abortedBeforeBroadcast: () async {
          if (reservation != null) {
            await journal.rejectedBeforeProvider(reservation!);
          }
        },
      );
      await journal.submitted(reservation!, hash);
      return hash;
    } on EvmReplacementException {
      rethrow;
    } on EvmFeeQuoteException {
      rethrow;
    } catch (_) {
      throw const EvmReplacementException(
        'Replacement outcome may be unknown. Check its status before trying again.',
      );
    } finally {
      await signer?.close();
    }
  }
}
