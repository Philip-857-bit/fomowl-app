import '../../models/chain.dart';

/// Solana metadata scaffold for future wallet integration.
///
/// This intentionally does not wire Solana into the active wallet flows yet.
/// The rest of the app still assumes EVM signing, RPC, token discovery, and
/// transaction semantics. These definitions give the next implementation pass
/// a single canonical source for Solana network metadata.
class SolanaCatalog {
  static const SolanaChain mainnet = SolanaChain(
    name: 'Solana',
    symbol: 'SOL',
    cluster: 'mainnet-beta',
    rpcUrl: 'https://api.mainnet-beta.solana.com',
    coinGeckoId: 'solana',
    explorerUrl: 'https://explorer.solana.com',
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/info/logo.png',
  );

  static const SolanaChain devnet = SolanaChain(
    name: 'Solana Devnet',
    symbol: 'SOL',
    cluster: 'devnet',
    rpcUrl: 'https://api.devnet.solana.com',
    coinGeckoId: 'solana',
    explorerUrl: 'https://explorer.solana.com/?cluster=devnet',
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/info/logo.png',
  );

  static const SolanaChain testnet = SolanaChain(
    name: 'Solana Testnet',
    symbol: 'SOL',
    cluster: 'testnet',
    rpcUrl: 'https://api.testnet.solana.com',
    coinGeckoId: 'solana',
    explorerUrl: 'https://explorer.solana.com/?cluster=testnet',
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/info/logo.png',
  );

  static const List<SolanaChain> builtInChains = [mainnet, devnet, testnet];
}
