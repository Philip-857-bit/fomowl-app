import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/services/currency_controller.dart';
import 'package:fomowl_wallet/services/http_client_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/utils/value_formatter.dart';

class CurrencyStorage extends StorageService {
  String code = 'USD';
  @override
  Future<String> getCurrency() async => code;
  @override
  Future<void> setCurrency(String value) async {
    code = value;
  }
}

class CurrencyHttp extends HttpClientService {
  CurrencyHttp(this.response) : super.internal();
  final http.Client response;
  @override
  http.Client get client => response;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    ValueFormatter.setCurrencyCode('USD');
    ValueFormatter.updateUsdConversionRates({'USD': 1});
  });
  test('USD is usable by default without a currency-rate request', () {
    final controller = CurrencyController(storage: CurrencyStorage());
    expect(controller.currencyCode, 'USD');
    expect(controller.amountInputUsdRate, '1');
  });
  test(
    'live selected currency persists, expires and never uses static display fallback',
    () async {
      final store = CurrencyStorage();
      var now = DateTime.utc(2026, 10, 19);
      var available = true;
      final client = CurrencyHttp(
        MockClient(
          (_) async => available
              ? http.Response(
                  jsonEncode({
                    'rates': {'NGN': 1500, 'EUR': 0.9, 'GBP': 0.8},
                  }),
                  200,
                )
              : http.Response('{}', 503),
        ),
      );
      final controller = CurrencyController(
        storage: store,
        httpClient: client,
        now: () => now,
      );
      await controller.setCurrencyCode('NGN');
      expect(store.code, 'NGN');
      expect(controller.amountInputUsdRate, '1500.0');
      now = now.add(const Duration(minutes: 31));
      expect(controller.amountInputUsdRate, isNull);
      available = false;
      final reopened = CurrencyController(
        storage: store,
        httpClient: client,
        now: () => now,
      );
      await reopened.init();
      expect(reopened.currencyCode, 'NGN');
      expect(reopened.amountInputUsdRate, isNull);
      // Existing portfolio display can still use its prior last-resort rate.
      expect(ValueFormatter.currencyCode, 'NGN');
      await reopened.setCurrencyCode('USD');
      expect(reopened.amountInputUsdRate, '1');
    },
  );
  test(
    'Send refresh coalesces expired rates and bounds outage retries',
    () async {
      var now = DateTime.utc(2026, 10, 19);
      var available = true;
      var calls = 0;
      var notifications = 0;
      final store = CurrencyStorage()..code = 'NGN';
      final client = CurrencyHttp(
        MockClient((_) async {
          calls++;
          return available
              ? http.Response(
                  jsonEncode({
                    'rates': {'NGN': 1550, 'EUR': 0.9, 'GBP': 0.8},
                  }),
                  200,
                )
              : http.Response('{}', 503);
        }),
      );
      final controller = CurrencyController(
        storage: store,
        httpClient: client,
        now: () => now,
      );
      await controller.init();
      controller.addListener(() => notifications++);
      expect(calls, 1);
      now = now.add(const Duration(minutes: 31));
      expect(controller.amountInputUsdRate, isNull);
      await Future.wait([
        controller.refreshAmountInputRates(),
        controller.refreshAmountInputRates(),
      ]);
      expect(calls, 2);
      expect(notifications, 1);
      expect(controller.amountInputUsdRate, '1550.0');
      now = now.add(const Duration(minutes: 31));
      available = false;
      await controller.refreshAmountInputRates();
      expect(controller.amountInputUsdRate, isNull);
      expect(calls, 4);
      await controller.refreshAmountInputRates();
      expect(calls, 4);
      now = now.add(const Duration(minutes: 1));
      available = true;
      await controller.refreshAmountInputRates();
      expect(calls, 5);
      expect(controller.amountInputUsdRate, '1550.0');
      controller.dispose();
    },
  );
}
