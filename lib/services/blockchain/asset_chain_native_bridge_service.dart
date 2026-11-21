import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import '../../models/chain.dart';
import '../../utils/amount_utils.dart';
import '../wallet_service.dart';
import 'asset_chain_bridge_client.dart';
import 'asset_chain_bridge_contract.dart';
import 'blockchain_catalog.dart';

class AssetChainNativeBridgeRoute {
  final AssetChainBridgeDeployment source;
  final AssetChainBridgeDeployment destination;
  final EvmChain sourceChain;
  final EvmChain destinationChain;
  const AssetChainNativeBridgeRoute(
    this.source,
    this.destination,
    this.sourceChain,
    this.destinationChain,
  );
  String get id => '${source.id}:${destination.id}';
  String get symbol => source.token!.symbol;
  bool get isNative =>
      source.token!.tokenAddress.toLowerCase() ==
      AssetChainNativeBridgeService.nativeToken;
}

class AssetChainNativeBridgeQuote {
  final AssetChainNativeBridgeRoute route;
  final BigInt amount;
  final BigInt? _bridgeAmount;
  final BigInt? _platformFeeAmount;
  final int platformFeeBps;
  final double? platformFeeUsd;
  final String? platformFeeRecipient;
  final double? amountUsd;
  final BigInt receivedAmount;
  final BigInt sendRate;
  final BigInt receiveRate;
  final BigInt sendFee;
  final BigInt receiveFee;
  final BigInt denominator;

  const AssetChainNativeBridgeQuote({
    required this.route,
    required this.amount,
    BigInt? bridgeAmount,
    BigInt? platformFeeAmount,
    this.platformFeeBps = 0,
    this.platformFeeUsd,
    this.platformFeeRecipient,
    this.amountUsd,
    required this.receivedAmount,
    required this.sendRate,
    required this.receiveRate,
    required this.sendFee,
    required this.receiveFee,
    required this.denominator,
  }) : _bridgeAmount = bridgeAmount,
       _platformFeeAmount = platformFeeAmount;

  BigInt get bridgeAmount => _bridgeAmount ?? amount;
  BigInt get platformFeeAmount => _platformFeeAmount ?? BigInt.zero;

  String get receivedText => AmountUtils.formatBaseUnits(
    receivedAmount,
    route.destination.tokenDecimal,
    maxFractionDigits: route.destination.tokenDecimal,
  );
}

/// Non-custodial BridgeAssist send/fulfill execution. Configuration and signatures
/// come from the backend proxy; chain reads verify its contract/token identity.
class AssetChainNativeBridgeService {
  static const nativeToken = '0x0000000000000000000000000000000000000001';
  static const _zeroAddressHex = '0x0000000000000000000000000000000000000000';
  static const _journalKey = 'owllet.assetchain.bridge.pending.v1';
  static final _bridgeAbi = ContractAbi.fromJson(
    assetChainBridgeContractAbi,
    'BridgeAssist',
  );
  static final _erc20Abi = ContractAbi.fromJson('''[
    {"type":"function","name":"balanceOf","stateMutability":"view","inputs":[{"name":"owner","type":"address"}],"outputs":[{"name":"","type":"uint256"}]},
    {"type":"function","name":"allowance","stateMutability":"view","inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"outputs":[{"name":"","type":"uint256"}]},
    {"type":"function","name":"approve","stateMutability":"nonpayable","inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]},
    {"type":"function","name":"transfer","stateMutability":"nonpayable","inputs":[{"name":"to","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]}
  ]''', 'ERC20');

  final AssetChainBridgeClient api;
  final WalletService wallet;
  final Web3Client Function(EvmChain)? clientFactory;
  final Map<int, Web3Client> _clients = {};

  AssetChainNativeBridgeService({
    AssetChainBridgeClient? api,
    WalletService? wallet,
    this.clientFactory,
  }) : api = api ?? AssetChainBridgeClient.fromEnvironment(),
       wallet = wallet ?? WalletService();

