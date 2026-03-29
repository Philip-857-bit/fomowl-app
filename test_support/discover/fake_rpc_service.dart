import 'package:fomowl_wallet/services/rpc_service.dart';

class FakeRpcService extends RpcService {
  FakeRpcService({Map<String, int>? chainIdsByUrl})
    : _chainIdsByUrl = Map<String, int>.from(chainIdsByUrl ?? const {});

  final Map<String, int> _chainIdsByUrl;

  @override
  Future<int?> getChainIdForRpcUrl(String rpcUrl) async {
    return _chainIdsByUrl[rpcUrl];
  }
}
