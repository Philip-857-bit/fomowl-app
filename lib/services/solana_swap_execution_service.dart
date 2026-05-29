import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../utils/app_error_utils.dart';
import 'solana_swap_service.dart';
import 'wallet_service.dart';

/// Result of a Solana swap execution attempt.
class SolanaSwapExecutionResult {
  final bool success;
  final String? transactionHash;
  final String? error;

  const SolanaSwapExecutionResult({
    required this.success,
    this.transactionHash,
    this.error,
  });
}

/// Handles the sign → broadcast pipeline for Solana swaps.
///
/// The backend already built and returned the unsigned transaction inside
/// [SolanaSwapQuote.swapTransaction] (base64). This service:
///   1. Decodes the base64 transaction bytes.
///   2. Signs the message bytes with the wallet's Ed25519 key via [WalletService].
///   3. Re-encodes the signed transaction as base64.
///   4. POSTs it to the backend via [SolanaSwapService.executeSwap].
class SolanaSwapExecutionService {
  SolanaSwapExecutionService({
    WalletService? walletService,
    SolanaSwapService? swapService,
  }) : _walletService = walletService ?? WalletService(),
       _swapService = swapService ?? SolanaSwapService();

  final WalletService _walletService;
  final SolanaSwapService _swapService;

  Future<SolanaSwapExecutionResult> execute({
    required SolanaSwapQuote quote,
    required String walletAddress,
  }) async {
    try {
      final txBytes = base64Decode(quote.swapTransaction);

      // A Solana transaction wire format starts with a compact-u16 count of
      // signatures followed by the static signature slots, then the message.
      // We need to sign *only* the message portion.
      //
      // compact-u16 encoding: for values 0-127 it's a single byte equal to
      // the value. For 1 signature slot that byte is 0x01, followed by 64
      // zero-bytes for the placeholder.
      //
      // Layout: [compact-u16 sig count][sig slots (64 bytes each)][message...]
      //
      // We parse the compact-u16 header to find where the message begins.
      final sigCount = _readCompactU16(txBytes, 0);
      final sigCountLen = _compactU16ByteLen(txBytes, 0);
      final messageOffset = sigCountLen + sigCount * 64;

      if (messageOffset >= txBytes.length) {
        return const SolanaSwapExecutionResult(
          success: false,
          error: 'Invalid transaction format: message offset out of bounds.',
        );
      }

      final messageBytes = Uint8List.sublistView(txBytes, messageOffset);

      // Sign message bytes with the Ed25519 private key.
      // Returns a base58-encoded 64-byte signature.
      final signatureBase58 = await _walletService.signSolanaMessageRaw(
        walletAddress,
        messageBytes,
      );

      // Decode the base58 signature to raw bytes (64 bytes).
      final signatureBytes = _decodeBase58(signatureBase58);
      if (signatureBytes.length != 64) {
        return SolanaSwapExecutionResult(
          success: false,
          error:
              'Invalid signature length: expected 64 bytes, got ${signatureBytes.length}.',
        );
      }

      // Reconstruct the signed transaction:
      // [compact-u16 = 1][64-byte signature][message]
      final signedTx = Uint8List(sigCountLen + 64 + messageBytes.length);
      // Copy original compact-u16 sig count header (it stays the same)
      signedTx.setRange(0, sigCountLen, txBytes, 0);
      // Write our signature in the first slot
      signedTx.setRange(sigCountLen, sigCountLen + 64, signatureBytes);
      // Write the message
      signedTx.setRange(sigCountLen + 64, signedTx.length, messageBytes);

      final signedTxBase64 = base64Encode(signedTx);

      final txHash = await _swapService.executeSwap(
        signedTransactionBase64: signedTxBase64,
        requestId: quote.requestId,
      );

      if (txHash != null && txHash.isNotEmpty) {
        return SolanaSwapExecutionResult(
          success: true,
          transactionHash: txHash,
        );
      }

      return SolanaSwapExecutionResult(
        success: false,
        error: _swapService.lastError ?? 'Swap execution failed.',
      );
    } catch (e) {
      debugPrint('SolanaSwapExecutionService.execute error: $e');
      return SolanaSwapExecutionResult(
        success: false,
        error: AppErrorUtils.userMessage(
          e,
          fallback: 'Solana swap execution failed. Please try again.',
        ),
      );
    }
  }

