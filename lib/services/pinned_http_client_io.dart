import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'spki_pinning.dart';

HttpClient _createConfiguredIoHttpClient() {
  return HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 30);
}

CronetEngine _buildCronetEngine() {
  try {
    // Keep HTTP/2 and Brotli over TCP while disabling QUIC (UDP/443) and
    // Cronet's built-in async DNS resolver. On many 5G carrier CGNAT networks,
    // Wi-Fi routers, and Android Private DNS / VPN setups, QUIC UDP/443 packets
    // or Cronet's internal c-ares DNS resolver stall on every cold start while
    // TCP/443 + Android system DNS works reliably.
    return CronetEngine.build(
      cacheMode: CacheMode.memory,
      cacheMaxSize: 2 * 1024 * 1024,
      enableHttp2: true,
      enableQuic: false,
      enableBrotli: true,
      useBuiltInDnsResolver: false,
    );
  } catch (_) {
    // Older Google Play Services Cronet modules may not support DnsOptions.
    // With enableQuic: false, Cronet already defaults to the system DNS resolver.
    return CronetEngine.build(
      cacheMode: CacheMode.memory,
      cacheMaxSize: 2 * 1024 * 1024,
      enableHttp2: true,
      enableQuic: false,
      enableBrotli: true,
    );
  }
}

http.Client _createNativeTransportClient() {
  if (Platform.isAndroid) {
    try {
      final engine = _buildCronetEngine();
      return ResilientNativeHttpClient(
        CronetClient.fromCronetEngine(engine, closeEngine: true),
      );
    } catch (_) {
      // Fall back to dart:io when Cronet native bindings are unavailable (e.g. tests).
    }
  }
  if (Platform.isIOS || Platform.isMacOS) {
    try {
      final config = URLSessionConfiguration.ephemeralSessionConfiguration()
        ..timeoutIntervalForRequest = const Duration(seconds: 8);
      return ResilientNativeHttpClient(
        CupertinoClient.fromSessionConfiguration(config),
      );
    } catch (_) {
      // Fall back to dart:io when Cupertino bindings are unavailable.
    }
  }
  return IOClient(_createConfiguredIoHttpClient());
}

/// Wraps a native HTTP/2 transport (`CronetClient` on Android,
/// `CupertinoClient` on iOS/macOS) and automatically falls back to `dart:io`
/// [IOClient] (HTTP/1.1) when the native transport fails or times out.
class ResilientNativeHttpClient extends http.BaseClient {
  ResilientNativeHttpClient(
    http.Client native, {
    http.Client Function()? fallbackFactory,
    Duration nativeAttemptTimeout = const Duration(seconds: 4),
  }) : _native = native,
       _fallbackFactory =
           fallbackFactory ?? (() => IOClient(_createConfiguredIoHttpClient())),
       _nativeAttemptTimeout = nativeAttemptTimeout;

  http.Client? _native;
  http.Client? _fallback;
  final http.Client Function() _fallbackFactory;
  final Duration _nativeAttemptTimeout;
  bool _closed = false;

  @visibleForTesting
  bool get isUsingFallback => _native == null;

  http.Client _activeFallback() => _fallback ??= _fallbackFactory();

  void _degradeToFallback([http.Client? failedNative]) {
    final current = failedNative ?? _native;
    if (current != null && identical(_native, current)) {
      _native = null;
      _closeClientSafely(current);
    }
  }

