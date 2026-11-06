import 'package:fomowl_wallet/services/wallet_service.dart';

class FakeWalletService extends WalletService {
  FakeWalletService({
    this.walletAddress = '0xbF75A6D2F5824A42b0BF946c15580A5f504c8c5F',
    this.messageSignature = '0xmock-message-signature',
    this.typedDataSignature = '0xmock-typed-data-signature',
    this.transactionHash =
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  });

  final String walletAddress;
  final String messageSignature;
  final String typedDataSignature;
  final String transactionHash;

  String? lastSignedMessage;
  String? lastTypedData;
  String? lastTransactionTo;
  String? lastRpcUrl;
  int? lastChainId;

  @override
  Future<String?> getCurrentWalletAddress() async => walletAddress;

  @override
  Future<String> signMessageForAddress(String? address, String message) async {
    lastSignedMessage = message;
    return messageSignature;
  }

  @override
  Future<String> signTypedDataForAddress(
    String? address,
    String jsonData,
  ) async {
    lastTypedData = jsonData;
    return typedDataSignature;
  }

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
    lastRpcUrl = rpcUrl;
    lastChainId = chainId;
    lastTransactionTo = toAddress;
    return transactionHash;
  }
}