  // ── Solana transaction helpers (public statics for reuse) ─────────────────

  /// Public alias used by swap_screen.dart to assemble signed Solana txs.
  static int compactU16ByteLenPublic(Uint8List buf, int offset) =>
      _compactU16ByteLen(buf, offset);

  /// Public alias used by swap_screen.dart to decode base58 signatures.
  static Uint8List decodeBase58Public(String input) => _decodeBase58(input);

  /// Splice a base58-encoded [signatureBase58] into the unsigned transaction
  /// [txBytes] (Solana wire format: compact-u16 signature count, signature
  /// slots, then the message) and return the signed transaction as base64.
  static String assembleSignedTransaction(
    Uint8List txBytes,
    String signatureBase58,
  ) {
    // Decode base58 signature → 64 bytes.
    final sigBytes = decodeBase58Public(signatureBase58);
    // compact-u16 header byte count.
    final sigCountLen = compactU16ByteLenPublic(txBytes, 0);
    final msgOffset = sigCountLen + 64;
    final messageBytes = Uint8List.sublistView(txBytes, msgOffset);
    final signedTx = Uint8List(sigCountLen + 64 + messageBytes.length);
    signedTx.setRange(0, sigCountLen, txBytes, 0);
    signedTx.setRange(sigCountLen, sigCountLen + 64, sigBytes);
    signedTx.setRange(sigCountLen + 64, signedTx.length, messageBytes);
    return base64Encode(signedTx);
  }

  /// Read a compact-u16 value from [buf] starting at [offset].
  /// Solana compact-u16: each byte's low 7 bits contribute; bit 7 signals continuation.
  static int _readCompactU16(Uint8List buf, int offset) {
    int value = 0;
    int shift = 0;
    for (int i = 0; i < 3; i++) {
      final byte = buf[offset + i];
      value |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
    }
    return value;
  }

  /// Return the number of bytes used to encode the compact-u16 at [offset].
  static int _compactU16ByteLen(Uint8List buf, int offset) {
    for (int i = 0; i < 3; i++) {
      if ((buf[offset + i] & 0x80) == 0) return i + 1;
    }
    return 3;
  }

  // Base58 alphabet used by Solana
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  // Precomputed O(1) lookup: char code → base58 digit (-1 = invalid)
  static final Map<int, int> _base58Map = {
    for (int i = 0; i < _base58Alphabet.length; i++)
      _base58Alphabet.codeUnitAt(i): i,
  };

  static Uint8List _decodeBase58(String input) {
    var num = BigInt.zero;
    final base = BigInt.from(58);

    // Single pass: count leading '1's and decode simultaneously
    int leadingZeros = 0;
    bool countingLeading = true;
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if (countingLeading && char == '1') {
        leadingZeros++;
      } else {
        countingLeading = false;
      }
      final digit = _base58Map[char.codeUnitAt(0)] ?? -1;
      if (digit < 0) throw FormatException('Invalid base58 character: $char');
      num = num * base + BigInt.from(digit);
    }

    // Convert BigInt to bytes using add+reversed (O(n) not O(n²))
    final bytes = <int>[];
    final mod = BigInt.from(256);
    while (num > BigInt.zero) {
      bytes.add((num % mod).toInt());
      num ~/= mod;
    }

    final result = Uint8List(leadingZeros + bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      result[leadingZeros + i] = bytes[bytes.length - 1 - i];
    }
    return result;
  }
}
