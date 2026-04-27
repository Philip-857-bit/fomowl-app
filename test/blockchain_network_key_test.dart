import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token_standard.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

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

  test('keeps non-EVM network activation explicitly unsupported for now', () {
    final service = BlockchainService();

    expect(
      () => service.setActiveNetworkKey('solana:mainnet'),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => service.setActiveNetworkKey('tron:mainnet'),
      throwsA(isA<UnsupportedError>()),
    );
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
}
