import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/models/token_standard.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/utils/token_visibility_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists active EVM network key beside legacy chain ID', () async {
    final service = BlockchainService();

    service.setActiveChainByChainId(56);
    await service.saveActiveNetworkForTest();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('active_chain_id'), 56);
    expect(prefs.getString('active_network_key'), 'evm:56');
    expect(service.activeNetworkKey, 'evm:56');
  });

  test(
    'loads active EVM network from network key before legacy chain ID',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_chain_id': 56,
        'active_network_key': 'evm:137',
      });
      final service = BlockchainService();

      await service.loadActiveNetworkForTest();

      expect(service.activeChain.chainId, 137);
      expect(service.activeNetworkKey, NetworkKey.evm(137));
    },
  );

  test(
    'activates non-EVM networks and exposes family native token fallback',
    () {
      final service = BlockchainService();

      service.setActiveNetworkKey('solana:mainnet');
      expect(service.activeNetworkKey, 'solana:mainnet');
      expect(service.activeFamily, ChainFamily.solana);
      expect(service.activeNetworkSymbol, 'SOL');
      expect(service.activeTokenStorageChainId, -501);
      expect(service.tokens.single.symbol, 'SOL');

      service.setActiveNetworkKey('tron:mainnet');
      expect(service.activeNetworkKey, 'tron:mainnet');
      expect(service.activeFamily, ChainFamily.tron);
      expect(service.activeNetworkSymbol, 'TRX');
      expect(service.activeTokenStorageChainId, -195);
      expect(service.tokens.single.symbol, 'TRX');

      service.setActiveNetworkKey('tron:nile');
      expect(service.activeNetworkKey, 'tron:mainnet');
      expect(service.activeNetworkName, 'TRON');
      expect(service.activeNetworkSymbol, 'TRX');
    },
  );

  test('clears non-EVM override when activating an EVM chain directly', () {
    final service = BlockchainService();

    service.setActiveNetworkKey('solana:mainnet');
    service.setActiveChainByChainId(56);

    expect(service.activeFamily, ChainFamily.evm);
    expect(service.activeNetworkKey, 'evm:56');
    expect(service.tokens.single.symbol, 'BNB');
  });

  test('wallet switch falls back when active family is unsupported', () {
    final service = BlockchainService();

    service.setActiveNetworkKey('solana:mainnet');
    expect(service.activeFamily, ChainFamily.solana);

    service.setActiveWalletContext(
      address: '0x1111111111111111111111111111111111111111',
      supportedFamilies: {ChainFamily.evm},
    );

    expect(service.activeFamily, ChainFamily.evm);
    expect(service.activeNetworkKey, startsWith('evm:'));
    expect(service.activeWalletSupportedFamilies, {ChainFamily.evm});
    expect(service.tokens.single.networkKey, service.activeNetworkKey);
  });

  test('active wallet context preserves non-EVM address casing', () {
    final service = BlockchainService();
    const solanaAddress = 'AJJF89F1ndCEu2zYCsGzznqmZQRmeKbrBwDF5fpyFuMP';

    service.setActiveWalletContext(
      address: solanaAddress,
      supportedFamilies: {ChainFamily.solana},
    );

    expect(service.activeWalletAddress, solanaAddress);
    expect(service.activeFamily, ChainFamily.solana);
  });

  test('blocks manual network switches unsupported by active wallet', () {
    final service = BlockchainService();
    service.setActiveWalletContext(
      address: '0x1111111111111111111111111111111111111111',
      supportedFamilies: {ChainFamily.evm},
    );

    service.setActiveNetworkKey('solana:mainnet');

    expect(service.activeFamily, ChainFamily.evm);
    expect(service.activeNetworkKey, startsWith('evm:'));
  });

  test('prefers canonical network wallet token endpoint before legacy alias', () {
    final service = BlockchainService();

    final urls = service.walletTokenDiscoveryUrisForTest(
      'https://example.test/api/blockchain',
      8453,
      '0xabc',
    );

    expect(
      urls.first.toString(),
      'https://example.test/api/blockchain/networks/evm%3A8453/wallet-tokens/0xabc',
    );
    expect(
      urls.last.toString(),
      'https://example.test/api/blockchain/8453/wallet-tokens/0xabc',
    );
  });

  test('parses backend token network metadata', () {
    final service = BlockchainService();

    final tokens = service.parseBackendDiscoveredTokensForTest(
      jsonEncode({
        'chainId': 1,
        'networkKey': 'evm:1',
        'tokens': [
          {
            'symbol': 'ETH',
            'name': 'Ethereum',
            'contractAddress': null,
            'balance': 1,
            'valueUsd': 3000,
            'priceUsd': 3000,
            'tokenStandard': 'native',
          },
          {
            'symbol': 'USDC',
            'name': 'USD Coin',
            'contractAddress': '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
            'balance': '2.5',
            'valueUsd': 2.5,
            'priceUsd': 1,
            'networkKey': 'evm:1',
            'tokenStandard': 'erc20',
          },
        ],
        'discovery': {'tokenCount': 2},
      }),
    );

    expect(tokens, hasLength(2));
    expect(tokens![0].networkKey, 'evm:1');
    expect(tokens[0].tokenStandard, TokenStandard.native);
    expect(tokens[1].networkKey, 'evm:1');
    expect(tokens[1].tokenStandard, TokenStandard.erc20);
  });

  test('uses active custom-chain metadata for its native token', () async {
    final service = BlockchainService();
    await service.addCustomChain(
      const EvmChain(
        name: 'My Custom Chain',
        symbol: 'MCC',
        chainId: 987654,
        rpcUrl: 'https://rpc.example.test',
        logoUrl: 'https://example.test/mcc.png',
        isCustom: true,
      ),
    );
    service.setActiveChainByChainId(987654);

    final tokens = service.parseBackendDiscoveredTokensForTest(
      jsonEncode({
        'chainId': 987654,
        'networkKey': 'evm:987654',
        'tokens': [
          {
            'symbol': 'NATIVE',
            'name': 'Network',
            'contractAddress': null,
            'balance': 1,
            'decimals': 18,
            'imageUrl': 'https://example.test/wrong.png',
          },
        ],
      }),
    )!;

    expect(tokens.single.name, 'My Custom Chain');
    expect(tokens.single.symbol, 'MCC');
    expect(tokens.single.imageUrl, 'https://example.test/mcc.png');
  });

  test('parses Solana backend tokens as SPL scoped to Solana network', () {
    final service = BlockchainService();
    service.setActiveNetworkKey('solana:mainnet');

    final tokens = service.parseBackendDiscoveredTokensForTest(
      jsonEncode({
        'networkKey': 'solana:mainnet',
        'tokens': [
          {
            'symbol': 'USDC',
            'name': 'USD Coin',
            'contractAddress': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
            'balance': '1.5',
            'valueUsd': 1.5,
            'priceUsd': 1,
          },
        ],
        'discovery': {'tokenCount': 1},
      }),
    );

    expect(tokens, hasLength(1));
    expect(tokens!.single.networkKey, 'solana:mainnet');
    expect(tokens.single.tokenStandard, TokenStandard.spl);
  });

  test('token visibility identifiers include network scope', () {
    const evmHello = Token(
      symbol: 'HELLO',
      name: 'HELLO',
      contractAddress: '0x0f1c00000000000000000000000000000000ac00',
      balance: 0,
      valueUsd: 0,
      changePercent24h: 0,
      networkKey: 'evm:56',
    );
    const solUsdc = Token(
      symbol: 'USDC',
      name: 'USD Coin',
      contractAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      balance: 0,
      valueUsd: 0,
      changePercent24h: 0,
      networkKey: 'solana:mainnet',
      tokenStandard: TokenStandard.spl,
    );

    expect(
      TokenVisibilityUtils.identifier(evmHello),
      'evm:56:0x0f1c00000000000000000000000000000000ac00',
    );
    expect(
      TokenVisibilityUtils.identifier(solUsdc),
      'solana:mainnet:epjfwdd5aufqssqem2qn1xzybapc8g4weggkzwytdt1v',
    );
  });

  test('rejects EVM custom token addresses on Solana', () async {
    final service = BlockchainService();
    service.setActiveNetworkKey('solana:mainnet');

    final added = await service.addCustomToken(
      chainId: -501,
      token: const CustomTokenDefinition(
        symbol: 'HELLO',
        name: 'HELLO',
        address: '0x0f1c00000000000000000000000000000000ac00',
        decimals: 18,
      ),
    );

    expect(added, isFalse);
    expect(service.customTokensForActiveChain, isEmpty);
  });
}
