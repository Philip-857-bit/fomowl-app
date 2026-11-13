import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';

import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/services/blockchain/asset_chain_swap_service.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/swap_service.dart';
import 'package:fomowl_wallet/services/swap_execution_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/utils/swap_quote_error_messages.dart';
import 'swap_service_test.dart' show HttpClientServiceMock;

/// Mock wallet service capturing the raw transaction requests for verification.
class _MockCapturingWallet extends WalletService {
  Map<String, Object?>? capturedRequest;
  bool shouldSucceed = true;

  @override
  Future<String> sendRawTransactionRequest({
    required String rpcUrl,
    required int chainId,
    String? expectedFromAddress,
    String? toAddress,
    BigInt? valueInWei,
    String? dataHex,
    BigInt? gasPriceWei,
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
    int? gasLimit,
    int? nonce,
  }) async {
    if (!shouldSucceed) {
      throw Exception('Simulated wallet transaction rejection');
    }
    capturedRequest = {
      'rpcUrl': rpcUrl,
      'chainId': chainId,
      'toAddress': toAddress,
      'valueInWei': valueInWei,
      'dataHex': dataHex,
      'gasPriceWei': gasPriceWei,
      'gasLimit': gasLimit,
    };
    return '0x9999999999999999999999999999999999999999999999999999999999999999';
  }
}

// Controlled RPC fee/allowance boundary for executable-quote regressions.
http.Response? feeRpcResponse(Map<String, dynamic> body) {
  String? result;
  if (body['method'] == 'eth_gasPrice') result = '0x3d187120';
  if (body['method'] == 'eth_estimateGas') result = '0x186a0';
  if (body['method'] == 'eth_call') {
    final params = body['params'] as List<dynamic>;
    final tx = params.first as Map<String, dynamic>;
    if ((tx['data'] as String).startsWith('0xdd62ed3e')) {
      result = '0x${'f' * 64}';
    }
  }
  if (result == null) return null;
  return http.Response(
    jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
    200,
  );
}

