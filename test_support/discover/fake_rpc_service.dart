import 'package:fomowl_wallet/services/rpc_service.dart';

class FakeRpcService extends RpcService {
  FakeRpcService({
    Map<String, int>? chainIdsByUrl,
    Map<int, String>? resolvedUrlsByChainId,
  }) : _chainIdsByUrl = Map<String, int>.from(chainIdsByUrl ?? const {}),
       _resolvedUrlsByChainId = Map<int, String>.from(
         resolvedUrlsByChainId ?? const {},
       );

  final Map<String, int> _chainIdsByUrl;
  final Map<int, String> _resolvedUrlsByChainId;

  @override
  Future<int?> getChainIdForRpcUrl(String rpcUrl) async {
    return _chainIdsByUrl[rpcUrl];
  }

  @override
  Future<String> resolveWorkingRpcUrl({
    required int chainId,
    required String primaryRpcUrl,
  }) async {
    return _resolvedUrlsByChainId[chainId] ?? primaryRpcUrl;
  }
}
