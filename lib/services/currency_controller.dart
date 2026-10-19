import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/value_formatter.dart';
import 'http_client_service.dart';
import 'storage_service.dart';

class CurrencyController extends ChangeNotifier {
  CurrencyController({
    StorageService? storage,
    HttpClientService? httpClient,
    DateTime Function()? now,
  }) : _storage = storage ?? StorageService(),
       _httpClient = httpClient ?? HttpClientService(),
       _now = now ?? DateTime.now;

  final StorageService _storage;
  final HttpClientService _httpClient;
  final DateTime Function() _now;

  static const _supportedCurrencies = {'USD', 'EUR', 'GBP', 'NGN'};
  static const _exchangeRatesBaseUrl = 'https://api.frankfurter.dev/v1/latest';
  static const _exchangeRateApiBaseUrl =
      'https://open.er-api.com/v6/latest/USD';
  static const _staticFallbackRates = <String, double>{
    'USD': 1.0,
    'NGN': 1600.0,
    'EUR': 0.92,
    'GBP': 0.79,
  };

  String _currencyCode = 'USD';
  bool _initialized = false;
  Map<String, double> _inputRates = const {'USD': 1};
  DateTime? _inputRatesObservedAt;
  DateTime? _lastRateRefreshAttempt;
  Future<void>? _amountRateRefresh;

  /// Just-in-time refresh for Send, coalesced and bounded during an outage.
  Future<void> refreshAmountInputRates() {
    if (!_initialized || amountInputUsdRate != null) return Future.value();
    final pending = _amountRateRefresh;
    if (pending != null) return pending;
    final last = _lastRateRefreshAttempt;
    if (last != null &&
        _now().toUtc().difference(last) < const Duration(minutes: 1)) {
      return Future.value();
    }
    return _amountRateRefresh = _refreshRates().whenComplete(() {
      _amountRateRefresh = null;
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  /// Static display fallbacks must never determine a transaction amount.
  String? get amountInputUsdRate {
    if (_currencyCode == 'USD') return '1';
    final observed = _inputRatesObservedAt;
    final rate = _inputRates[_currencyCode];
    if (observed == null ||
        _now().toUtc().difference(observed) > const Duration(minutes: 30) ||
        rate == null ||
        !rate.isFinite ||
        rate <= 0) {
      return null;
    }
    return rate.toString();
  }

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
    await _refreshRates();
    _currencyCode = normalized;
    ValueFormatter.setCurrencyCode(normalized);
    notifyListeners();
    await _storage.setCurrency(normalized);
  }

  Future<void> _refreshRates() async {
    _lastRateRefreshAttempt = _now().toUtc();
    final rates = <String, double>{'USD': 1.0};
    try {
      rates.addAll(await _fetchFrankfurterRates());
    } catch (_) {
      // Fall through to the secondary live source.
    }

    if (_hasMissingRates(rates)) {
      try {
        final secondaryRates = await _fetchExchangeRateApiRates();
        for (final entry in secondaryRates.entries) {
          rates.putIfAbsent(entry.key, () => entry.value);
        }
      } catch (_) {
        // Fall through to static last-resort values.
      }
    }

    _inputRates = Map.unmodifiable(rates);
    _inputRatesObservedAt = _now().toUtc();
    for (final entry in _staticFallbackRates.entries) {
      rates.putIfAbsent(entry.key, () => entry.value);
    }

    ValueFormatter.updateUsdConversionRates(rates);
  }

  Future<Map<String, double>> _fetchFrankfurterRates() async {
    final targets = _supportedCurrencies
        .where((code) => code != 'USD')
        .join(',');
    final uri = Uri.parse('$_exchangeRatesBaseUrl?base=USD&symbols=$targets');
    final response = await _httpClient.client
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      return const <String, double>{};
    }

    final decoded = jsonDecode(response.body);
    return _extractRates(decoded);
  }

  Future<Map<String, double>> _fetchExchangeRateApiRates() async {
    final uri = Uri.parse(_exchangeRateApiBaseUrl);
    final response = await _httpClient.client
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      return const <String, double>{};
    }

    final decoded = jsonDecode(response.body);
    return _extractRates(decoded);
  }

  Map<String, double> _extractRates(dynamic decoded) {
    final rates = <String, double>{};
    if (decoded is! Map<String, dynamic>) {
      return rates;
    }

    final rawRates = decoded['rates'];
    if (rawRates is! Map) {
      return rates;
    }

    for (final code in _supportedCurrencies) {
      if (code == 'USD') continue;
      final value = rawRates[code];
      if (value is num && value.isFinite && value > 0) {
        rates[code] = value.toDouble();
      }
    }
    return rates;
  }

  bool _hasMissingRates(Map<String, double> rates) {
    return _supportedCurrencies.any(
      (code) => !rates.containsKey(code) || rates[code]! <= 0,
    );
  }
}