  static void _closeClientSafely(http.Client client) {
    try {
      client.close();
    } on StateError {
      // CupertinoClient.close() throws StateError while a cancelled task's
      // completion callback is still draining. Retry once after it settles.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          try {
            client.close();
          } catch (_) {}
        }),
      );
    } catch (_) {}
  }

  static http.Request? _snapshotRequest(
    http.BaseRequest request, {
    Future<void>? abortTrigger,
  }) {
    if (request is! http.Request) return null;
    final effectiveTrigger =
        abortTrigger ??
        (request is http.Abortable
            ? (request as http.Abortable).abortTrigger
            : null);
    final http.Request copy = effectiveTrigger != null
        ? http.AbortableRequest(
            request.method,
            request.url,
            abortTrigger: effectiveTrigger,
          )
        : http.Request(request.method, request.url);
    copy
      ..headers.addAll(request.headers)
      ..encoding = request.encoding
      ..bodyBytes = request.bodyBytes
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    return copy;
  }

  static bool _isStandardNetworkException(Object error) {
    return error is http.ClientException ||
        error is SocketException ||
        error is TimeoutException ||
        error is TlsException ||
        error is HttpException;
  }

  http.StreamedResponse _wrapNativeStreamedResponse(
    http.Client native,
    http.StreamedResponse response,
    http.BaseRequest originalRequest,
    bool Function() isCallerAborted,
  ) {
    final guardedStream = response.stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) => sink.add(data),
        handleError:
            (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
              if (!isCallerAborted() &&
                  error is! http.RequestAbortedException) {
                _degradeToFallback(native);
              }
              sink.addError(error, stackTrace);
            },
        handleDone: (sink) => sink.close(),
      ),
    );
    return http.StreamedResponse(
      guardedStream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request ?? originalRequest,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) {
      throw http.ClientException(
        'HTTP request failed. Client is already closed.',
        request.url,
      );
    }
    final native = _native;
    if (native == null) {
      return _activeFallback().send(request);
    }

    final abortCompleter = Completer<void>();
    var callerAborted = false;
    if (request case http.Abortable(:final abortTrigger?)) {
      unawaited(
        abortTrigger.whenComplete(() {
          callerAborted = true;
          if (!abortCompleter.isCompleted) {
            abortCompleter.complete();
          }
        }),
      );
    }

    final retryCopy = _snapshotRequest(request);
    final nativeRequest =
        _snapshotRequest(request, abortTrigger: abortCompleter.future) ??
        request;
    if (!identical(nativeRequest, request) && !request.finalized) {
      request.finalize();
    }

    var timedOut = false;
    try {
      final response = await native
          .send(nativeRequest)
          .timeout(
            _nativeAttemptTimeout,
            onTimeout: () {
              timedOut = true;
              if (!abortCompleter.isCompleted) {
                abortCompleter.complete();
              }
              throw TimeoutException(
                'Native HTTP transport timed out waiting for response headers.',
                _nativeAttemptTimeout,
              );
            },
          );
      return _wrapNativeStreamedResponse(
        native,
        response,
        request,
        () => callerAborted,
      );
    } catch (error) {
      if (_closed ||
          callerAborted ||
          (error is http.RequestAbortedException && !timedOut)) {
        rethrow;
      }

      // Immediately demote when the native wrapper threw a non-HTTP binding/JNI
      // error (e.g. GMS-free Android device missing Play Services Cronet) or an
      // explicit QUIC protocol failure (UDP/443 blocked on carrier/Wi-Fi).
      if (!_isStandardNetworkException(error) || error is QuicException) {
        _degradeToFallback(native);
      }

      if (retryCopy == null) {
        rethrow;
      }

      try {
        final fallbackResponse = await _activeFallback().send(retryCopy);
        // The dart:io HTTP/1.1 fallback succeeded where the native HTTP/2/3
        // transport failed or timed out: demote the native transport so future
        // requests use the working fallback directly.
        _degradeToFallback(native);
        return fallbackResponse;
      } catch (_) {
        // Both native and dart:io failed (e.g. device is genuinely offline).
        // Surface the original error.
        rethrow;
      }
    }
  }

  @override
  void close() {
    _closed = true;
    final native = _native;
    _native = null;
    if (native != null) {
      _closeClientSafely(native);
    }
    final fallback = _fallback;
    _fallback = null;
    fallback?.close();
  }
}

/// Builds an [http.Client] that enforces SPKI (public-key) pinning for
/// [pinnedHost] on native (mobile/desktop) platforms.
///
/// Each fingerprint is the hex-encoded SHA-256 of the certificate's
/// DER-encoded SubjectPublicKeyInfo, so the pin survives certificate renewals
/// as long as the server keeps its key pair. Pinning applies only to
/// [pinnedHost]; requests to other hosts (RPC nodes, CoinGecko, swap
/// aggregators, ...) get normal TLS validation. If [sha256Fingerprints] is
/// empty, pinning is disabled and the native HTTP/2 + HTTP/3 transport
/// (`cronet_http` on Android, `cupertino_http` on iOS/macOS) is used.
http.Client createPinnedHttpClient(
  List<String> sha256Fingerprints, {
  required String pinnedHost,
}) {
  final pins = normalizePins(sha256Fingerprints);

  if (pins.isEmpty || pinnedHost.isEmpty) {
    return _createNativeTransportClient();
  }

  return _SpkiPinnedHttpClient(pins, pinnedHost);
}

/// An IO-backed [http.Client] that verifies the server's SPKI hash against a
/// pin set for the pinned host.
///
/// The send implementation mirrors `IOClient.send` from package:http 1.6.0.
/// We cannot wrap [IOClient] itself because it never exposes the underlying
/// [HttpClientResponse.certificate]; `HttpClient.badCertificateCallback` is
/// not sufficient either, since it only fires for certificates that already
/// fail chain validation — a CA-valid man-in-the-middle certificate would
/// never reach it. The pin is checked here on top of normal chain validation:
/// the certificate must be CA-valid AND match a pin.
///
/// Like dio's `validateCertificate`, the check runs once the response headers
/// arrive. Cross-host redirects away from the pinned host fail the pin check
/// by design (an API backend has no business redirecting elsewhere).
class _SpkiPinnedHttpClient extends http.BaseClient {
  _SpkiPinnedHttpClient(this._pins, this._pinnedHost);

