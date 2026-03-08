import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/services/push_notification_registration_service.dart';
import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_backend_auth_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationRegistrationService', () {
    late StorageService storage;
    late _InMemorySecureStore secureStore;
    late _FakeMessagingClient messagingClient;
    late _RecordingHttpClient httpClient;
    late PushNotificationRegistrationService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secureStore = _InMemorySecureStore();
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(
        secureStore: secureStore,
        sharedPreferences: prefs,
      );
      messagingClient = _FakeMessagingClient(token: 'token-1234567890');
      httpClient = _RecordingHttpClient();
      service = PushNotificationRegistrationService(
        storageService: storage,
        walletService: _FakeWalletService(
          address: '0x1234567890123456789012345678901234567890',
        ),
        walletBackendAuthService: _FakeWalletBackendAuthService(),
        messagingClient: messagingClient,
        httpClient: httpClient,
        appVersionProvider: () async => '1.2.0+5',
        pushNotificationsEnabled: true,
      );
    });

    test('registers device token and caches registration', () async {
      await service.syncForActiveWallet();

      expect(httpClient.requests, hasLength(1));
      final request = httpClient.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/notifications/devices/register');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['deviceToken'], 'token-1234567890');
      expect(body['appVersion'], '1.2.0+5');

      final stored = await storage.getNotificationDeviceRegistration(
        '0x1234567890123456789012345678901234567890',
      );
      expect(stored, isNotNull);
      expect(stored!['token'], 'token-1234567890');
      expect(stored['appVersion'], '1.2.0+5');
    });

    test('skips registration when cached token and version match', () async {
      await service.syncForActiveWallet();
      await service.syncForActiveWallet();

      expect(httpClient.requests, hasLength(1));
    });

    test('unregisters old token before registering new one', () async {
      await service.syncForActiveWallet();
      messagingClient.token = 'token-0987654321';

      await service.syncForActiveWallet();

      expect(httpClient.requests, hasLength(3));
      expect(
        httpClient.requests[1].url.path,
        '/api/notifications/devices/unregister',
      );
      expect(
        httpClient.requests[2].url.path,
        '/api/notifications/devices/register',
      );
    });
  });
}

class _FakeMessagingClient implements PushMessagingClient {
  _FakeMessagingClient({required this.token});

  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  String? token;

  @override
  Stream<String> get onTokenRefresh => _controller.stream;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async => true;
}

class _FakeWalletService extends WalletService {
  _FakeWalletService({required this.address});

  final String address;

  @override
  Future<String?> getCurrentWalletAddress() async => address;
}

class _FakeWalletBackendAuthService extends WalletBackendAuthService {
  _FakeWalletBackendAuthService() : super();

  @override
  Future<http.Response> sendAuthorized(
    String walletAddress,
    Future<http.Response> Function(Map<String, String> headers) send,
    Map<String, String> headers,
  ) {
    return send({...headers, 'Authorization': 'Bearer test-token'});
  }
}

class _RecordingHttpClient extends http.BaseClient {
  final List<_CapturedRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final streamedRequest = request as http.Request;
    requests.add(
      _CapturedRequest(
        method: streamedRequest.method,
        url: streamedRequest.url,
        body: streamedRequest.body,
        headers: Map<String, String>.from(streamedRequest.headers),
      ),
    );
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"success":true}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.url,
    required this.body,
    required this.headers,
  });

  final String method;
  final Uri url;
  final String body;
  final Map<String, String> headers;
}

class _InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}
