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

Duration? cashinExecutionRetryAfter(http.Response response) {
  final value =
      response.headers['retry-after'] ?? response.headers['Retry-After'];
  final seconds = int.tryParse(value?.trim() ?? '');
  return seconds == null || seconds < 0
      ? null
      : Duration(seconds: seconds == 0 ? 1 : seconds);
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