  final Set<String> _pins;
  final String _pinnedHost;

  HttpClient? _inner = _createConfiguredIoHttpClient();

  @override
  Future<IOStreamedResponse> send(http.BaseRequest request) async {
    if (_inner == null) {
      throw http.ClientException(
        'HTTP request failed. Client is already closed.',
        request.url,
      );
    }

    var stream = request.finalize();

    try {
      var ioRequest = (await _inner!.openUrl(request.method, request.url))
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..contentLength = (request.contentLength ?? -1)
        ..persistentConnection = request.persistentConnection;
      request.headers.forEach((name, value) {
        ioRequest.headers.set(name, value);
      });

      var isAborted = false;
      var hasResponse = false;

      if (request case http.Abortable(:final abortTrigger?)) {
        unawaited(
          abortTrigger.whenComplete(() {
            isAborted = true;
            if (!hasResponse) {
              ioRequest.abort(http.RequestAbortedException(request.url));
            }
          }),
        );
      }

      final response = await stream.pipe(ioRequest) as HttpClientResponse;
      hasResponse = true;

      _verifyPin(request, response);

      StreamSubscription<List<int>>? ioResponseSubscription;

      late final StreamController<List<int>> responseController;
      responseController = StreamController(
        onListen: () {
          if (isAborted) {
            responseController
              ..addError(http.RequestAbortedException(request.url))
              ..close();
            return;
          } else if (request case http.Abortable(:final abortTrigger?)) {
            abortTrigger.whenComplete(() {
              if (!responseController.isClosed) {
                responseController
                  ..addError(http.RequestAbortedException(request.url))
                  ..close();
              }
              ioResponseSubscription?.cancel();
            });
          }

          ioResponseSubscription = response.listen(
            responseController.add,
            onDone: () {
              ioResponseSubscription = null;
              unawaited(responseController.close());
            },
            onError: (Object err, StackTrace stackTrace) {
              if (err is HttpException) {
                responseController.addError(
                  http.ClientException(err.message, err.uri),
                  stackTrace,
                );
              } else {
                responseController.addError(err, stackTrace);
              }
            },
          );
        },
        onPause: () => ioResponseSubscription?.pause(),
        onResume: () => ioResponseSubscription?.resume(),
        onCancel: () => ioResponseSubscription?.cancel(),
        sync: true,
      );

      var headers = <String, String>{};
      response.headers.forEach((key, values) {
        headers[key] = values.map((value) => value.trimRight()).join(',');
      });

      return IOStreamedResponse(
        responseController.stream,
        response.statusCode,
        contentLength: response.contentLength == -1
            ? null
            : response.contentLength,
        request: request,
        headers: headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
        inner: response,
      );
    } on SocketException catch (error) {
      throw http.ClientException(error.message, request.url);
    } on TlsException catch (error) {
      throw http.ClientException(error.message, request.url);
    } on HttpException catch (error) {
      throw http.ClientException(error.message, error.uri);
    }
  }

  /// Throws [http.ClientException] and tears down the connection when the
  /// response from the pinned host does not carry a pinned public key.
  void _verifyPin(http.BaseRequest request, HttpClientResponse response) {
    final effectiveUrl = response.redirects.isNotEmpty
        ? request.url.resolveUri(response.redirects.last.location)
        : request.url;
    if (request.url.host != _pinnedHost && effectiveUrl.host != _pinnedHost) {
      return;
    }
    // A plain-HTTP backend (local development) has nothing to pin against.
    // Reaching this over HTTPS and landing on plain HTTP is a downgrade and
    // falls through to the failure below via the null certificate.
    if (request.url.scheme == 'http' && effectiveUrl.scheme == 'http') {
      return;
    }

    final certificate = response.certificate;
    if (certificate != null && certMatchesSpkiPins(certificate.der, _pins)) {
      return;
    }

    unawaited(
      response.detachSocket().then<void>(
        (socket) => socket.destroy(),
        onError: (Object _) {},
      ),
    );
    throw http.ClientException(
      'TLS public key for $_pinnedHost does not match the configured '
      'certificate pins.',
      request.url,
    );
  }

  @override
  void close() {
    if (_inner != null) {
      _inner!.close(force: true);
      _inner = null;
    }
  }
}
