import 'dart:convert';

class AppErrorUtils {
  AppErrorUtils._();

  static String userMessage(
    Object? error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final raw = _normalize(error);
    if (raw.isEmpty) return fallback;

    final lowered = raw.toLowerCase();

    if (_containsAny(lowered, const [
      'socketexception',
      'timed out',
      'timeout',
      'failed host lookup',
      'connection refused',
      'network is unreachable',
      'no address associated',
    ])) {
      return 'Connection failed. Please check your internet and try again.';
    }

    if (_containsAny(lowered, const [
      '401',
      '403',
      'wallet session',
      'challenge',
      'signature',
      'authentication',
      'authorization',
      'unauthorized',
      'forbidden',
    ])) {
      return 'Authentication failed. Please try again.';
    }

    if (_containsAny(lowered, const [
      '429',
      'rate limit',
      'too many requests',
    ])) {
      return 'Too many requests right now. Please try again shortly.';
    }

    if (_containsAny(lowered, const [
      'invalid mnemonic',
      'invalid private key',
      'amount is required',
      'invalid amount format',
      'supports up to',
    ])) {
      return raw;
    }

    if (_containsAny(lowered, const [
      'unexpected end of input',
      'unexpected character',
      'invalid portfolio response payload',
      'response was incomplete',
      'response was malformed',
      'invalid json',
    ])) {
      return fallback;
    }

    if (_containsAny(lowered, const [
      'type \'string\' is not a subtype of type \'int\' of \'index\'',
      'type \'string\' is not a subtype of type \'int\'',
    ])) {
      return 'Transaction reverted or failed. Please check your balance or slippage and try again.';
    }

    if (_containsAny(lowered, const [
      'backend',
      'database',
      'sql',
      'rpc',
      'provider',
      'upstream',
      'response was incomplete',
      'response was malformed',
    ])) {
      return fallback;
    }

    if (_containsSensitiveEndpoint(raw, lowered)) {
      return fallback;
    }

    return raw.length > 160 ? fallback : raw;
  }

  static String backendMessage(String? body, {required String fallback}) {
    if (body == null || body.trim().isEmpty) return fallback;
    final lowered = body.toLowerCase();
    if (_containsAny(lowered, const [
      'challenge',
      'signature',
      'wallet session',
      'backend',
      'database',
      'internal',
      'sql',
      'rpc',
      'provider',
    ])) {
      return fallback;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          // Run the extracted message through the same sanitisation pipeline
          // used for all user-visible error strings so that internal infra
          // details (e.g. "dial tcp 10.0.0.5:5432: connection refused") are
          // never exposed to users.
          return userMessage(message, fallback: fallback);
        }
      }
    } catch (_) {}
    return fallback;
  }

  static String _normalize(Object? error) {
    if (error == null) return '';
    var text = error.toString().trim();
    if (text.startsWith('Exception:')) {
      text = text.substring('Exception:'.length).trim();
    }
    if (text.startsWith('FormatException:')) {
      text = text.substring('FormatException:'.length).trim();
    }
    return text;
  }

  static bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }

  static bool _containsSensitiveEndpoint(String raw, String lowered) {
    final hasUrl = RegExp(r'https?://', caseSensitive: false).hasMatch(raw);
    final hasLocalHost = _containsAny(lowered, const [
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '10.0.3.2',
      'onrender.com',
    ]);
    final hasInfraShape = RegExp(
      r'\b\d{1,3}(\.\d{1,3}){3}:\d+\b',
    ).hasMatch(raw);

    return hasUrl || hasLocalHost || hasInfraShape;
  }
}