  Web3Client _client(EvmChain chain) => _clients.putIfAbsent(
    chain.chainId,
    () => clientFactory?.call(chain) ?? Web3Client(chain.rpcUrl, http.Client()),
  );

  void dispose() {
    for (final client in _clients.values) {
      client.dispose();
    }
    api.dispose();
  }

  static String normalizedSymbol(String value) => switch (value.toUpperCase()) {
    'XRWA' => 'RWA',
    'USDT0' || 'USD₮0' => 'USDT',
    _ => value.toUpperCase(),
  };

  static List<AssetChainNativeBridgeRoute> routes(
    List<AssetChainBridgeDeployment> deployments,
    List<EvmChain> chains,
  ) {
    final byId = {
      for (final chain in chains)
        if (chain.family == ChainFamily.evm) chain.chainId: chain,
    };
    final result = <AssetChainNativeBridgeRoute>[];
    for (final source in deployments) {
      final srcId = int.tryParse(source.chainId);
      final srcChain = byId[srcId];
      if (srcChain == null || source.token == null || source.id.isEmpty) {
        continue;
      }
      for (final destination in deployments) {
        final dstId = int.tryParse(destination.chainId);
        final dstChain = byId[dstId];
        if (dstChain == null ||
            destination.token == null ||
            destination.id.isEmpty ||
            srcId == dstId) {
          continue;
        }
        if (!BlockchainCatalog.isAssetChain(srcId!) &&
            !BlockchainCatalog.isAssetChain(dstId!)) {
          continue;
        }
        // A configured testnet must never be paired with the mainnet deployment.
        if ((srcId == 42421 && dstId == 42420) ||
            (srcId == 42420 && dstId == 42421)) {
          continue;
        }
        if (normalizedSymbol(source.token!.symbol) !=
            normalizedSymbol(destination.token!.symbol)) {
          continue;
        }
        if (source.token!.chainId != source.chainId ||
            destination.token!.chainId != destination.chainId) {
          continue;
        }
        if (source.tokenDecimal != source.token!.decimal ||
            destination.tokenDecimal != destination.token!.decimal) {
          continue;
        }
        if (source.tokenDecimal < 0 ||
            source.tokenDecimal > 36 ||
            destination.tokenDecimal < 0 ||
            destination.tokenDecimal > 36) {
          continue;
        }
        result.add(
          AssetChainNativeBridgeRoute(source, destination, srcChain, dstChain),
        );
      }
    }
    return result;
  }

  DeployedContract _contract(AssetChainBridgeDeployment deployment) =>
      DeployedContract(
        _bridgeAbi,
        EthereumAddress.fromHex(deployment.bridgeAddress),
      );
  Future<List<dynamic>> _read(
    EvmChain chain,
    DeployedContract contract,
    String method, [
    List<dynamic> args = const [],
  ]) => _client(chain)
      .call(
        contract: contract,
        function: contract.function(method),
        params: args,
      )
      .timeout(const Duration(seconds: 15));
  Future<BigInt> _uint(
    EvmChain chain,
    DeployedContract contract,
    String method, [
    List<dynamic> args = const [],
  ]) async => (await _read(chain, contract, method, args)).single as BigInt;

  static Uint8List _chainBytes(int id) {
    final value = utf8.encode('evm.$id');
    return Uint8List(32)..setRange(0, value.length, value);
  }

