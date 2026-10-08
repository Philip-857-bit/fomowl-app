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
    'evm:1313161554' => 'AURORA',
    'evm:4663' => 'HOOD',
    'evm:25' => 'CRO',
    'evm:169' => 'MANTA',
    'evm:1088' => 'METIS',
    'evm:1329' => 'SEI',
    'evm:5042' => 'ARC',
    'evm:98866' => 'PLUME',
    'evm:130' => 'UNI',
    'evm:143' => 'MON',
    'evm:146' => 'S',
    'evm:480' => 'WLD',
    'evm:999' => 'HYPE',
    'evm:1135' => 'LSK',
    'evm:2741' => 'ABS',
    'evm:5000' => 'MNT',
    'evm:9745' => 'XPL',
    'evm:33139' => 'APE',
    'evm:34443' => 'MODE',
    'evm:42220' => 'CELO',
    'evm:57073' => 'INK',
    'evm:59144' => 'LINEA',
    'evm:80094' => 'BERA',
    'evm:81457' => 'BLAST',
    'evm:534352' => 'SCR',
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

final class BitcoinNetworkEntry extends NetworkEntry {
  final BitcoinChain chain;
  BitcoinNetworkEntry(this.chain);
  @override
  String get networkKey => chain.networkKey;
  @override
  String get name => chain.name;
  @override
  String get symbol => chain.symbol;
  @override
  String? get logoUrl => chain.logoUrl;
  @override
  ChainFamily get family => ChainFamily.bitcoin;
}
