import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/value_formatter.dart';
import 'http_client_service.dart';
import 'storage_service.dart';

class CurrencyController extends ChangeNotifier {
  CurrencyController({StorageService? storage, HttpClientService? httpClient})
    : _storage = storage ?? StorageService(),
      _httpClient = httpClient ?? HttpClientService();

  final StorageService _storage;
  final HttpClientService _httpClient;

  static const _supportedCurrencies = {'USD', 'EUR', 'GBP', 'NGN'};
  static const _frankfurterBaseUrl = 'https://api.frankfurter.dev/v1/latest';

  String _currencyCode = 'USD';
  bool _initialized = false;

  String get currencyCode => _currencyCode;
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    final stored = await _storage.getCurrency();
    final normalizedStored = stored.trim().toUpperCase();
    _currencyCode = _supportedCurrencies.contains(normalizedStored)
        ? normalizedStored
        : 'USD';
    ValueFormatter.setCurrencyCode(_currencyCode);
    await _refreshRates();
    _initialized = true;
    notifyListeners();
  }

  Future<void> setCurrencyCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty || normalized == _currencyCode) return;
    if (!_supportedCurrencies.contains(normalized)) return;
    _currencyCode = normalized;
    await _refreshRates();
    ValueFormatter.setCurrencyCode(normalized);
    notifyListeners();
    await _storage.setCurrency(normalized);
  }

  Future<void> _refreshRates() async {
    try {
      final symbols = _supportedCurrencies
          .where((code) => code != 'USD')
          .join(',');
      final uri = Uri.parse(
        _frankfurterBaseUrl,
      ).replace(queryParameters: {'base': 'USD', 'symbols': symbols});
      final response = await _httpClient.client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return;
      }

      final decoded = jsonDecode(response.body);
      final rates = <String, double>{'USD': 1.0};
      if (decoded is Map<String, dynamic>) {
        final rawRates = decoded['rates'];
        if (rawRates is Map<String, dynamic>) {
          for (final entry in rawRates.entries) {
            final value = entry.value;
            if (value is num) {
              rates[entry.key.toUpperCase()] = value.toDouble();
            }
          }
        }
      }
      ValueFormatter.updateUsdConversionRates(rates);
    } catch (_) {
      // Keep the last known rates or the default USD-only fallback.
    }
  }
}
