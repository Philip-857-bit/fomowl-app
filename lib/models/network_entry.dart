import 'chain.dart';

sealed class NetworkEntry {
  String get networkKey;
  String get name;
  String get symbol;
  String? get logoUrl;
  ChainFamily get family;
}

/// Short identity label used when the UI is naming a network rather than its
/// native gas token. Several EVM L2s use ETH for fees, but showing ETH in the
/// network picker makes Base, Arbitrum, and Optimism indistinguishable.
String networkIdentitySymbolForKey(
  String networkKey, {
  required String fallback,
}) {
  return switch (networkKey.trim().toLowerCase()) {
    'evm:1' => 'ETH',
    'evm:56' => 'BNB',
    'evm:137' => 'MATIC',
    'evm:42161' => 'ARB',
    'evm:10' => 'OP',
    'evm:8453' => 'BASE',
    'evm:324' => 'ZK',
    'evm:43114' => 'AVAX',
    'evm:250' => 'FTM',
    'evm:100' => 'GNO',
    'evm:8217' => 'KAIA',
    'evm:1313161554' => 'AURORA',
    'evm:4663' => 'HOOD',
    'solana:mainnet' || 'solana:mainnet-beta' => 'SOL',
    'tron:mainnet' => 'TRX',
    _ => fallback.trim().toUpperCase(),
  };
}

extension NetworkEntryIdentity on NetworkEntry {
  String get identitySymbol =>
      networkIdentitySymbolForKey(networkKey, fallback: symbol);
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
