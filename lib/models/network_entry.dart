import 'chain.dart';

sealed class NetworkEntry {
  String get networkKey;
  String get name;
  String get symbol;
  String? get logoUrl;
  ChainFamily get family;
}

final class EvmNetworkEntry extends NetworkEntry {
  final EvmChain chain;
  EvmNetworkEntry(this.chain);

  @override
  String get networkKey => chain.networkKey;
  @override
  String get name => chain.name;
  @override
  String get symbol => chain.symbol;
  @override
  String? get logoUrl => chain.logoUrl;
  @override
  ChainFamily get family => ChainFamily.evm;
}

final class SolanaNetworkEntry extends NetworkEntry {
  final SolanaChain chain;
  SolanaNetworkEntry(this.chain);

  @override
  String get networkKey => chain.networkKey;
  @override
  String get name => chain.name;
  @override
  String get symbol => chain.symbol;
  @override
  String? get logoUrl => chain.logoUrl;
  @override
  ChainFamily get family => ChainFamily.solana;
}

final class TronNetworkEntry extends NetworkEntry {
  final TronChain chain;
  TronNetworkEntry(this.chain);

  @override
  String get networkKey => chain.networkKey;
  @override
  String get name => chain.name;
  @override
  String get symbol => chain.symbol;
  @override
  String? get logoUrl => chain.logoUrl;
  @override
  ChainFamily get family => ChainFamily.tron;
}