  Future<void> _verifyDeployment(
    EvmChain chain,
    AssetChainBridgeDeployment deployment,
    int counterChain,
  ) async {
    final contract = _contract(deployment);
    final actualChainId = await _client(
      chain,
    ).getChainId().timeout(const Duration(seconds: 15));
    if (actualChainId != BigInt.from(chain.chainId)) {
      throw StateError('Bridge RPC network mismatch.');
    }
    final current = (await _read(chain, contract, 'CURRENT_CHAIN')).single;
    final token =
        (await _read(chain, contract, 'TOKEN')).single as EthereumAddress;
    if (current != 'evm.${chain.chainId}' ||
        token.hex.toLowerCase() !=
            deployment.token!.tokenAddress.toLowerCase()) {
      throw StateError(
        'Bridge deployment does not match its configured network or token.',
      );
    }
    if ((await _read(chain, contract, 'paused')).single == true ||
        (await _read(chain, contract, 'isSupportedChain', [
              'evm.$counterChain',
            ])).single !=
            true) {
      throw StateError('This bridge route is currently unavailable.');
    }
  }

  static BigInt calculateReceived({
    required BigInt amount,
    required BigInt sendRate,
    required BigInt receiveRate,
    required BigInt sendFee,
    required BigInt receiveFee,
    required BigInt denominator,
  }) {
    if (denominator <= BigInt.zero ||
        sendRate <= BigInt.zero ||
        receiveRate <= BigInt.zero ||
        sendFee < BigInt.zero ||
        receiveFee < BigInt.zero ||
        sendFee >= denominator ||
        receiveFee >= denominator) {
      throw StateError('Invalid bridge rate or fee configuration.');
    }
    if (amount <= BigInt.zero ||
        amount % sendRate != BigInt.zero ||
        amount ~/ sendRate < denominator) {
      throw StateError(
        'Amount is too small or has more precision than this bridge supports.',
      );
    }
    final sent =
        amount ~/ sendRate - (amount * sendFee ~/ denominator ~/ sendRate);
    final received = sent * receiveRate;
    return received - received * receiveFee ~/ denominator;
  }

  static BigInt calculatePlatformFeeAmount({
    required BigInt totalAmount,
    required int feeBps,
    required BigInt sendRate,
  }) {
    if (totalAmount <= BigInt.zero || feeBps <= 0) return BigInt.zero;
    var fee = (totalAmount * BigInt.from(feeBps)) ~/ BigInt.from(10000);
    if (sendRate > BigInt.one && fee > BigInt.zero) {
      fee = fee - (fee % sendRate);
    }
    if (fee >= totalAmount) return BigInt.zero;
    return fee;
  }

  static ({BigInt amount, int bps, double? usd, String? recipient})
  _validatedPlatformFee({
    required AssetChainBridgeFeeQuote feeQuote,
    required BigInt totalAmount,
    required BigInt sendRate,
    required double? amountUsd,
  }) {
    if (!feeQuote.enabled ||
        feeQuote.platformFeeBps <= 0 ||
        feeQuote.feeRecipient == null) {
      return (amount: BigInt.zero, bps: 0, usd: null, recipient: null);
    }
    try {
      final recipient = EthereumAddress.fromHex(feeQuote.feeRecipient!);
      if (recipient.hex.toLowerCase() == _zeroAddressHex) {
        return (amount: BigInt.zero, bps: 0, usd: null, recipient: null);
      }
    } catch (_) {
      return (amount: BigInt.zero, bps: 0, usd: null, recipient: null);
    }
    final bps = feeQuote.platformFeeBps.clamp(0, 1000);
    final feeAmount = calculatePlatformFeeAmount(
      totalAmount: totalAmount,
      feeBps: bps,
      sendRate: sendRate,
    );
    if (feeAmount <= BigInt.zero) {
      return (amount: BigInt.zero, bps: 0, usd: null, recipient: null);
    }
    final feeUsd = feeQuote.platformFeeUsd > 0
        ? feeQuote.platformFeeUsd
        : (amountUsd != null && amountUsd.isFinite && amountUsd > 0
              ? amountUsd * (bps / 10000.0)
              : null);
    return (
      amount: feeAmount,
      bps: bps,
      usd: feeUsd,
      recipient: feeQuote.feeRecipient,
    );
  }

