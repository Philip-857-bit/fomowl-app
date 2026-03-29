import 'dart:convert';
import 'dart:io';

class DiscoverTestDappServer {
  static const String mockAddChainRpcUrl = 'https://rpc.sepolia.test';

  HttpServer? _server;

  Uri get originUri {
    final server = _server;
    if (server == null) {
      throw StateError('DiscoverTestDappServer has not been started.');
    }
    return Uri.parse('http://127.0.0.1:${server.port}');
  }

  String origin() => originUri.toString();

  String urlForScenario(String scenario) {
    return originUri
        .replace(path: '/approved', queryParameters: {'scenario': scenario})
        .toString();
  }

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/approved') {
      final scenario = request.uri.queryParameters['scenario'] ?? 'provider';
      request.response.headers.contentType = ContentType.html;
      request.response.write(_pageForScenario(scenario));
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.write('not found');
    await request.response.close();
  }

  String _pageForScenario(String scenario) {
    final config = jsonEncode(<String, Object?>{
      'scenario': scenario,
      'switchChainId': '0x38',
      'addChain': <String, Object?>{
        'chainId': '0xaa36a7',
        'chainName': 'Sepolia',
        'rpcUrls': <String>[mockAddChainRpcUrl],
        'blockExplorerUrls': <String>['https://sepolia.etherscan.io'],
        'nativeCurrency': <String, String>{'symbol': 'ETH'},
      },
      'invalidAddChain': <String, Object?>{
        'chainId': '0xaa36a7',
        'chainName': 'Sepolia',
        'rpcUrls': <String>['http://invalid.local'],
        'blockExplorerUrls': <String>['https://sepolia.etherscan.io'],
        'nativeCurrency': <String, String>{'symbol': 'ETH'},
      },
      'blockedRedirectUrl': 'https://blocked.example/landing',
    });

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>loading:$scenario</title>
    <script>
      const config = $config;

      function setResult(title, details) {
        document.title = title;
        const target = document.getElementById('result');
        if (target) {
          target.textContent = details || title;
        }
      }

      async function waitForProvider() {
        const startedAt = Date.now();
        while (Date.now() - startedAt < 5000) {
          if (window.ethereum && typeof window.ethereum.request === 'function') {
            return window.ethereum;
          }
          await new Promise((resolve) => setTimeout(resolve, 50));
        }
        throw new Error('provider missing');
      }

      async function runScenario() {
        try {
          const provider = await waitForProvider();
          switch (config.scenario) {
            case 'provider':
              setResult(
                provider ? 'provider:yes' : 'provider:no',
                provider ? 'provider detected' : 'provider missing',
              );
              return;
            case 'connect': {
              const accounts = await provider.request({
                method: 'eth_requestAccounts',
                params: [],
              });
              setResult('accounts:' + accounts.join(','), accounts.join(','));
              return;
            }
            case 'switch': {
              await provider.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: config.switchChainId }],
              });
              const chainId = await provider.request({
                method: 'eth_chainId',
                params: [],
              });
              setResult('chain:' + chainId, chainId);
              return;
            }
            case 'addchain': {
              await provider.request({
                method: 'wallet_addEthereumChain',
                params: [config.addChain],
              });
              setResult('addchain:ok', 'custom chain added');
              return;
            }
            case 'addchain-invalid': {
              await provider.request({
                method: 'wallet_addEthereumChain',
                params: [config.invalidAddChain],
              });
              setResult('addchain:unexpected', 'unexpected success');
              return;
            }
            case 'blocked-redirect':
              window.location.href = config.blockedRedirectUrl;
              return;
            default:
              setResult('unknown:' + config.scenario, 'unknown scenario');
          }
        } catch (error) {
          const code =
            error && typeof error.code !== 'undefined' ? error.code : 'none';
          const message = error && error.message ? error.message : String(error);
          setResult('error:' + code, message);
        }
      }

      window.addEventListener('load', () => {
        setTimeout(runScenario, 50);
      });
    </script>
  </head>
  <body>
    <main>
      <h1>Discover Harness</h1>
      <p id="result">waiting</p>
    </main>
  </body>
</html>
''';
  }
}
