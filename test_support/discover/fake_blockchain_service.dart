import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain/blockchain_catalog.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

class FakeBlockchainService extends BlockchainService {
  FakeBlockchainService({EvmChain? initialChain, List<EvmChain>? chains})
    : _activeChain = initialChain ?? BlockchainCatalog.builtInChains.first,
      _chains = List<EvmChain>.from(chains ?? BlockchainCatalog.builtInChains) {
    if (!_chains.any((chain) => chain.chainId == _activeChain.chainId)) {
      _chains.insert(0, _activeChain);
    }
  }

  final List<EvmChain> _chains;
  EvmChain _activeChain;

  @override
  List<EvmChain> get allChains => List<EvmChain>.unmodifiable(_chains);

  @override
  EvmChain get activeChain => _activeChain;

  @override
  void refresh() {}

  @override
  void setActiveChainByChainId(int chainId) {
    _activeChain = _chains.firstWhere(
      (chain) => chain.chainId == chainId,
      orElse: () => _activeChain,
    );
    notifyListeners();
  }

  @override
  Future<bool> addCustomChain(EvmChain chain) async {
    if (_chains.any((existing) => existing.chainId == chain.chainId)) {
      return false;
    }
    _chains.add(chain);
    notifyListeners();
    return true;
  }
}
