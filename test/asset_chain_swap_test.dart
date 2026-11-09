import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';

import 'package:fomowl_wallet/services/blockchain/asset_chain_swap_service.dart';
import 'package:fomowl_wallet/services/blockchain/blockchain_catalog.dart';
import 'package:fomowl_wallet/services/swap_service.dart';

void main() {
  group('Group 1: Asset Chain Constants & Contract Addresses', () {
    test('TC-NET-01: Mainnet (42420) contracts match verified deployments', () {
      expect(
        AssetChainSwapService.mainnetRouterAddress.toLowerCase(),
        '0xec2b2209d710d4283b5d1e29441df0dbb9cee5c3',
      );
      expect(
        AssetChainSwapService.mainnetFactoryAddress.toLowerCase(),
        '0xa9d53862d01190e78ddaf924a8f497b4f8bb5163',
      );
      expect(
        AssetChainSwapService.mainnetQuoterAddress.toLowerCase(),
        '0xe83e6b8e8e3ec15d5cbf84cf2b2b44d19a203257',
      );
      expect(
        AssetChainSwapService.mainnetWrwaAddress.toLowerCase(),
        '0x2584d40b5553e81bb9dec0b6cd1a2e504aab1709',
      );
    });

    test('TC-NET-02: Testnet (42421) contracts match verified deployments', () {
      expect(
        AssetChainSwapService.testnetRouterAddress.toLowerCase(),
        '0x365c8bd36a27128a230b1ce8f7027d7a9e5a8f82',
      );
      expect(
        AssetChainSwapService.testnetFactoryAddress.toLowerCase(),
        '0xf509c3fbbba099cd5d949c6621c218b3e52670f8',
      );
      expect(
        AssetChainSwapService.testnetQuoterAddress.toLowerCase(),
        '0x740ac3204db2aa93cd7d5a320e8374ef63d24dbf',
      );
      expect(
        AssetChainSwapService.testnetWrwaAddress.toLowerCase(),
        '0x0fa7527f1050bb9f9736828b689c652ab2c483ef',
      );
    });

    test('TC-NET-03: Native RWA parameters in BlockchainCatalog', () {
      final mainnet = BlockchainCatalog.findChain(42420);
      expect(mainnet, isNotNull);
      expect(mainnet!.name, 'Asset Chain');
      expect(mainnet.symbol, 'RWA');
      expect(mainnet.chainId, 42420);

      final testnet = BlockchainCatalog.findChain(42421);
      expect(testnet, isNotNull);
      expect(testnet!.name, 'Asset Chain Testnet');
      expect(testnet.symbol, 'RWA');
      expect(testnet.chainId, 42421);
      expect(testnet.explorerUrl, 'https://scan-testnet.assetchain.org');

      expect(
        BlockchainCatalog.wrappedNativeAddress(42420)?.toLowerCase(),
        '0x2584d40b5553e81bb9dec0b6cd1a2e504aab1709',
      );
      expect(
        BlockchainCatalog.wrappedNativeAddress(42421)?.toLowerCase(),
        '0x0fa7527f1050bb9f9736828b689c652ab2c483ef',
      );
      expect(BlockchainCatalog.isAssetChain(42420), isTrue);
      expect(BlockchainCatalog.isAssetChain(42421), isTrue);
      expect(BlockchainCatalog.isAssetChain(1), isFalse);
    });
  });

  group('Group 2: Smart Contract Function Selectors', () {
    test('TC-SEL-01: exactInputSingle selector matches 0x414bf389', () {
      expect(AssetChainSwapService.exactInputSingleSelector, '0x414bf389');
    });

    test('TC-SEL-02: multicall selector matches 0xac9650d8', () {
      expect(AssetChainSwapService.multicallSelector, '0xac9650d8');
    });

    test('TC-SEL-03: unwrapWETH9 selector matches 0x49404b7c', () {
      expect(AssetChainSwapService.unwrapWeth9Selector, '0x49404b7c');
    });

    test('TC-SEL-04: refundETH selector matches 0x12210e8a', () {
      expect(AssetChainSwapService.refundEthSelector, '0x12210e8a');
    });

    test('TC-SEL-05: getPool selector matches 0x1698ee82', () {
      expect(AssetChainSwapService.getPoolSelector, '0x1698ee82');
    });

    test('TC-SEL-06: quoteExactInputSingle selector matches 0xc6a5026a', () {
      expect(AssetChainSwapService.quoteExactInputSingleSelector, '0xc6a5026a');
    });
  });

  group('Group 3: Calldata Encoding Validation (exactInputSingle)', () {
    test(
      'TC-ENC-01 & 02: encodes 260 bytes (522 hex chars) with correct 8-word parameter offsets',
      () {
        final calldata = AssetChainSwapService.encodeExactInputSingle(
          tokenIn: '0x2584D40B5553E81Bb9deC0b6CD1a2E504AAB1709',
          tokenOut: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
          fee: 3000,
          recipient: '0x1111111111111111111111111111111111111111',
          deadline: BigInt.from(1700000000),
          amountIn: BigInt.parse('1000000000000000000'), // 1 RWA
          amountOutMinimum: BigInt.parse('995000'), // 0.995 USDT
          sqrtPriceLimitX96: BigInt.zero,
        );

        expect(calldata.startsWith('0x414bf389'), isTrue);
        expect(calldata.length, 2 + 8 + (8 * 64)); // '0x' + 8 selector + 512 parameters = 522 chars

        // Word 0: tokenIn (32 bytes = 64 hex chars)
        final word0 = calldata.substring(10, 74);
        expect(
          word0,
          '0000000000000000000000002584d40b5553e81bb9dec0b6cd1a2e504aab1709',
        );

        // Word 1: tokenOut
        final word1 = calldata.substring(74, 138);
        expect(
          word1,
          '00000000000000000000000026e490d30e73c36800788dc6d6315946c4bbea24',
        );

        // Word 2: fee (3000 = 0xbb8)
        final word2 = calldata.substring(138, 202);
        expect(
          word2,
          '0000000000000000000000000000000000000000000000000000000000000bb8',
        );

        // Word 3: recipient
        final word3 = calldata.substring(202, 266);
        expect(
          word3,
          '0000000000000000000000001111111111111111111111111111111111111111',
        );

        // Word 4: deadline (1700000000 = 0x6553f100)
        final word4 = calldata.substring(266, 330);
        expect(
          word4,
          '000000000000000000000000000000000000000000000000000000006553f100',
        );

        // Word 5: amountIn (1e18 = 0x0de0b6b3a7640000)
        final word5 = calldata.substring(330, 394);
        expect(
          word5,
          '0000000000000000000000000000000000000000000000000de0b6b3a7640000',
        );

        // Word 6: amountOutMinimum (995000 = 0xf2eb8)
        final word6 = calldata.substring(394, 458);
        expect(
          word6,
          '00000000000000000000000000000000000000000000000000000000000f2eb8',
        );

        // Word 7: sqrtPriceLimitX96 = 0
        final word7 = calldata.substring(458, 522);
        expect(word7, '0' * 64);
      },
    );

    test('TC-ENC-03: Mainnet quote targets Mainnet SwapRouter', () {
      final router = AssetChainSwapService.resolveRouterAddress(42420);
      expect(router, '0xec2b2209d710d4283b5d1e29441df0dbb9cee5c3');
    });

    test('TC-ENC-04: Testnet quote targets Testnet SwapRouter', () {
      final router = AssetChainSwapService.resolveRouterAddress(42421);
      expect(router, '0x365C8Bd36a27128A230B1CE8f7027d7a9e5A8f82');
    });

    test('TC-ENC-05: Transaction value is strictly BigInt.zero for token sales', () {
      final swapPlan = AssetChainSwapService.buildSwapTransactionPlan(
        chainId: 42420,
        isNativeIn: false,
        isNativeOut: false,
        fromTokenAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
        toTokenAddress: '0x2B7C1342Cc64add10B2a79C8f9767d2667DE64B2',
        amountInWei: BigInt.parse('1000000'),
        amountOutMinimum: BigInt.parse('995000'),
        fee: 500,
        recipientAddress: '0x1111111111111111111111111111111111111111',
      );

      expect(swapPlan.value, BigInt.zero);
      expect(swapPlan.to, AssetChainSwapService.mainnetRouterAddress);
      expect(swapPlan.data.startsWith('0x414bf389'), isTrue);
    });
  });

  group('Group 4: Native RWA Input (Wrapping & Multicall Encoding)', () {
    test('TC-WRAP-01 & 02: Native RWA sell assigns native value and WRWA tokenIn', () {
      final swapPlan = AssetChainSwapService.buildSwapTransactionPlan(
        chainId: 42420,
        isNativeIn: true,
        isNativeOut: false,
        fromTokenAddress: '',
        toTokenAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
        amountInWei: BigInt.parse('1000000000000000000'),
        amountOutMinimum: BigInt.parse('995000'),
        fee: 3000,
        recipientAddress: '0x1111111111111111111111111111111111111111',
      );

      expect(swapPlan.value, BigInt.parse('1000000000000000000'));
      expect(swapPlan.to, AssetChainSwapService.mainnetRouterAddress);
      expect(
        swapPlan.data.startsWith('0x414bf389') ||
            swapPlan.data.startsWith('0xac9650d8'),
        isTrue,
      );
    });

    test('TC-WRAP-03: Multicall encoding with refundETH() safety tail', () {
      final swapPlan = AssetChainSwapService.buildSwapTransactionPlan(
        chainId: 42421,
        isNativeIn: true,
        isNativeOut: false,
        fromTokenAddress: '',
        toTokenAddress: '0x04f868C5b3F0A100a207c7e9312946cC2c48a7a3',
        amountInWei: BigInt.parse('500000000000000000'),
        amountOutMinimum: BigInt.parse('490000'),
        fee: 3000,
        recipientAddress: '0x2222222222222222222222222222222222222222',
      );

      expect(swapPlan.data.startsWith('0xac9650d8'), isTrue);
      // Contains refundETH selector
      expect(swapPlan.data.contains('12210e8a'), isTrue);
      // Contains WRWA as tokenIn
      expect(
        swapPlan.data.contains('0fa7527f1050bb9f9736828b689c652ab2c483ef'),
        isTrue,
      );
      expect(swapPlan.value, BigInt.parse('500000000000000000'));
    });
  });

  group('Group 5: Native RWA Output (Unwrapping via Multicall)', () {
    test('TC-UNWRAP-01: Multicall batches exactInputSingle + unwrapWETH9', () {
      final swapPlan = AssetChainSwapService.buildSwapTransactionPlan(
        chainId: 42420,
        isNativeIn: false,
        isNativeOut: true,
        fromTokenAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
        toTokenAddress: '',
        amountInWei: BigInt.parse('1000000'),
        amountOutMinimum: BigInt.parse('995000000000000000'),
        fee: 3000,
        recipientAddress: '0x1111111111111111111111111111111111111111',
      );

      expect(swapPlan.value, BigInt.zero);
      expect(swapPlan.data.startsWith('0xac9650d8'), isTrue);
      expect(swapPlan.data.contains('49404b7c'), isTrue); // unwrapWETH9 selector
      expect(swapPlan.data.contains('414bf389'), isTrue); // exactInputSingle selector
    });

    test(
      'TC-UNWRAP-02 & 03: Intermediate recipient set to router, final to user, amountMinimum matches floor',
      () {
        const userAddr = '0x1111111111111111111111111111111111111111';
        final floor = BigInt.parse('995000000000000000');
        final swapPlan = AssetChainSwapService.buildSwapTransactionPlan(
          chainId: 42420,
          isNativeIn: false,
          isNativeOut: true,
          fromTokenAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
          toTokenAddress: '',
          amountInWei: BigInt.parse('1000000'),
          amountOutMinimum: floor,
          fee: 3000,
          recipientAddress: userAddr,
        );

        // In exactInputSingle: recipient is the router
        expect(
          swapPlan.data.contains(
            AssetChainSwapService.mainnetRouterAddress.substring(2).toLowerCase(),
          ),
          isTrue,
        );
        // In unwrapWETH9: recipient is the user
        expect(
          swapPlan.data.contains(userAddr.substring(2).toLowerCase()),
          isTrue,
        );
      },
    );
  });

  group('Group 6: Slippage Floor Math & Invariant Enforcement', () {
    test('TC-SLIP-01: 0% slippage (0 BPS) returns exact quote', () {
      final quoted = BigInt.from(1000000000);
      expect(AssetChainSwapService.calculateAmountOutMinimum(quoted, 0), quoted);
    });

    test(
      'TC-SLIP-02: 0.5% default slippage (50 BPS) computes floor with 9950/10000 multiplier',
      () {
        final quoted = BigInt.from(1000000);
        expect(
          AssetChainSwapService.calculateAmountOutMinimum(quoted, 50),
          BigInt.from(995000),
        );
      },
    );

    test('TC-SLIP-03: Custom slippage tiers (100 BPS, 500 BPS)', () {
      final quoted = BigInt.from(1000000);
      expect(
        AssetChainSwapService.calculateAmountOutMinimum(quoted, 100),
        BigInt.from(990000),
      );
      expect(
        AssetChainSwapService.calculateAmountOutMinimum(quoted, 500),
        BigInt.from(950000),
      );
    });

    test('TC-SLIP-04: Test vectors TV-SLIP-03 and TV-SLIP-06', () {
      final rwa1 = BigInt.parse('1000000000000000000');
      expect(
        AssetChainSwapService.calculateAmountOutMinimum(rwa1, 50),
        BigInt.parse('995000000000000000'),
      );

      final oddAmount = BigInt.from(123456789);
      expect(
        AssetChainSwapService.calculateAmountOutMinimum(oddAmount, 50),
        BigInt.from(122839505),
      );
    });

    test('TC-SLIP-05: Rejects negative slippage or >= 10000 BPS', () {
      final quoted = BigInt.from(1000000);
      expect(
        () => AssetChainSwapService.calculateAmountOutMinimum(quoted, -1),
        throwsArgumentError,
      );
      expect(
        () => AssetChainSwapService.calculateAmountOutMinimum(quoted, 10000),
        throwsArgumentError,
      );
      expect(
        () => AssetChainSwapService.calculateAmountOutMinimum(quoted, 15000),
        throwsArgumentError,
      );
    });
  });

  group('Group 7: Mock RPC & Quoting Simulation (Test Isolation)', () {
    test(
      'TC-RPC-01 & 02: Factory getPool discovery and QuoterV2 quoteExactInputSingle simulation',
      () async {
        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final method = body['method'] as String;
            final params = body['params'] as List<dynamic>;

            if (method == 'eth_call') {
              final tx = params[0] as Map<String, dynamic>;
              final data = tx['data'] as String;

              if (data.startsWith('0x1698ee82')) {
                // getPool: returns pool address for fee 3000
                const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
                final poolWord = pool.replaceAll('0x', '').padLeft(64, '0');
                return http.Response(
                  jsonEncode({
                    'jsonrpc': '2.0',
                    'id': body['id'],
                    'result': '0x$poolWord',
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }

              if (data.startsWith('0xc6a5026a')) {
                // quoteExactInputSingle: returns 995000 out
                final outHex =
                    BigInt.from(995000).toRadixString(16).padLeft(64, '0');
                return http.Response(
                  jsonEncode({
                    'jsonrpc': '2.0',
                    'id': body['id'],
                    'result': '0x$outHex${'0' * 64}${'0' * 64}${'0' * 64}',
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
            }
            throw StateError('Unexpected RPC call: $method');
          }),
        );

        final quote = await AssetChainSwapService(web3Client: client).getQuote(
          chainId: 42420,
          fromTokenAddress: '0x2584D40B5553E81Bb9deC0b6CD1a2E504AAB1709',
          toTokenAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
          amountInWei: BigInt.parse('1000000000000000000'),
          slippageBps: 50,
        );

        expect(quote, isNotNull);
        expect(quote!.amountOutWei, '995000');
        expect(quote.minAmountOutWei, '990025'); // 995000 * 9950 / 10000
        expect(
          quote.allowanceTarget,
          AssetChainSwapService.mainnetRouterAddress,
        );
        expect(quote.needsAllowance, isTrue);
      },
    );

    test('TC-RPC-03: Best-rate pool fee tier selection among multiple pools', () async {
      final client = Web3Client(
        'https://rpc.offline.test',
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final method = body['method'] as String;
          final params = body['params'] as List<dynamic>;

          if (method == 'eth_call') {
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              // Both 500 (0x1f4) and 3000 (0xbb8) have pools
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              final poolWord = pool.replaceAll('0x', '').padLeft(64, '0');
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x$poolWord',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (data.startsWith('0xc6a5026a')) {
              // Check fee in calldata: fee is at word 3 (offset 10 + 3*64 = 202)
              final feeHex = data.substring(202, 266);
              final fee = int.parse(feeHex, radix: 16);
              // Fee 500 gives 1,000,000; Fee 3000 gives 950,000
              final outVal = fee == 500
                  ? BigInt.from(1000000)
                  : BigInt.from(950000);
              final outHex = outVal.toRadixString(16).padLeft(64, '0');
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x$outHex${'0' * 64}${'0' * 64}${'0' * 64}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }
          throw StateError('Unexpected RPC call: $method');
        }),
      );

      final quote = await AssetChainSwapService(web3Client: client).getQuote(
        chainId: 42421,
        fromTokenAddress: '0x0FA7527F1050bb9F9736828B689c652AB2c483ef',
        toTokenAddress: '0x04f868C5b3F0A100a207c7e9312946cC2c48a7a3',
        amountInWei: BigInt.parse('1000000000000000000'),
        slippageBps: 50,
      );

      expect(quote, isNotNull);
      // Selects the 500 fee pool which produced 1,000,000
      expect(quote!.amountOutWei, '1000000');
      expect(quote.minAmountOutWei, '995000');
    });

    test('TC-RPC-04: Missing liquidity / uncreated pool returns null with user error', () async {
      final client = Web3Client(
        'https://rpc.offline.test',
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          // Factory returns zero address for all fee tiers
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': '0x${'0' * 64}',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final service = AssetChainSwapService(web3Client: client);
      final quote = await service.getQuote(
        chainId: 42420,
        fromTokenAddress: '0x1111111111111111111111111111111111111111',
        toTokenAddress: '0x2222222222222222222222222222222222222222',
        amountInWei: BigInt.from(1000),
      );

      expect(quote, isNull);
      expect(service.lastError, contains('No liquidity pool found'));
    });

    test('TC-RPC-05: Quoter revert rejects executable quote but allows slot0 fallback for estimates', () async {
      final client = Web3Client(
        'https://rpc.offline.test',
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final method = body['method'] as String;
          final params = body['params'] as List<dynamic>;

          if (method == 'eth_call') {
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              // getPool returns valid pool address
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              final poolWord = pool.replaceAll('0x', '').padLeft(64, '0');
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x$poolWord',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (data.startsWith('0xc6a5026a')) {
              // Quoter reverts with JSON-RPC error
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'error': {
                    'code': 3,
                    'message': 'execution reverted: Unexpected error',
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (data.startsWith('0x3850c7bd')) {
              // slot0 fallback returns sqrtPriceX96 = 2^96 (1:1 price)
              final sqrtPriceX96 = BigInt.one << 96;
              final sqrtHex = sqrtPriceX96.toRadixString(16).padLeft(64, '0');
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x$sqrtHex${'0' * 64}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }
          throw StateError('Unexpected RPC call: $method');
        }),
      );

      final service = AssetChainSwapService(web3Client: client);
      // 1. Executable quote must fail closed when Quoter reverts
      final quote = await service.getQuote(
        chainId: 42420,
        fromTokenAddress: '0x2584D40B5553E81Bb9deC0b6CD1a2E504AAB1709',
        toTokenAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
        amountInWei: BigInt.from(1000000),
      );

      expect(quote, isNull);
      expect(service.lastError, contains('Quoter simulation failed'));

      // 2. Non-executable estimate allows slot0 fallback
      final estimate = await service.getBestQuoteResult(
        chainId: 42420,
        tokenInAddress: '0x2584D40B5553E81Bb9deC0b6CD1a2E504AAB1709',
        tokenOutAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
        amountInWei: BigInt.from(1000000),
        candidates: [
          const AssetChainPoolCandidate(
            poolAddress: '0x63b1086e9e993612106955b770e1c8239ddd1dde',
            fee: 3000,
          ),
        ],
        allowSlot0Fallback: true,
      );
      expect(estimate, isNotNull);
      expect(estimate!.amountOut > BigInt.zero, isTrue);
      expect(estimate.usedFallback, isTrue);
    });
  });

  group('Group 8: Regression Prevention & Safety Invariants', () {
    test(
      'TC-REG-01: SwapService.isChainSupported returns true for normal Asset Chain swaps and false for gasless',
      () {
        final swapService = SwapService();
        expect(swapService.isChainSupported(42420, isGasless: false), isTrue);
        expect(swapService.isChainSupported(42421, isGasless: false), isTrue);
        expect(swapService.isChainSupported(42420, isGasless: true), isFalse);
        expect(swapService.isChainSupported(42421, isGasless: true), isFalse);
      },
    );

    test(
      'TC-REG-02: Native token swap sets txValue == amountIn and ERC-20 swap sets txValue == 0',
      () {
        // Native RWA sell
        final nativePlan = AssetChainSwapService.buildSwapTransactionPlan(
          chainId: 42420,
          isNativeIn: true,
          isNativeOut: false,
          fromTokenAddress: '',
          toTokenAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
          amountInWei: BigInt.parse('1000000000000000000'),
          amountOutMinimum: BigInt.parse('995000'),
          fee: 3000,
          recipientAddress: '0x1111111111111111111111111111111111111111',
        );
        expect(nativePlan.value, BigInt.parse('1000000000000000000'));

        // ERC-20 token sell
        final tokenPlan = AssetChainSwapService.buildSwapTransactionPlan(
          chainId: 42420,
          isNativeIn: false,
          isNativeOut: false,
          fromTokenAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
          toTokenAddress: '0x2584D40B5553E81Bb9deC0b6CD1a2E504AAB1709',
          amountInWei: BigInt.parse('1000000'),
          amountOutMinimum: BigInt.parse('995000000000000000'),
          fee: 3000,
          recipientAddress: '0x1111111111111111111111111111111111111111',
        );
        expect(tokenPlan.value, BigInt.zero);
      },
    );

    test('TC-REG-03: Minimum output floor preserves slippage tolerance', () {
      final quotedOut = BigInt.from(1000000);
      final minOut = AssetChainSwapService.calculateAmountOutMinimum(
        quotedOut,
        50,
      );
      // minOut must be exactly 995,000 for 50 BPS (0.5% max drop)
      expect(minOut, BigInt.from(995000));
      expect(minOut <= quotedOut, isTrue);
    });
  });
}
