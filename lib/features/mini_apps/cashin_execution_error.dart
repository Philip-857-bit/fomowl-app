import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../utils/app_error_utils.dart';

class CashinExecutionRequestException implements Exception {
  const CashinExecutionRequestException(
    this.message, {
    required this.statusCode,
    this.retryAfter,
  });
  final String message;
  final int statusCode;
  final Duration? retryAfter;
  @override
  String toString() => message;
}

class CashinExecutionTransactionFailed implements Exception {
  const CashinExecutionTransactionFailed(this.message);
  final String message;
  @override
  String toString() => message;
}

bool cashinExecutionOutcomeIsUncertain(
  Object error, {
  required String? transactionHash,
  required bool hasSubmittedStep,
}) =>
    error is! CashinExecutionTransactionFailed &&
    (transactionHash != null || hasSubmittedStep);

Duration? cashinExecutionRetryAfter(http.Response response) {
  final value =
      response.headers['retry-after'] ?? response.headers['Retry-After'];
  final seconds = int.tryParse(value?.trim() ?? '');
  return seconds == null || seconds < 0
      ? null
      : Duration(seconds: seconds == 0 ? 1 : seconds);
}

/// Replays only the idempotent registration of an existing transaction hash.
/// The caller must never sign or broadcast inside [submit].
Future<http.Response> submitCashinExecutionResponse(
  Future<http.Response> Function() submit, {
  Future<void> Function(Duration)? wait,
}) async {
  const delays = [
    Duration(milliseconds: 800),
    Duration(milliseconds: 1500),
    Duration(milliseconds: 2500),
    Duration(seconds: 4),
  ];
  final pause = wait ?? (duration) => Future<void>.delayed(duration);
  for (var attempt = 0; ; attempt++) {
    try {
      final response = await submit();
      String? code;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          code = (decoded['code'] ?? decoded['error'])
              ?.toString()
              .trim()
              .toUpperCase();
        }
      } catch (_) {
        /* Non-JSON errors still use their HTTP status. */
      }
      final retryable =
          response.statusCode == 429 ||
          response.statusCode >= 500 ||
          (response.statusCode == 409 && code == 'TRANSACTION_NOT_FOUND');
      if (!retryable || attempt == delays.length) return response;
      final requested = cashinExecutionRetryAfter(response);
      // Long throttles stay pending rather than holding the wallet indefinitely.
      if (requested != null && requested > const Duration(seconds: 30)) {
        return response;
      }
      await pause(requested ?? delays[attempt]);
    } on SocketException {
      if (attempt == delays.length) rethrow;
      await pause(delays[attempt]);
    } on TimeoutException {
      if (attempt == delays.length) rethrow;
      await pause(delays[attempt]);
    }
  }
}

/// Use only for execution-plan GETs. It never submits or recreates a payment.
Future<http.Response> readCashinExecutionResponse(
  Future<http.Response> Function() read, {
  Future<void> Function(Duration)? wait,
}) async {
  final response = await read();
  final retryAfter = cashinExecutionRetryAfter(response);
  if (response.statusCode != 429 ||
      retryAfter == null ||
      retryAfter > const Duration(seconds: 30)) {
    return response;
  }
  await (wait ?? (duration) => Future<void>.delayed(duration))(retryAfter);
  return read();
}

String cashinExecutionErrorMessage(Object error, {bool? isTransfer}) {
  if (error is CashinExecutionRequestException && error.statusCode == 429) {
    final seconds = error.retryAfter?.inSeconds;
    return seconds == null
        ? 'OwlletPay is busy. Please try again shortly.'
        : 'OwlletPay is busy. Please wait $seconds ${seconds == 1 ? 'second' : 'seconds'} and try again.';
  }
  final operation = isTransfer == true ? 'Transfer' : 'Payment';
  return '$operation could not continue: ${AppErrorUtils.userMessage(error)}';
}