  Future<AssetChainNativeBridgeQuote> quote(
    AssetChainNativeBridgeRoute route,
    String amountText, {
    double? amountUsd,
  }) async {
    if (api.isMockMode) {
      throw StateError('Mock bridges cannot move wallet funds.');
    }
    final amount = AmountUtils.parseDecimalToBaseUnits(
      amountText,
      route.source.tokenDecimal,
    );
    await _verifyDeployment(
      route.sourceChain,
      route.source,
      route.destinationChain.chainId,
    );
    await _verifyDeployment(
      route.destinationChain,
      route.destination,
      route.sourceChain.chainId,
    );
    final src = _contract(route.source), dst = _contract(route.destination);
    final denominator = await _uint(route.sourceChain, src, 'FEE_DENOMINATOR');
    if (await _uint(route.destinationChain, dst, 'FEE_DENOMINATOR') !=
        denominator) {
      throw StateError('Incompatible bridge fee denominators.');
    }
    final limit = await _uint(route.sourceChain, src, 'limitPerSend');
    if (amount > limit) {
      throw StateError('Amount exceeds this bridge’s transfer limit.');
    }
    final sendRate = await _uint(route.sourceChain, src, 'exchangeRateFrom', [
      _chainBytes(route.destinationChain.chainId),
    ]);
    final receiveRate = await _uint(
      route.destinationChain,
      dst,
      'exchangeRateFrom',
      [_chainBytes(route.sourceChain.chainId)],
    );
    final sendFee = await _uint(route.sourceChain, src, 'feeSend');
    final receiveFee = await _uint(route.destinationChain, dst, 'feeFulfill');
    final feeQuote = await api.getFeeQuote(
      chainId: route.sourceChain.chainId,
      sellToken: route.source.token!.tokenAddress,
      amount: amount.toString(),
      amountUsd: amountUsd,
    );
    final platformFee = _validatedPlatformFee(
      feeQuote: feeQuote,
      totalAmount: amount,
      sendRate: sendRate,
      amountUsd: amountUsd,
    );
    final bridgeAmount = amount - platformFee.amount;
    if (bridgeAmount <= BigInt.zero) {
      throw StateError('Amount is too small after platform fee.');
    }
    return AssetChainNativeBridgeQuote(
      route: route,
      amount: amount,
      bridgeAmount: bridgeAmount,
      platformFeeAmount: platformFee.amount,
      platformFeeBps: platformFee.bps,
      platformFeeUsd: platformFee.usd,
      platformFeeRecipient: platformFee.recipient,
      amountUsd: amountUsd,
      receivedAmount: calculateReceived(
        amount: bridgeAmount,
        sendRate: sendRate,
        receiveRate: receiveRate,
        sendFee: sendFee,
        receiveFee: receiveFee,
        denominator: denominator,
      ),
      sendRate: sendRate,
      receiveRate: receiveRate,
      sendFee: sendFee,
      receiveFee: receiveFee,
      denominator: denominator,
    );
  }

  Future<void> _current(String sender, bool Function() isCurrent) async {
    if (!isCurrent() ||
        (await wallet.getCurrentWalletAddress())?.toLowerCase() !=
            sender.toLowerCase()) {
      throw StateError('The selected wallet or bridge request changed.');
    }
  }

  Future<TransactionReceipt> _receipt(EvmChain chain, String hash) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final receipt = await _client(
        chain,
      ).getTransactionReceipt(hash).timeout(const Duration(seconds: 10));
      if (receipt != null) {
        if (receipt.status != true) {
          throw StateError('Bridge transaction failed on chain: $hash');
        }
        return receipt;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    throw StateError(
      'Transaction submitted and still confirming: $hash. Refresh transfers; do not send it again.',
    );
  }

