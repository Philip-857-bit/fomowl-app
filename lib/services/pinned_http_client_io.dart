import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'spki_pinning.dart';

HttpClient _createConfiguredIoHttpClient() {
  return HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 30);
}

http.Client _createNativeTransportClient() {
  if (Platform.isAndroid) {
    try {
      final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
        enableHttp2: true,
        enableQuic: true,
        enableBrotli: true,
      );
      return _ResilientNativeHttpClient(
        CronetClient.fromCronetEngine(engine, closeEngine: true),
      );
    } catch (_) {
      // Fall back to dart:io when Cronet native bindings are unavailable (e.g. tests).
    }
  }
  if (Platform.isIOS || Platform.isMacOS) {
    try {
      final config = URLSessionConfiguration.ephemeralSessionConfiguration()
        ..timeoutIntervalForRequest = const Duration(seconds: 15);
      return _ResilientNativeHttpClient(
        CupertinoClient.fromSessionConfiguration(config),
      );
    } catch (_) {
      // Fall back to dart:io when Cupertino bindings are unavailable.
    }
  }
  return IOClient(_createConfiguredIoHttpClient());
}

class _ResilientNativeHttpClient extends http.BaseClient {
  _ResilientNativeHttpClient(this._native);

  http.Client? _native;
  http.Client? _fallback;
  bool _closed = false;

  http.Client _activeFallback() =>
      _fallback ??= IOClient(_createConfiguredIoHttpClient());

  static http.Request? _snapshotRequest(http.BaseRequest request) {
    if (request is! http.Request) return null;
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    return copy;
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
    final retryCopy = _snapshotRequest(request);
    try {
      return await native.send(request);
    } catch (error) {
      if (error is http.ClientException ||
          error is SocketException ||
          error is TimeoutException ||
          error is TlsException ||
          error is HttpException) {
        rethrow;
      }
      // Native wrapper failed asynchronously (e.g. GMS-free Android device missing
      // Play Services Cronet): permanently degrade to dart:io IOClient.
      _native = null;
      try {
        native.close();
      } catch (_) {}
      if (retryCopy != null) {
        return _activeFallback().send(retryCopy);
      }
      rethrow;
    }
  }

  @override
  void close() {
    _closed = true;
    final native = _native;
    _native = null;
    if (native != null) {
      try {
        native.close();
      } catch (_) {}
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