void main() {
  late BlockchainService blockchain;
  late _MockCapturingWallet wallet;

  setUp(() {
    blockchain = BlockchainService();
    wallet = _MockCapturingWallet();
  });

  tearDown(() {
    blockchain.dispose();
  });

  const nativeRwa = Token(
    symbol: 'RWA',
    name: 'Asset Chain Native RWA',
    contractAddress: '',
    decimals: 18,
    balance: 10,
    valueUsd: 10,
    changePercent24h: 0,
  );

  const nativeRwaSentinel = Token(
    symbol: 'RWA',
    name: 'Asset Chain Native RWA',
    contractAddress: '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    decimals: 18,
    balance: 10,
    valueUsd: 10,
    changePercent24h: 0,
  );

  const usdtToken = Token(
    symbol: 'USDT',
    name: 'Tether USD',
    contractAddress: '0x26E490d30e73c36800788DC6d6315946C4BbEa24',
    decimals: 6,
    balance: 100,
    valueUsd: 100,
    changePercent24h: 0,
  );

  const wrwaToken = Token(
    symbol: 'WRWA',
    name: 'Wrapped RWA',
    contractAddress: '0x2584D40B5553E81Bb9deC0b6CD1a2E504AAB1709',
    decimals: 18,
    balance: 10,
    valueUsd: 10,
    changePercent24h: 0,
  );

  group('CHALLENGE SUITE 1: Safety Invariant Compliance with SwapExecutionService', () {
    test(
      'CH-INV-01: Native RWA sale sets quote.txValue == sellAmountWei and succeeds in SwapExecutionService',
      () async {
        // Setup Web3Client mock returning valid pool (fee 3000) and Quoter quote
        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final feeResponse = feeRpcResponse(body);
            if (feeResponse != null) return feeResponse;
            final params = body['params'] as List<dynamic>;
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              // getPool: return valid pool address
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x${pool.replaceAll('0x', '').padLeft(64, '0')}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (data.startsWith('0xc6a5026a')) {
              // quoteExactInputSingle: 2,000,000 USDT base units (2.0 USDT)
              final outHex = BigInt.from(
                2000000,
              ).toRadixString(16).padLeft(64, '0');
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
            throw StateError('Unexpected RPC call');
          }),
        );

        final swapService = AssetChainSwapService(web3Client: client);
        final sellAmountWei = BigInt.parse('1000000000000000000'); // 1 RWA

        final quote = await swapService.getQuote(
          chainId: 42420,
          fromTokenAddress: '', // Native
          toTokenAddress: usdtToken.contractAddress!,
          amountInWei: sellAmountWei,
          buyTokenDecimals: 6,
          slippageBps: 50,
          walletAddress: '0x1111111111111111111111111111111111111111',
          useFirmQuote: true,
        );

        expect(quote, isNotNull);
        // Native RWA sale must assign exact sellAmountWei to txValue
        expect(quote!.txValue, sellAmountWei.toString());
        expect(BigInt.parse(quote.txValue!), sellAmountWei);

        // Execute via SwapExecutionService
        final executionService = SwapExecutionService(walletService: wallet);
        final result = await executionService.execute(
          quote: quote,
          fromToken: nativeRwa,
          toToken: usdtToken,
          fromAmountWei: sellAmountWei.toString(),
          expectedToAmount: double.parse(quote.amountOutFormatted),
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );

        expect(result.success, isTrue);
        expect(wallet.capturedRequest, isNotNull);
        expect(wallet.capturedRequest!['valueInWei'], sellAmountWei);
        expect(
          wallet.capturedRequest!['toAddress'],
          AssetChainSwapService.mainnetRouterAddress,
        );
      },
    );

    test(
      'CH-INV-02: Native RWA sentinel address 0xeeee... assigns exact sellAmountWei and passes SwapExecutionService',
      () async {
        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final feeResponse = feeRpcResponse(body);
            if (feeResponse != null) return feeResponse;
            final params = body['params'] as List<dynamic>;
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x${pool.replaceAll('0x', '').padLeft(64, '0')}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (data.startsWith('0xc6a5026a')) {
              final outHex = BigInt.from(
                1500000,
              ).toRadixString(16).padLeft(64, '0');
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
            throw StateError('Unexpected RPC call');
          }),
        );

        final swapService = AssetChainSwapService(web3Client: client);
        final sellAmountWei = BigInt.parse('500000000000000000'); // 0.5 RWA

        final quote = await swapService.getQuote(
          chainId: 42420,
          fromTokenAddress: '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          toTokenAddress: usdtToken.contractAddress!,
          amountInWei: sellAmountWei,
          buyTokenDecimals: 6,
          slippageBps: 50,
          walletAddress: '0x1111111111111111111111111111111111111111',
          useFirmQuote: true,
        );

        expect(quote, isNotNull);
        expect(quote!.txValue, sellAmountWei.toString());

        final executionService = SwapExecutionService(walletService: wallet);
        final result = await executionService.execute(
          quote: quote,
          fromToken: nativeRwaSentinel,
          toToken: usdtToken,
          fromAmountWei: sellAmountWei.toString(),
          expectedToAmount: double.parse(quote.amountOutFormatted),
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );

        expect(result.success, isTrue);
        expect(wallet.capturedRequest!['valueInWei'], sellAmountWei);
      },
    );

    test(
      'CH-INV-03: Tampered native sale with mismatched txValue is strictly rejected by SwapExecutionService',
      () async {
        final sellAmountWei = BigInt.parse('1000000000000000000');
        // Create a quote where txValue does not match sellAmountWei (e.g. 0 or off by 1 wei)
        final tamperedQuoteZero = SwapQuote(
          amountOutWei: '1000000',
          minAmountOutWei: '995000',
          amountOutFormatted: '1.0',
          minAmountOutFormatted: '0.995',
          networkFeeUsd: 0,
          networkFeeNative: 0.001,
          allowanceTarget: '',
          allowanceSpender: null,
          needsAllowance: false,
          hasBalanceIssue: false,
          balanceNeeded: null,
          balanceActual: null,
          txTo: AssetChainSwapService.mainnetRouterAddress,
          txData: '0xac9650d81234',
          txValue: '0', // Mismatch!
          txGas: '250000',
          txGasPrice: '20000000000',
        );

        final executionService = SwapExecutionService(walletService: wallet);
        final resultZero = await executionService.execute(
          quote: tamperedQuoteZero,
          fromToken: nativeRwa,
          toToken: usdtToken,
          fromAmountWei: sellAmountWei.toString(),
          expectedToAmount: 1.0,
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );

        expect(resultZero.success, isFalse);
        expect(
          resultZero.error,
          contains(
            'Swap transaction value does not match the amount you are selling',
          ),
        );
        expect(wallet.capturedRequest, isNull);

        // Off-by-one wei tamper
        final tamperedQuoteOffByOne = SwapQuote(
          amountOutWei: '1000000',
          minAmountOutWei: '995000',
          amountOutFormatted: '1.0',
          minAmountOutFormatted: '0.995',
          networkFeeUsd: 0,
          networkFeeNative: 0.001,
          allowanceTarget: '',
          allowanceSpender: null,
          needsAllowance: false,
          hasBalanceIssue: false,
          balanceNeeded: null,
          balanceActual: null,
          txTo: AssetChainSwapService.mainnetRouterAddress,
          txData: '0xac9650d81234',
          txValue: (sellAmountWei - BigInt.one).toString(), // Off by 1 wei
          txGas: '250000',
          txGasPrice: '20000000000',
        );

        final resultOff = await executionService.execute(
          quote: tamperedQuoteOffByOne,
          fromToken: nativeRwa,
          toToken: usdtToken,
          fromAmountWei: sellAmountWei.toString(),
          expectedToAmount: 1.0,
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );

        expect(resultOff.success, isFalse);
        expect(
          resultOff.error,
          contains(
            'Swap transaction value does not match the amount you are selling',
          ),
        );
        expect(wallet.capturedRequest, isNull);
      },
    );

    test(
      'CH-INV-04: ERC-20 token sale sets quote.txValue == "0" and succeeds in SwapExecutionService',
      () async {
        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final feeResponse = feeRpcResponse(body);
            if (feeResponse != null) return feeResponse;
            final params = body['params'] as List<dynamic>;
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x${pool.replaceAll('0x', '').padLeft(64, '0')}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (data.startsWith('0xc6a5026a')) {
              // Returns 500,000,000,000,000,000 (0.5 RWA)
              final outHex = BigInt.parse(
                '500000000000000000',
              ).toRadixString(16).padLeft(64, '0');
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
            throw StateError('Unexpected RPC call');
          }),
        );

        final swapService = AssetChainSwapService(web3Client: client);
        final sellAmountWei = BigInt.parse('1000000'); // 1 USDT

        final quote = await swapService.getQuote(
          chainId: 42420,
          fromTokenAddress: usdtToken.contractAddress!,
          toTokenAddress: wrwaToken.contractAddress!,
          amountInWei: sellAmountWei,
          buyTokenDecimals: 18,
          slippageBps: 50,
          walletAddress: '0x1111111111111111111111111111111111111111',
          useFirmQuote: true,
        );

        expect(quote, isNotNull);
        // ERC-20 token sale must strictly assign "0" to txValue
        expect(quote!.txValue, '0');
        expect(BigInt.parse(quote.txValue!), BigInt.zero);

        final executionService = SwapExecutionService(walletService: wallet);
        final result = await executionService.execute(
          quote: quote,
          fromToken: usdtToken,
          toToken: wrwaToken,
          fromAmountWei: sellAmountWei.toString(),
          expectedToAmount: double.parse(quote.amountOutFormatted),
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );

        expect(result.success, isTrue);
        expect(wallet.capturedRequest, isNotNull);
        expect(wallet.capturedRequest!['valueInWei'], BigInt.zero);
      },
    );

    test(
      'CH-INV-05: Adversarial ERC-20 token sale with non-zero txValue (native drain attempt) is blocked by SwapExecutionService',
      () async {
        // Attacker tampers quote to siphon 1 ether of native RWA along with the token swap
        final maliciousQuote = SwapQuote(
          amountOutWei: '500000000000000000',
          minAmountOutWei: '497500000000000000',
          amountOutFormatted: '0.5',
          minAmountOutFormatted: '0.4975',
          networkFeeUsd: 0,
          networkFeeNative: 0.001,
          allowanceTarget: AssetChainSwapService.mainnetRouterAddress,
          allowanceSpender: AssetChainSwapService.mainnetRouterAddress,
          needsAllowance: true,
          hasBalanceIssue: false,
          balanceNeeded: null,
          balanceActual: null,
          txTo: AssetChainSwapService.mainnetRouterAddress,
          txData: '0x414bf3891234',
          txValue: '1000000000000000000', // Drain 1 RWA!
          txGas: '250000',
          txGasPrice: '20000000000',
        );

        final executionService = SwapExecutionService(walletService: wallet);
        final result = await executionService.execute(
          quote: maliciousQuote,
          fromToken: usdtToken,
          toToken: wrwaToken,
          fromAmountWei: '1000000',
          expectedToAmount: 0.5,
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );

        expect(result.success, isFalse);
        expect(
          result.error,
          contains(
            'Swap transaction unexpectedly sends native funds for a token sale',
          ),
        );
        expect(wallet.capturedRequest, isNull);
      },
    );

    test(
      'CH-INV-06: Missing or null transaction executable fields fail closed in SwapExecutionService',
      () async {
        final executionService = SwapExecutionService(walletService: wallet);

        // Missing txTo
        final missingTxTo = SwapQuote(
          amountOutWei: '1000',
          minAmountOutWei: '990',
          amountOutFormatted: '1.0',
          minAmountOutFormatted: '0.99',
          networkFeeUsd: 0,
          networkFeeNative: 0.001,
          allowanceTarget: '',
          allowanceSpender: null,
          needsAllowance: false,
          hasBalanceIssue: false,
          balanceNeeded: null,
          balanceActual: null,
          txTo: null, // missing
          txData: '0x1234',
          txValue: '0',
          txGasPrice: '20000000000',
        );
        final res1 = await executionService.execute(
          quote: missingTxTo,
          fromToken: usdtToken,
          toToken: wrwaToken,
          fromAmountWei: '1000',
          expectedToAmount: 1.0,
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );
        expect(res1.success, isFalse);
        expect(res1.error, contains('missing executable transaction fields'));

        // Missing txGasPrice
        final missingGasPrice = SwapQuote(
          amountOutWei: '1000',
          minAmountOutWei: '990',
          amountOutFormatted: '1.0',
          minAmountOutFormatted: '0.99',
          networkFeeUsd: 0,
          networkFeeNative: 0.001,
          allowanceTarget: '',
          allowanceSpender: null,
          needsAllowance: false,
          hasBalanceIssue: false,
          balanceNeeded: null,
          balanceActual: null,
          txTo: AssetChainSwapService.mainnetRouterAddress,
          txData: '0x1234',
          txValue: '0',
          txGasPrice: null, // missing
        );
        final res2 = await executionService.execute(
          quote: missingGasPrice,
          fromToken: usdtToken,
          toToken: wrwaToken,
          fromAmountWei: '1000',
          expectedToAmount: 1.0,
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );
        expect(res2.success, isFalse);
        expect(res2.error, contains('missing executable transaction fields'));

        // Missing txValue
        final missingTxValue = SwapQuote(
          amountOutWei: '1000',
          minAmountOutWei: '990',
          amountOutFormatted: '1.0',
          minAmountOutFormatted: '0.99',
          networkFeeUsd: 0,
          networkFeeNative: 0.001,
          allowanceTarget: '',
          allowanceSpender: null,
          needsAllowance: false,
          hasBalanceIssue: false,
          balanceNeeded: null,
          balanceActual: null,
          txTo: AssetChainSwapService.mainnetRouterAddress,
          txData: '0x1234',
          txValue: null, // missing
          txGasPrice: '20000000000',
        );
        final res3 = await executionService.execute(
          quote: missingTxValue,
          fromToken: usdtToken,
          toToken: wrwaToken,
          fromAmountWei: '1000',
          expectedToAmount: 1.0,
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );
        expect(res3.success, isFalse);
        expect(res3.error, contains('missing executable transaction fields'));
      },
    );
  });

  group('CHALLENGE SUITE 2: Slippage Floor Calculation & Front-Running Prevention', () {
    test(
      'CH-SLIP-01: calculateAmountOutMinimum strictly throws ArgumentError for negative or out-of-range slippage',
      () {
        final quoted = BigInt.from(1000000);
        expect(
          () => AssetChainSwapService.calculateAmountOutMinimum(quoted, -1),
          throwsArgumentError,
        );
        expect(
          () => AssetChainSwapService.calculateAmountOutMinimum(quoted, -500),
          throwsArgumentError,
        );
        expect(
          () => AssetChainSwapService.calculateAmountOutMinimum(quoted, 10000),
          throwsArgumentError,
        );
        expect(
          () => AssetChainSwapService.calculateAmountOutMinimum(quoted, 20000),
          throwsArgumentError,
        );
      },
    );

    test(
      'CH-SLIP-02: Boundary slippage values [0, 9999] compute strictly valid floors',
      () {
        final quoted = BigInt.from(10000000);

        // 0 BPS: exactly 100% of quote
        final min0 = AssetChainSwapService.calculateAmountOutMinimum(quoted, 0);
        expect(min0, quoted);

        // 50 BPS (0.5%): 9,950,000
        final min50 = AssetChainSwapService.calculateAmountOutMinimum(
          quoted,
          50,
        );
        expect(min50, BigInt.from(9950000));

        // 1000 BPS (10%): 9,000,000
        final min1000 = AssetChainSwapService.calculateAmountOutMinimum(
          quoted,
          1000,
        );
        expect(min1000, BigInt.from(9000000));

        // 9999 BPS (99.99%): 1,000
        final min9999 = AssetChainSwapService.calculateAmountOutMinimum(
          quoted,
          9999,
        );
        expect(min9999, BigInt.from(1000));
      },
    );

    test(
      'CH-SLIP-03: Monotonic floor invariant: higher slippage BPS strictly yields <= minimum output',
      () {
        final quoted = BigInt.parse('1000000000000000000'); // 1e18
        final testBpsTiers = [0, 10, 50, 100, 250, 500, 1000, 2500, 5000, 9999];

        BigInt prevFloor = quoted;
        for (final bps in testBpsTiers) {
          final floor = AssetChainSwapService.calculateAmountOutMinimum(
            quoted,
            bps,
          );
          expect(
            floor <= prevFloor,
            isTrue,
            reason:
                'Floor for $bps BPS ($floor) must be <= floor for lower BPS ($prevFloor)',
          );
          expect(floor <= quoted, isTrue);
          expect(floor >= BigInt.zero, isTrue);
          prevFloor = floor;
        }
      },
    );

    test(
      'CH-SLIP-04: Dust amount handling never yields negative or overflowing minimum output',
      () {
        // Quoted 1 wei with 50 BPS slippage: 1 * 9950 / 10000 = 0 (integer division rounds down)
        expect(
          AssetChainSwapService.calculateAmountOutMinimum(BigInt.one, 50),
          BigInt.zero,
        );

        // Quoted 0 wei: 0
        expect(
          AssetChainSwapService.calculateAmountOutMinimum(BigInt.zero, 50),
          BigInt.zero,
        );

        // Large 256-bit BigInt value does not overflow Dart BigInt
        final largeBigInt = BigInt.parse(
          '115792089237316195423570985008687907853269984665640564039457584007913129639935',
        ); // 2^256 - 1
        final largeMin = AssetChainSwapService.calculateAmountOutMinimum(
          largeBigInt,
          50,
        );
        expect(largeMin < largeBigInt, isTrue);
        expect(largeMin > BigInt.zero, isTrue);
      },
    );

    test(
      'CH-SLIP-05: Adversarial front-running quote with tampered minAmountOut below floor is rejected by SwapExecutionService',
      () async {
        // Legitimate expected output is 100.0 USDT.
        // Attacker alters quote to offer 50.0 USDT minAmountOut (50% drop, violating user 0.5% slippage).
        final frontrunQuote = SwapQuote(
          amountOutWei: '100000000',
          minAmountOutWei: '50000000', // Siphoned / sandwich attacked!
          amountOutFormatted: '100.0',
          minAmountOutFormatted: '50.0',
          networkFeeUsd: 0,
          networkFeeNative: 0.001,
          allowanceTarget: AssetChainSwapService.mainnetRouterAddress,
          allowanceSpender: AssetChainSwapService.mainnetRouterAddress,
          needsAllowance: false,
          hasBalanceIssue: false,
          balanceNeeded: null,
          balanceActual: null,
          txTo: AssetChainSwapService.mainnetRouterAddress,
          txData: '0x414bf3891234',
          txValue: '1000000000000000000',
          txGas: '250000',
          txGasPrice: '20000000000',
        );

        final executionService = SwapExecutionService(walletService: wallet);
        final result = await executionService.execute(
          quote: frontrunQuote,
          fromToken: nativeRwa,
          toToken: usdtToken,
          fromAmountWei: '1000000000000000000',
          expectedToAmount:
              100.0, // User agreed to 100.0 USDT with 50 BPS slippage
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );

        expect(result.success, isFalse);
        expect(
          result.error,
          contains(
            'The current swap rate is worse than the quote you approved',
          ),
        );
        expect(wallet.capturedRequest, isNull);
      },
    );

    test(
      'CH-SLIP-06: Genuine AssetChainSwapService quote always clears SwapExecutionService floor check',
      () async {
        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final feeResponse = feeRpcResponse(body);
            if (feeResponse != null) return feeResponse;
            final params = body['params'] as List<dynamic>;
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x${pool.replaceAll('0x', '').padLeft(64, '0')}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (data.startsWith('0xc6a5026a')) {
              // 100 USDT = 100,000,000 base units
              final outHex = BigInt.from(
                100000000,
              ).toRadixString(16).padLeft(64, '0');
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
            throw StateError('Unexpected RPC call');
          }),
        );

        final swapService = AssetChainSwapService(web3Client: client);
        final quote = await swapService.getQuote(
          chainId: 42420,
          fromTokenAddress: '',
          toTokenAddress: usdtToken.contractAddress!,
          amountInWei: BigInt.parse('1000000000000000000'),
          buyTokenDecimals: 6,
          slippageBps: 50,
          walletAddress: '0x1111111111111111111111111111111111111111',
          useFirmQuote: true,
        );

        expect(quote, isNotNull);
        final executionService = SwapExecutionService(walletService: wallet);
        final result = await executionService.execute(
          quote: quote!,
          fromToken: nativeRwa,
          toToken: usdtToken,
          fromAmountWei: '1000000000000000000',
          expectedToAmount: double.parse(quote.amountOutFormatted),
          slippageBps: 50,
          blockchain: blockchain,
          recipientAddress: '0x1111111111111111111111111111111111111111',
          isGasless: false,
        );

        expect(result.success, isTrue);
        expect(wallet.capturedRequest, isNotNull);
      },
    );
  });

  group('CHALLENGE SUITE 3: Simulation Resilience & Quoter Revert Fallback', () {
    test(
      'CH-SIM-01: Quoter reverts with "execution reverted: Unexpected error" falls back to slot0 calculation',
      () async {
        int quoterCallCount = 0;
        int slot0CallCount = 0;

        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final feeResponse = feeRpcResponse(body);
            if (feeResponse != null) return feeResponse;
            final params = body['params'] as List<dynamic>;
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              // getPool: valid pool address
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x${pool.replaceAll('0x', '').padLeft(64, '0')}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (data.startsWith('0xc6a5026a')) {
              quoterCallCount++;
              // Quoter reverts with RPC error
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
              slot0CallCount++;
              // slot0 returns sqrtPriceX96 = 2^96 (1:1 price ratio)
              final sqrtPriceX96 = BigInt.one << 96;
              final hex = sqrtPriceX96.toRadixString(16).padLeft(64, '0');
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x$hex${'0' * 64}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            throw StateError('Unexpected RPC call: $data');
          }),
        );

        final swapService = AssetChainSwapService(web3Client: client);
        final quote = await swapService.getQuote(
          chainId: 42420,
          fromTokenAddress: wrwaToken.contractAddress!,
          toTokenAddress: usdtToken.contractAddress!,
          amountInWei: BigInt.parse('1000000000000000000'), // 1e18
        );

        expect(quote, isNull);
        expect(swapService.lastError, contains('No liquidity pool'));
        expect(
          quoterCallCount > 0,
          isTrue,
          reason: 'Quoter must be called first',
        );

        final estimate = await swapService.getBestQuoteResult(
          chainId: 42420,
          tokenInAddress: wrwaToken.contractAddress!,
          tokenOutAddress: usdtToken.contractAddress!,
          amountInWei: BigInt.parse('1000000000000000000'),
          candidates: [
            const AssetChainPoolCandidate(
              poolAddress: '0x63b1086e9e993612106955b770e1c8239ddd1dde',
              fee: 3000,
            ),
          ],
          allowSlot0Fallback: true,
        );
        expect(estimate, isNotNull);
        expect(
          slot0CallCount > 0,
          isTrue,
          reason: 'slot0 fallback triggered when explicitly enabled',
        );
        expect(estimate!.amountOut > BigInt.zero, isTrue);
      },
    );

    test(
      'CH-SIM-02: Slot0 math bidirectional test (token0 -> token1 and token1 -> token0)',
      () {
        final tokenA = '0x1000000000000000000000000000000000000001';
        final tokenB = '0x2000000000000000000000000000000000000002';
        // tokenA < tokenB, so tokenA is token0, tokenB is token1

        // Price = 1:1, sqrtPriceX96 = 2^96
        final sqrt1to1 = BigInt.one << 96;
        final amountIn = BigInt.from(1000000);
        final fee = 3000; // 0.3% fee

        // Direction 1: token0 -> token1 (isToken0 = true)
        final out0to1 = AssetChainSwapService.calculateAmountOutFromSlot0(
          tokenIn: tokenA,
          tokenOut: tokenB,
          amountIn: amountIn,
          fee: fee,
          sqrtPriceX96: sqrt1to1,
        );
        // amountInWithFee = 1000000 * 997000 / 1000000 = 997000
        expect(out0to1, BigInt.from(997000));

        // Direction 2: token1 -> token0 (isToken0 = false)
        final out1to0 = AssetChainSwapService.calculateAmountOutFromSlot0(
          tokenIn: tokenB,
          tokenOut: tokenA,
          amountIn: amountIn,
          fee: fee,
          sqrtPriceX96: sqrt1to1,
        );
        expect(out1to0, BigInt.from(997000));

        // Price = 4:1 (token1/token0 = 4), sqrtPriceX96 = 2 * 2^96
        final sqrt4to1 = (BigInt.from(2)) << 96;

        // Selling token0 for token1 at 4:1 -> amountOut should be 4 * amountInWithFee
        final out0to1P4 = AssetChainSwapService.calculateAmountOutFromSlot0(
          tokenIn: tokenA,
          tokenOut: tokenB,
          amountIn: amountIn,
          fee: fee,
          sqrtPriceX96: sqrt4to1,
        );
        expect(out0to1P4, BigInt.from(997000 * 4));

        // Selling token1 for token0 at 4:1 -> amountOut should be amountInWithFee / 4
        final out1to0P4 = AssetChainSwapService.calculateAmountOutFromSlot0(
          tokenIn: tokenB,
          tokenOut: tokenA,
          amountIn: amountIn,
          fee: fee,
          sqrtPriceX96: sqrt4to1,
        );
        expect(out1to0P4, BigInt.from(997000 ~/ 4));
      },
    );

    test(
      'CH-SIM-03: Quoter throws HTTP 500 error does not crash and attempts slot0 fallback',
      () async {
        int slot0Attempted = 0;

        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final feeResponse = feeRpcResponse(body);
            if (feeResponse != null) return feeResponse;
            final params = body['params'] as List<dynamic>;
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x${pool.replaceAll('0x', '').padLeft(64, '0')}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (data.startsWith('0xc6a5026a')) {
              // Server responds with 500 Internal Server Error
              return http.Response('Internal Server Error', 500);
            }

            if (data.startsWith('0x3850c7bd')) {
              slot0Attempted++;
              final sqrtPriceX96 = BigInt.one << 96;
              final hex = sqrtPriceX96.toRadixString(16).padLeft(64, '0');
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x$hex${'0' * 64}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            throw StateError('Unexpected RPC call: $data');
          }),
        );

        final swapService = AssetChainSwapService(web3Client: client);
        final quote = await swapService.getQuote(
          chainId: 42420,
          fromTokenAddress: wrwaToken.contractAddress!,
          toTokenAddress: usdtToken.contractAddress!,
          amountInWei: BigInt.parse('1000000000000000000'),
        );

        expect(quote, isNull);
        expect(swapService.lastError, contains('No liquidity pool'));

        final estimate = await swapService.getBestQuoteResult(
          chainId: 42420,
          tokenInAddress: wrwaToken.contractAddress!,
          tokenOutAddress: usdtToken.contractAddress!,
          amountInWei: BigInt.parse('1000000000000000000'),
          candidates: [
            const AssetChainPoolCandidate(
              poolAddress: '0x63b1086e9e993612106955b770e1c8239ddd1dde',
              fee: 3000,
            ),
          ],
          allowSlot0Fallback: true,
        );
        expect(estimate, isNotNull);
        expect(slot0Attempted > 0, isTrue);
      },
    );

    test(
      'CH-SIM-04: Both Quoter AND slot0 revert returns null with user-friendly error without crashing',
      () async {
        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final feeResponse = feeRpcResponse(body);
            if (feeResponse != null) return feeResponse;
            final params = body['params'] as List<dynamic>;
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x${pool.replaceAll('0x', '').padLeft(64, '0')}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            // Both Quoter and slot0 revert
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': body['id'],
                'error': {
                  'code': 3,
                  'message': 'execution reverted: pool locked',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final swapService = AssetChainSwapService(web3Client: client);
        final quote = await swapService.getQuote(
          chainId: 42420,
          fromTokenAddress: wrwaToken.contractAddress!,
          toTokenAddress: usdtToken.contractAddress!,
          amountInWei: BigInt.parse('1000000000000000000'),
        );

        expect(quote, isNull);
        expect(
          swapQuoteErrorMessage(swapService.lastError!),
          swapRouteUnavailableMessage,
        );
      },
    );

    test(
      'CH-SIM-05: Corrupted / empty Quoter return does not throw RangeError and falls back to slot0',
      () async {
        final client = Web3Client(
          'https://rpc.offline.test',
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final feeResponse = feeRpcResponse(body);
            if (feeResponse != null) return feeResponse;
            final params = body['params'] as List<dynamic>;
            final tx = params[0] as Map<String, dynamic>;
            final data = tx['data'] as String;

            if (data.startsWith('0x1698ee82')) {
              const pool = '0x63b1086e9e993612106955b770e1c8239ddd1dde';
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x${pool.replaceAll('0x', '').padLeft(64, '0')}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (data.startsWith('0xc6a5026a')) {
              // Malformed short return value: 0x1234
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x1234',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (data.startsWith('0x3850c7bd')) {
              final sqrtPriceX96 = BigInt.one << 96;
              final hex = sqrtPriceX96.toRadixString(16).padLeft(64, '0');
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x$hex${'0' * 64}',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            throw StateError('Unexpected RPC call: $data');
          }),
        );

        final swapService = AssetChainSwapService(web3Client: client);
        final quote = await swapService.getQuote(
          chainId: 42420,
          fromTokenAddress: wrwaToken.contractAddress!,
          toTokenAddress: usdtToken.contractAddress!,
          amountInWei: BigInt.parse('1000000000000000000'),
        );

        expect(quote, isNull);
        expect(swapService.lastError, contains('No liquidity pool'));

        final estimate = await swapService.getBestQuoteResult(
          chainId: 42420,
          tokenInAddress: wrwaToken.contractAddress!,
          tokenOutAddress: usdtToken.contractAddress!,
          amountInWei: BigInt.parse('1000000000000000000'),
          candidates: [
            const AssetChainPoolCandidate(
              poolAddress: '0x63b1086e9e993612106955b770e1c8239ddd1dde',
              fee: 3000,
            ),
          ],
          allowSlot0Fallback: true,
        );
        expect(estimate, isNotNull);
        expect(
          BigInt.parse(estimate!.amountOut.toString()) > BigInt.zero,
          isTrue,
        );
      },
    );
  });

  group(
    'CHALLENGE SUITE 4: Pool Discovery Across Non-Existent Pairs & Input Validation',
    () {
      test(
        'CH-POOL-01: Non-existent pair (factory returns 0x0 for all fee tiers) sets "No liquidity pool found"',
        () async {
          final client = Web3Client(
            'https://rpc.offline.test',
            MockClient((request) async {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              final feeResponse = feeRpcResponse(body);
              if (feeResponse != null) return feeResponse;
              // Factory returns zero address (no pool deployed for fee tier)
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

          final swapService = AssetChainSwapService(web3Client: client);
          final pools = await swapService.discoverPools(
            chainId: 42420,
            tokenInAddress: '0x1111111111111111111111111111111111111111',
            tokenOutAddress: '0x9999999999999999999999999999999999999999',
          );
          expect(pools, isEmpty);

          final quote = await swapService.getQuote(
            chainId: 42420,
            fromTokenAddress: '0x1111111111111111111111111111111111111111',
            toTokenAddress: '0x9999999999999999999999999999999999999999',
            amountInWei: BigInt.from(1000),
          );

          expect(quote, isNull);
          expect(swapService.lastError, contains('No liquidity pool found'));
        },
      );

      test(
        'CH-POOL-02: SwapService preserves the Asset Chain backend route error',
        () async {
          final swapService = SwapService(
            httpClientService: HttpClientServiceMock(
              MockClient((request) async {
                expect(request.url.queryParameters['chainId'], '42420');
                return http.Response(
                  '{"message":"No liquidity pool found for this pair on Asset Chain."}',
                  404,
                );
              }),
            ),
          );

          final quote = await swapService.get0xQuote(
            chainId: 42420,
            fromTokenAddress: '0x1111111111111111111111111111111111111111',
            toTokenAddress: '0x9999999999999999999999999999999999999999',
            amountWei: '1000000000000000000',
            buyTokenDecimals: 18,
            isGasless: false,
          );

          expect(quote, isNull);
          expect(swapService.lastError, swapRouteUnavailableMessage);
        },
      );

      test(
        'CH-POOL-03: Factory contract revert (RPC error) is caught gracefully without throwing unhandled exceptions',
        () async {
          final client = Web3Client(
            'https://rpc.offline.test',
            MockClient((request) async {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              final feeResponse = feeRpcResponse(body);
              if (feeResponse != null) return feeResponse;
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'error': {
                    'code': -32000,
                    'message': 'execution reverted: Factory unavailable',
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          );

          final swapService = AssetChainSwapService(web3Client: client);
          final pools = await swapService.discoverPools(
            chainId: 42420,
            tokenInAddress: '0x1111111111111111111111111111111111111111',
            tokenOutAddress: '0x2222222222222222222222222222222222222222',
          );

          expect(pools, isEmpty);

          final quote = await swapService.getQuote(
            chainId: 42420,
            fromTokenAddress: '0x1111111111111111111111111111111111111111',
            toTokenAddress: '0x2222222222222222222222222222222222222222',
            amountInWei: BigInt.from(1000),
          );

          expect(quote, isNull);
          expect(swapService.lastError, contains('No liquidity pool found'));
        },
      );

      test(
        'CH-POOL-04: Swapping token to itself (WRWA to WRWA or Native to WRWA) is rejected with clean error',
        () async {
          final swapService = AssetChainSwapService();

          // WRWA to WRWA
          final quote1 = await swapService.getQuote(
            chainId: 42420,
            fromTokenAddress: AssetChainSwapService.mainnetWrwaAddress,
            toTokenAddress: AssetChainSwapService.mainnetWrwaAddress,
            amountInWei: BigInt.from(1000),
          );
          expect(quote1, isNull);
          expect(
            swapService.lastError,
            contains('Cannot swap token to itself'),
          );

          // Native RWA to WRWA (both resolve to WRWA internally)
          final quote2 = await swapService.getQuote(
            chainId: 42420,
            fromTokenAddress: '',
            toTokenAddress: AssetChainSwapService.mainnetWrwaAddress,
            amountInWei: BigInt.from(1000),
          );
          expect(quote2, isNull);
          expect(
            swapService.lastError,
            contains('Cannot swap token to itself'),
          );
        },
      );

      test(
        'CH-POOL-05: Non-positive swap amounts are rejected with clean error',
        () async {
          final swapService = AssetChainSwapService();

          final quoteZero = await swapService.getQuote(
            chainId: 42420,
            fromTokenAddress: '',
            toTokenAddress: usdtToken.contractAddress!,
            amountInWei: BigInt.zero,
          );
          expect(quoteZero, isNull);
          expect(swapService.lastError, contains('greater than zero'));

          final quoteNegative = await swapService.getQuote(
            chainId: 42420,
            fromTokenAddress: '',
            toTokenAddress: usdtToken.contractAddress!,
            amountInWei: BigInt.from(-100),
          );
          expect(quoteNegative, isNull);
          expect(swapService.lastError, contains('greater than zero'));
        },
      );

      test(
        'CH-POOL-06: Unsupported chainId returns null with explicit error',
        () async {
          final swapService = AssetChainSwapService();

          final quote = await swapService.getQuote(
            chainId: 1, // Ethereum Mainnet, not Asset Chain
            fromTokenAddress: '',
            toTokenAddress: usdtToken.contractAddress!,
            amountInWei: BigInt.from(1000),
          );
          expect(quote, isNull);
          expect(
            swapService.lastError,
            contains('Unsupported chainId for Asset Chain swap'),
          );
        },
      );
    },
  );
}