  Future<void> _save(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_journalKey) ?? [];
    items.removeWhere(
      (raw) => (jsonDecode(raw) as Map)['hash'] == item['hash'],
    );
    items.add(jsonEncode(item));
    if (!await prefs.setStringList(_journalKey, items)) {
      throw StateError('Unable to save bridge recovery record.');
    }
  }

  Future<void> _remove(String hash) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_journalKey) ?? [];
    items.removeWhere((raw) => (jsonDecode(raw) as Map)['hash'] == hash);
    await prefs.setStringList(_journalKey, items);
  }

  Future<List<Map<String, dynamic>>> pending(String sender) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_journalKey) ?? [])
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .where((item) => item['sender'] == sender.toLowerCase())
        .toList();
  }

  Future<String> _broadcast(
    EvmChain chain,
    String sender,
    EthereumAddress to,
    Uint8List data,
    BigInt value,
    bool Function() isCurrent,
  ) async {
    await _current(sender, isCurrent);
    // WalletService estimates gas and price for the exact transaction and enforces
    // the signer identity immediately before signing.
    return wallet.sendRawTransactionRequest(
      rpcUrl: chain.rpcUrl,
      chainId: chain.chainId,
      expectedFromAddress: sender,
      toAddress: to.hex,
      dataHex: '0x${bytesToHex(data)}',
      valueInWei: value,
    );
  }

  Future<String> send(
    AssetChainNativeBridgeQuote approved,
    String sender, {
    required bool Function() isCurrent,
    void Function(String)? onStatus,
  }) async {
    if ((await pending(sender)).isNotEmpty) {
      throw StateError(
        'Check the saved bridge transaction before sending again.',
      );
    }
    final route = approved.route;
    final fresh = await quote(
      route,
      AmountUtils.formatBaseUnits(
        approved.amount,
        route.source.tokenDecimal,
        maxFractionDigits: route.source.tokenDecimal,
      ),
      amountUsd: approved.amountUsd,
    );
    if (fresh.receivedAmount != approved.receivedAmount ||
        fresh.sendFee != approved.sendFee ||
        fresh.receiveFee != approved.receiveFee ||
        fresh.platformFeeBps != approved.platformFeeBps ||
        fresh.platformFeeAmount != approved.platformFeeAmount ||
        fresh.platformFeeRecipient?.toLowerCase() !=
            approved.platformFeeRecipient?.toLowerCase()) {
      throw StateError(
        'Bridge fees changed. Refresh and review the amount again.',
      );
    }
    final owner = EthereumAddress.fromHex(sender),
        bridge = _contract(route.source);
    if (route.isNative) {
      if (approved.platformFeeAmount > BigInt.zero) {
        final balance = await _client(
          route.sourceChain,
        ).getBalance(owner).timeout(const Duration(seconds: 15));
        if (balance.getInWei < approved.amount) {
          throw StateError('Insufficient ${route.symbol} balance.');
        }
      }
    } else {
      final token = DeployedContract(
        _erc20Abi,
        EthereumAddress.fromHex(route.source.token!.tokenAddress),
      );
      if (await _uint(route.sourceChain, token, 'balanceOf', [owner]) <
          approved.amount) {
        throw StateError('Insufficient ${route.symbol} balance.');
      }
      final allowance = await _uint(route.sourceChain, token, 'allowance', [
        owner,
        bridge.address,
      ]);
      if (allowance < approved.bridgeAmount) {
        onStatus?.call('Approving ${route.symbol}');
        for (final amount in [
          if (allowance > BigInt.zero) BigInt.zero,
          approved.bridgeAmount,
        ]) {
          final hash = await _broadcast(
            route.sourceChain,
            sender,
            token.address,
            token.function('approve').encodeCall([bridge.address, amount]),
            BigInt.zero,
            isCurrent,
          );
          await _receipt(route.sourceChain, hash);
        }
        if (await _uint(route.sourceChain, token, 'allowance', [
              owner,
              bridge.address,
            ]) <
            approved.bridgeAmount) {
          throw StateError(
            'Token approval did not grant the required allowance.',
          );
        }
      }
    }
    final index = await _uint(
      route.sourceChain,
      bridge,
      'getUserTransactionsAmount',
      [owner],
    );
    onStatus?.call('Submitting bridge transfer');
    final hash = await _broadcast(
      route.sourceChain,
      sender,
      bridge.address,
      bridge.function('send').encodeCall([
        approved.bridgeAmount,
        sender,
        'evm.${route.destinationChain.chainId}',
      ]),
      route.isNative ? approved.bridgeAmount : BigInt.zero,
      isCurrent,
    );
    await _save({
      'sender': sender.toLowerCase(),
      'hash': hash,
      'chain': route.sourceChain.chainId,
      'bridgeId': route.source.id,
      'index': index.toString(),
      'amount': approved.bridgeAmount.toString(),
      'kind': 'send',
    });
    onStatus?.call('Transfer submitted · awaiting confirmation');
    final receipt = await _receipt(route.sourceChain, hash);
    final matched = await _matchConfirmedSendIndex(
      chain: route.sourceChain,
      bridge: bridge,
      sender: sender,
      blockNumber: BigInt.from(receipt.blockNumber.blockNum),
      savedIndex: index,
      amount: approved.bridgeAmount,
      destinationChain: 'evm.${route.destinationChain.chainId}',
    );
    if (matched == null) {
      throw StateError(
        'Transfer confirmed. Refresh transfers to synchronize its source index; do not send again.',
      );
    }
    await api.recordTransaction(
      bridgeId: route.source.id,
      index: matched.toString(),
      userAddress: sender,
      transactionHash: hash,
    );
    await _remove(hash);
    if (approved.platformFeeAmount > BigInt.zero &&
        approved.platformFeeRecipient != null) {
      await _collectPlatformFee(
        route: route,
        sender: sender,
        approved: approved,
        isCurrent: isCurrent,
        onStatus: onStatus,
      );
    }
    return hash;
  }

  Future<void> _collectPlatformFee({
    required AssetChainNativeBridgeRoute route,
    required String sender,
    required AssetChainNativeBridgeQuote approved,
    required bool Function() isCurrent,
    void Function(String)? onStatus,
  }) async {
    final recipientHex = approved.platformFeeRecipient;
    if (approved.platformFeeAmount <= BigInt.zero || recipientHex == null) {
      return;
    }
    try {
      final recipient = EthereumAddress.fromHex(recipientHex);
      if (recipient.hex.toLowerCase() == _zeroAddressHex) return;
      onStatus?.call('Collecting platform fee');
      if (route.isNative) {
        await _broadcast(
          route.sourceChain,
          sender,
          recipient,
          Uint8List(0),
          approved.platformFeeAmount,
          isCurrent,
        );
      } else {
        final token = DeployedContract(
          _erc20Abi,
          EthereumAddress.fromHex(route.source.token!.tokenAddress),
        );
        await _broadcast(
          route.sourceChain,
          sender,
          token.address,
          token.function('transfer').encodeCall([
            recipient,
            approved.platformFeeAmount,
          ]),
          BigInt.zero,
          isCurrent,
        );
      }
    } catch (_) {
      // Bridge deposit is already confirmed and recorded; never fail or trigger
      // a duplicate retry over secondary fee transfer errors.
    }
  }

  Future<String> claim(
    AssetChainBridgeTransaction transfer,
    AssetChainNativeBridgeRoute route,
    String sender, {
    required bool Function() isCurrent,
    void Function(String)? onStatus,
  }) async {
    if (api.isMockMode) {
      throw StateError('Mock bridges cannot move wallet funds.');
    }
    if (transfer.fulfilled) throw StateError('Transfer already claimed.');
    if (transfer.toUser.toLowerCase() != sender.toLowerCase() ||
        transfer.fromUser.toLowerCase() != sender.toLowerCase() ||
        transfer.fromChain.replaceFirst('evm.', '') != route.source.chainId ||
        transfer.toChain.replaceFirst('evm.', '') !=
            route.destination.chainId ||
        (transfer.bridgeInfoId != null &&
            transfer.bridgeInfoId != route.source.id)) {
      throw StateError('Transfer does not match this wallet or bridge route.');
    }
    await _verifyDeployment(
      route.destinationChain,
      route.destination,
      route.sourceChain.chainId,
    );
    final dst = _contract(route.destination);
    final amount = BigInt.tryParse(transfer.fulfillAmount ?? '');
    final nonce = transfer.fulfillNonce;
    final fromUser = transfer.fulfillFromUser;
    final toUser = transfer.fulfillToUser;
    if (amount == null ||
        amount <= BigInt.zero ||
        nonce == null ||
        fromUser == null ||
        fromUser.toLowerCase() != sender.toLowerCase() ||
        toUser?.toLowerCase() != sender.toLowerCase() ||
        transfer.fulfillFromChain?.replaceFirst('evm.', '') !=
            route.source.chainId) {
      throw StateError(
        'Claim data is incomplete. Refresh transfers before claiming.',
      );
    }
    final fromChain = 'evm.${route.sourceChain.chainId}';
    final existing = await _uint(route.destinationChain, dst, 'fulfilledAt', [
      fromChain,
      fromUser,
      BigInt.from(nonce),
    ]);
    if (existing > BigInt.zero) {
      throw StateError(
        'Claim already exists on chain. Refresh transfers to synchronize it.',
      );
    }
    onStatus?.call('Requesting relayer signatures');
    final signatures = await api.getRelayerSignatures(
      bridgeId: route.source.id,
      index: transfer.index.toString(),
      fromUser: transfer.fromUser,
    );
    final count = (await _uint(
      route.destinationChain,
      dst,
      'relayersLength',
    )).toInt();
    if (count < 1 || signatures.signatures.length < count) {
      throw StateError(
        'Relayer signatures are not ready. Try again after more confirmations.',
      );
    }
    final sigs = signatures.signatures.take(count).map((value) {
      if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(value)) {
        throw StateError('Invalid relayer signature.');
      }
      return hexToBytes(value);
    }).toList();
    final hash = await _broadcast(
      route.destinationChain,
      sender,
      dst.address,
      dst.function('fulfill').encodeCall([
        [
          amount,
          fromUser,
          EthereumAddress.fromHex(toUser!),
          fromChain,
          BigInt.from(nonce),
        ],
        sigs,
      ]),
      BigInt.zero,
      isCurrent,
    );
    await _save({
      'sender': sender.toLowerCase(),
      'hash': hash,
      'chain': route.destinationChain.chainId,
      'kind': 'claim',
      'transactionId': transfer.id,
      'toBridgeId': route.destination.id,
    });
    onStatus?.call('Claim submitted · awaiting confirmation');
    await _receipt(route.destinationChain, hash);
    if (await _uint(route.destinationChain, dst, 'fulfilledAt', [
          fromChain,
          fromUser,
          BigInt.from(nonce),
        ]) <=
        BigInt.zero) {
      throw StateError(
        'Claim receipt did not confirm fulfillment. Refresh transfers; do not claim again.',
      );
    }
    final result = await api.updateTransactionFulfillment(
      transactionId: transfer.id,
      claimTransactionHash: hash,
      toBridgeId: route.destination.id,
    );
    if (!result.fulfilled) {
      throw StateError(
        'Claim confirmed. Bridge status is still synchronizing; refresh transfers.',
      );
    }
    await _remove(hash);
    return hash;
  }

  Future<bool> _recordConfirmedSend({
    required String sender,
    required EvmChain chain,
    required Map<String, dynamic> item,
    required BigInt blockNumber,
  }) async {
    final bridgeId = item['bridgeId']?.toString() ?? '';
    if (bridgeId.isEmpty) return false;
    final bridges = await api.getBridges(chainId: chain.chainId.toString());
    AssetChainBridgeDeployment? deployment;
    for (final candidate in bridges) {
      if (candidate.id == bridgeId) deployment = candidate;
    }
    if (deployment == null || deployment.bridgeAddress.isEmpty) return false;
    final matched = await _matchConfirmedSendIndex(
      chain: chain,
      bridge: _contract(deployment),
      sender: sender,
      blockNumber: blockNumber,
      savedIndex: BigInt.tryParse('${item['index'] ?? ''}'),
      amount: BigInt.tryParse('${item['amount'] ?? ''}'),
    );
    if (matched == null) return false;
    await api.recordTransaction(
      bridgeId: bridgeId,
      index: matched.toString(),
      userAddress: sender,
      transactionHash: item['hash'] as String,
    );
    return true;
  }

  /// The saved index is only a hint. The confirmed receipt's block, amount,
  /// and destination chain identify the source transaction. Two matches are
  /// left unresolved instead of recording the wrong index.
  Future<BigInt?> _matchConfirmedSendIndex({
    required EvmChain chain,
    required DeployedContract bridge,
    required String sender,
    required BigInt blockNumber,
    BigInt? savedIndex,
    BigInt? amount,
    String? destinationChain,
  }) async {
    final owner = EthereumAddress.fromHex(sender);
    final count = await _uint(chain, bridge, 'getUserTransactionsAmount', [
      owner,
    ]);
    if (count <= BigInt.zero) return null;
    final indexes = <BigInt>[];
    void add(BigInt index) {
      if (index < BigInt.zero || index >= count || indexes.contains(index)) {
        return;
      }
      indexes.add(index);
    }

    if (savedIndex != null) add(savedIndex);
    final window = BigInt.from(20);
    var index = count - BigInt.one;
    final stop = count > window ? count - window : BigInt.zero;
    while (index >= stop) {
      add(index);
      if (index == BigInt.zero) break;
      index -= BigInt.one;
    }
    BigInt? matched;
    for (final candidate in indexes) {
      final tx = await _read(chain, bridge, 'transactions', [owner, candidate]);
      if (tx.length < 8) continue;
      final fromUser = tx[2];
      if (fromUser is! EthereumAddress || fromUser != owner) continue;
      if (tx[3].toString().toLowerCase() != sender.toLowerCase()) continue;
      if (tx[4] != 'evm.${chain.chainId}') continue;
      if (destinationChain != null && tx[5] != destinationChain) continue;
      if (tx[7] != blockNumber) continue;
      if (amount != null && tx[0] != amount) continue;
      if (matched != null) return null;
      matched = candidate;
    }
    return matched;
  }

  /// Resume only recorded hashes. No recovery operation broadcasts a new payment.
  Future<void> synchronize(String sender, List<EvmChain> chains) async {
    final byId = {for (final chain in chains) chain.chainId: chain};
    for (final item in await pending(sender)) {
      final chain = byId[item['chain']];
      if (chain == null) {
        continue;
      }
      final receipt = await _client(
        chain,
      ).getTransactionReceipt(item['hash'] as String);
      if (receipt == null) {
        continue;
      }
      if (receipt.status == false) {
        await _remove(item['hash'] as String);
        continue;
      }
      if (receipt.status != true) {
        continue;
      }
      if (item['kind'] == 'claim') {
        final result = await api.updateTransactionFulfillment(
          transactionId: item['transactionId'] as String,
          claimTransactionHash: item['hash'] as String,
          toBridgeId: item['toBridgeId'] as String,
        );
        if (result.fulfilled) {
          await _remove(item['hash'] as String);
        }
      } else {
        final hash = item['hash'] as String;
        final result = await api.getTransactions(
          userAddress: sender,
          forceSync: true,
          limit: 100,
        );
        if (result.items.any(
          (tx) => tx.transactionHash.toLowerCase() == hash.toLowerCase(),
        )) {
          await _remove(hash);
          continue;
        }
        final recorded = await _recordConfirmedSend(
          sender: sender,
          chain: chain,
          item: item,
          blockNumber: BigInt.from(receipt.blockNumber.blockNum),
        );
        if (recorded) await _remove(hash);
      }
    }
  }
}
