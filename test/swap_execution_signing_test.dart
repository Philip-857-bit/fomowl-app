import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/evm_transaction_service.dart';
import 'package:fomowl_wallet/services/swap_service.dart';
import 'package:fomowl_wallet/services/swap_execution_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

class _Wallet extends WalletService {
  Map<String, Object?>? request;

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
    Future<void> Function(EvmSignedTransaction transaction)? beforeBroadcast,
    Future<void> Function()? abortedBeforeBroadcast,
    void Function()? validateBeforeSigning,
  }) async {
    request = {
      'rpc': rpcUrl,
      'chain': chainId,
      'to': toAddress,
      'value': valueInWei,
      'data': dataHex,
      'gasPrice': gasPriceWei,
      'gasLimit': gasLimit,
    };
    return '0xhash';
  }
}

const _token = Token(
  symbol: 'TST',
  name: 'Token',
  contractAddress: '0x1111111111111111111111111111111111111111',
  balance: 1,
  valueUsd: 1,
  changePercent24h: 0,
  decimals: 6,
);
const _native = Token(
  symbol: 'ETH',
  name: 'Ether',
  balance: 1,
  valueUsd: 1,
  changePercent24h: 0,
);

SwapQuote _quote({String value = '0', String output = '1000000'}) => SwapQuote(
  amountOutWei: output,
  minAmountOutWei: output,
  amountOutFormatted: '1',
  minAmountOutFormatted: '1',
  networkFeeUsd: 0,
  networkFeeNative: 0,
  allowanceTarget: '0x2222222222222222222222222222222222222222',
  allowanceSpender: null,
  needsAllowance: false,
  hasBalanceIssue: false,
  balanceNeeded: null,
  balanceActual: null,
  txTo: '0x3333333333333333333333333333333333333333',
  txData: '0x1234',
  txValue: value,
  txGas: '0x186a0',
  txGasPrice: '0x3b9aca00',
  analyticsEventId: 'event-1',
);

void main() {
  late BlockchainService blockchain;
  setUp(() => blockchain = BlockchainService());
  tearDown(() => blockchain.dispose());

  Future<SwapExecutionResult> execute(
    _Wallet wallet,
    SwapQuote quote, {
    Token from = _token,
  }) => SwapExecutionService(walletService: wallet).execute(
    quote: quote,
    fromToken: from,
    toToken: _token,
    fromAmountWei: '1000',
    expectedToAmount: 1,
    slippageBps: 100,
    blockchain: blockchain,
    recipientAddress: '0x4444444444444444444444444444444444444444',
    isGasless: false,
  );

  test(
    'standard swap forwards the approved transaction to the Rust wallet path',
    () async {
      final wallet = _Wallet();
      final result = await execute(wallet, _quote());
      expect(result.success, isTrue);
      expect(result.transactionHash, '0xhash');
      expect(result.analyticsEventId, 'event-1');
      expect(wallet.request, {
        'rpc': blockchain.activeChain.rpcUrl,
        'chain': blockchain.activeChain.chainId,
        'to': '0x3333333333333333333333333333333333333333',
        'value': BigInt.zero,
        'data': '0x1234',
        'gasPrice': BigInt.from(1000000000),
        'gasLimit': 100000,
      });
    },
  );

  test('native swap preserves the exact sell value', () async {
    final wallet = _Wallet();
    expect(
      (await execute(wallet, _quote(value: '1000'), from: _native)).success,
      isTrue,
    );
    expect(wallet.request?['value'], BigInt.from(1000));
  });

  test('token sale cannot send unapproved native funds', () async {
    final wallet = _Wallet();
    expect((await execute(wallet, _quote(value: '1'))).success, isFalse);
    expect(wallet.request, isNull);
  });

  test('native sale cannot exceed the approved input amount', () async {
    final wallet = _Wallet();
    expect(
      (await execute(wallet, _quote(value: '1001'), from: _native)).success,
      isFalse,
    );
    expect(wallet.request, isNull);
  });

  test('slippage floor remains enforced before signing', () async {
    final wallet = _Wallet();
    expect((await execute(wallet, _quote(output: '1'))).success, isFalse);
    expect(wallet.request, isNull);
  });

  test('unparseable output fails closed before signing', () async {
    final wallet = _Wallet();
    expect((await execute(wallet, _quote(output: 'bad'))).success, isFalse);
    expect(wallet.request, isNull);
  });
}
