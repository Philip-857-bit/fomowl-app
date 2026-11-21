import 'dart:async';
import 'dart:convert';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/http_client_service.dart';
import 'package:fomowl_wallet/services/pinned_http_client_io.dart';
import 'package:http/http.dart' as http;

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler, {this.onClose});

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;
  final void Function()? onClose;
  int sendCount = 0;
  bool closed = false;
  final List<http.BaseRequest> capturedRequests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sendCount++;
    capturedRequests.add(request);
    return _handler(request);
  }

  @override
  void close() {
    closed = true;
    onClose?.call();
  }
}

http.StreamedResponse _jsonResponse(
  String body, {
  int statusCode = 200,
  http.BaseRequest? request,
}) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    contentLength: bytes.length,
    request: request,
    headers: const {'content-type': 'application/json'},
  );
}

void main() {
  final testUri = Uri.parse('https://core.owlletapp.com/api/config/runtime');

  group('ResilientNativeHttpClient protocol fallback', () {
    test(
      'falls back to dart:io client and demotes native client when Cronet/Cupertino throws ClientException',
      () async {
        final native = _FakeHttpClient((request) async {
          throw CronetException('net::ERR_NAME_NOT_RESOLVED', request.url);
        });
        final fallback = _FakeHttpClient((request) async {
          return _jsonResponse('{"ok":true}', request: request);
        });

        final client = ResilientNativeHttpClient(
          native,
          fallbackFactory: () => fallback,
        );

        final firstResponse = await client.post(
          testUri,
          headers: const {'x-test': '1'},
          body: '{"hello":"world"}',
        );

        expect(firstResponse.statusCode, 200);
        expect(firstResponse.body, '{"ok":true}');
        expect(native.sendCount, 1);
        expect(native.closed, isTrue);
        expect(fallback.sendCount, 1);
        expect(client.isUsingFallback, isTrue);

        final fallbackRequest =
            fallback.capturedRequests.single as http.Request;
        expect(fallbackRequest.method, 'POST');
        expect(fallbackRequest.headers['x-test'], '1');
        expect(fallbackRequest.body, '{"hello":"world"}');

        // Subsequent requests go directly to fallback without touching native.
        final secondResponse = await client.get(testUri);
        expect(secondResponse.statusCode, 200);
        expect(native.sendCount, 1);
        expect(fallback.sendCount, 2);
      },
    );

    test(
      'aborts hung native HTTP/3 request on timeout and falls back to dart:io client',
      () async {
        var nativeRequestAborted = false;
        final native = _FakeHttpClient((request) {
          if (request case http.Abortable(:final abortTrigger?)) {
            abortTrigger.whenComplete(() {
              nativeRequestAborted = true;
            });
          }
          // Simulate a blackholed UDP/443 QUIC handshake that never completes.
          return Completer<http.StreamedResponse>().future;
        });
        final fallback = _FakeHttpClient((request) async {
          return _jsonResponse('{"fallback":true}', request: request);
        });

        final client = ResilientNativeHttpClient(
          native,
          fallbackFactory: () => fallback,
          nativeAttemptTimeout: const Duration(milliseconds: 40),
        );

        final response = await client.get(testUri);

        expect(response.statusCode, 200);
        expect(response.body, '{"fallback":true}');
        expect(nativeRequestAborted, isTrue);
        expect(native.closed, isTrue);
        expect(client.isUsingFallback, isTrue);
        expect(fallback.sendCount, 1);
      },
    );

    test(
      'keeps native transport active when both native and fallback fail while device is offline',
      () async {
        var offline = true;
        final native = _FakeHttpClient((request) async {
          if (offline) {
            throw http.ClientException('Network unreachable', request.url);
          }
          return _jsonResponse('{"native":true}', request: request);
        });
        final fallback = _FakeHttpClient((request) async {
          if (offline) {
            throw http.ClientException('Network unreachable', request.url);
          }
          return _jsonResponse('{"fallback":true}', request: request);
        });

        final client = ResilientNativeHttpClient(
          native,
          fallbackFactory: () => fallback,
        );

        await expectLater(
          () => client.get(testUri),
          throwsA(isA<http.ClientException>()),
        );
        expect(native.sendCount, 1);
        expect(fallback.sendCount, 1);
        expect(client.isUsingFallback, isFalse);
        expect(native.closed, isFalse);

        // Once connectivity recovers, native transport still works.
        offline = false;
        final recovered = await client.get(testUri);
        expect(recovered.body, '{"native":true}');
        expect(native.sendCount, 2);
        expect(fallback.sendCount, 1);
      },
    );

    test(
      'demotes native transport on mid-stream body error so HttpClientService.sendWithRetry succeeds via fallback',
      () async {
        final native = _FakeHttpClient((request) async {
          final controller = StreamController<List<int>>()
            ..add(utf8.encode('{"partial":'))
            ..addError(
              CronetException('net::ERR_QUIC_PROTOCOL_ERROR', request.url),
            )
            ..close();
          return http.StreamedResponse(
            controller.stream,
            200,
            request: request,
          );
        });
        final fallback = _FakeHttpClient((request) async {
          return _jsonResponse('{"retried":"ok"}', request: request);
        });

        final client = ResilientNativeHttpClient(
          native,
          fallbackFactory: () => fallback,
        );
        final service = HttpClientService.internal();

        final response = await service.sendWithRetry(
          () => client.get(testUri),
          maxRetries: 2,
          delay: Duration.zero,
        );

        expect(response.statusCode, 200);
        expect(response.body, '{"retried":"ok"}');
        expect(client.isUsingFallback, isTrue);
        expect(native.sendCount, 1);
        expect(fallback.sendCount, 1);
      },
    );

    test(
      'does not fall back or demote native transport when caller aborts request',
      () async {
        final abortCompleter = Completer<void>();
        final native = _FakeHttpClient((request) {
          final completer = Completer<http.StreamedResponse>();
          if (request case http.Abortable(:final abortTrigger?)) {
            abortTrigger.whenComplete(() {
              if (!completer.isCompleted) {
                completer.completeError(
                  http.RequestAbortedException(request.url),
                );
              }
            });
          }
          return completer.future;
        });
        final fallback = _FakeHttpClient((request) async {
          return _jsonResponse('{"fallback":true}', request: request);
        });

        final client = ResilientNativeHttpClient(
          native,
          fallbackFactory: () => fallback,
        );

        final request = http.AbortableRequest(
          'GET',
          testUri,
          abortTrigger: abortCompleter.future,
        );
        final sendFuture = client.send(request);
        abortCompleter.complete();

        await expectLater(
          sendFuture,
          throwsA(isA<http.RequestAbortedException>()),
        );
        expect(fallback.sendCount, 0);
        expect(client.isUsingFallback, isFalse);
      },
    );

    test(
      'retries closing native client when close throws StateError while tasks drain',
      () async {
        var closeAttempts = 0;
        final native = _FakeHttpClient(
          (request) async => throw StateError('Native JNI failure'),
          onClose: () {
            closeAttempts++;
            if (closeAttempts == 1) {
              throw StateError('cannot close with running requests');
            }
          },
        );
        final fallback = _FakeHttpClient((request) async {
          return _jsonResponse('{"ok":true}', request: request);
        });

        final client = ResilientNativeHttpClient(
          native,
          fallbackFactory: () => fallback,
        );

        final response = await client.get(testUri);
        expect(response.statusCode, 200);
        expect(closeAttempts, 1);

        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(closeAttempts, 2);
      },
    );
  });
}
