import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'http_client_service.dart';
import '../models/wallet_account.dart';
import 'storage_service.dart';
import '../utils/amount_utils.dart';
import 'native_crypto.dart';

/// Wallet Service
/// Handles wallet creation, import, and key management
class WalletService {
  WalletService({StorageService? storageService})
    : _storage = storageService ?? StorageService();

  final StorageService _storage;
  final HttpClientService _httpClientService = HttpClientService();
  final Map<String, Web3Client> _web3Clients = {};
  static final ContractAbi _erc20Abi = ContractAbi.fromJson('''[
      {
        "constant": false,
        "inputs": [
          {"name": "recipient", "type": "address"},
          {"name": "amount", "type": "uint256"}
        ],
        "name": "transfer",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function"
      }
    ]''', 'ERC20');

  /// Generate a new 12-word mnemonic phrase (Rust FFI)
  Future<String> generateMnemonic() async {
    return await NativeCrypto.generateMnemonic();
  }

  /// Validate a mnemonic phrase (Rust FFI)
  Future<bool> validateMnemonic(String mnemonic) async {
    final normalizedMnemonic = normalizeMnemonic(mnemonic);
    if (normalizedMnemonic.isEmpty) return false;
    return await NativeCrypto.validateMnemonic(normalizedMnemonic);
  }

  String normalizeMnemonic(String mnemonic) {
    return mnemonic
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .join(' ');
  }

  /// Create wallet from mnemonic
  /// Returns: {address, privateKey, publicKey}
  Future<Map<String, String>> createWalletFromMnemonic(
    String mnemonic, {
    String? walletName,
    int derivationIndex = 0,
  }) async {
    final normalizedMnemonic = normalizeMnemonic(mnemonic);
    if (!await validateMnemonic(normalizedMnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    // Generate seed from mnemonic (Rust FFI)
    final seed = await NativeCrypto.mnemonicToSeed(normalizedMnemonic);

    // Derive Ethereum wallet via HD key derivation (Rust FFI)
    // Path: m/44'/60'/0'/0/{derivationIndex}
    final privateKey = await NativeCrypto.deriveWalletFromSeed(
      seed,
      derivationIndex,
    );

    // Create credentials from private key
    final credentials = EthPrivateKey.fromHex(privateKey);

    // Get address
    final address = credentials.address.hexEip55;

    // Get public key from credentials
    final publicKey = HEX.encode(credentials.encodedPublicKey);

    // Store wallet data securely
    await _storage.saveWallet(
      address: address,
      privateKey: privateKey,
      mnemonic: normalizedMnemonic,
      walletName: walletName ?? 'Wallet ${derivationIndex + 1}',
      origin: WalletOrigin.derived,
      derivationIndex: derivationIndex,
    );

    return {
      'address': address,
      'privateKey': privateKey,
      'publicKey': publicKey,
      'derivationIndex': derivationIndex.toString(),
    };
  }

  /// Import wallet from private key
  Future<Map<String, String>> importWalletFromPrivateKey(
    String privateKey, {
    String? walletName,
  }) async {
    try {
      privateKey = privateKey.trim();

      // Remove 0x prefix if present
      if (privateKey.startsWith('0x')) {
        privateKey = privateKey.substring(2);
      }

      // Validate private key length (64 hex characters = 32 bytes)
      if (privateKey.length != 64) {
        throw Exception('Invalid private key length');
      }

      // Validate that the key contains only valid hex characters
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(privateKey)) {
        throw Exception('Invalid private key format: must be hexadecimal');
      }

      // Create credentials from private key
      final credentials = EthPrivateKey.fromHex(privateKey);

      // Get address
      final address = credentials.address.hexEip55;

      // Store wallet data securely (no mnemonic for imported private keys)
      await _storage.saveWallet(
        address: address,
        privateKey: privateKey,
        walletName: walletName ?? 'Imported Wallet',
        origin: WalletOrigin.imported,
      );

      return {'address': address, 'privateKey': privateKey};
    } catch (e) {
      throw Exception('Failed to import wallet: ${e.toString()}');
    }
  }

  /// Get current wallet address
  Future<String?> getCurrentWalletAddress() async {
    return await _storage.getWalletAddress();
  }

  /// Get wallet private key (use with caution!)
  /// Prefer signing helpers for transactional/auth flows.
  Future<String?> getPrivateKey([String? address]) async {
    if (address == null || address.isEmpty) {
      return await _storage.getPrivateKey();
    }
    return await _storage.getPrivateKeyForAddress(address);
  }

  /// Get wallet mnemonic (if available)
  Future<String?> getMnemonic() async {
    return await _storage.getMnemonic();
  }

  /// Check if wallet exists
  Future<bool> hasWallet() async {
    final address = await getCurrentWalletAddress();
    return address != null && address.isNotEmpty;
  }

  /// Delete wallet (logout)
  Future<void> deleteWallet() async {
    await _storage.deleteWallet();
  }

  /// Get wallet name
  Future<String?> getWalletName() async {
    return await _storage.getWalletName();
  }

  Future<List<WalletAccount>> getWalletAccounts() {
    return _storage.getWalletAccounts();
  }

  Future<WalletAccount?> getActiveWalletAccount() async {
    final address = await _storage.getWalletAddress();
    if (address == null || address.isEmpty) {
      return null;
    }
    final accounts = await _storage.getWalletAccounts();
    for (final account in accounts) {
      if (account.address.toLowerCase() == address.toLowerCase()) {
        return account;
      }
    }
    return null;
  }

  Future<void> setActiveWallet(String address) async {
    await _storage.setActiveWallet(address);
  }

  Future<void> removeWalletAccount(String address) async {
    // Perform storage removal first.
    // This will handle active wallet replacement internally in StorageService.
    await _storage.removeWalletAccount(address);

    // We don't need to manually setActiveWallet here anymore because
    // StorageService.removeWalletAccount handles the active wallet swap
    // if the removed account was the active one.
  }

  Future<Map<String, String>> createAdditionalWallet({
    String? walletName,
  }) async {
    final mnemonic = await _storage.getMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception(
        'Original seed phrase not available. Unable to derive new wallet.',
      );
    }
    final index = await _storage.getNextDerivationIndex();
    return await createWalletFromMnemonic(
      mnemonic,
      walletName: walletName ?? 'Wallet ${index + 1}',
      derivationIndex: index,
    );
  }

  /// Sign a message with the active wallet.
  Future<String> signMessage(String message) {
    return signMessageForAddress(null, message);
  }

  /// Sign a message with a specific wallet when available (Rust FFI).
  Future<String> signMessageForAddress(String? address, String message) async {
    final privateKeyHex = await getPrivateKey(address);
    if (privateKeyHex == null) {
      throw Exception('No wallet found');
    }

    final pk = privateKeyHex.startsWith('0x')
        ? privateKeyHex.substring(2)
        : privateKeyHex;

    // Use Rust secp256k1 for personal message signing
    final signature = await NativeCrypto.signPersonalMessage(
      privateKeyHex: pk,
      message: message,
    );

    // Remove 0x prefix if present (Rust returns 0x-prefixed)
    return signature.startsWith('0x') ? signature.substring(2) : signature;
  }

  /// Sign EIP-712 typed data with the active wallet.
  Future<String> signTypedData(String jsonData) {
    return signTypedDataForAddress(null, jsonData);
  }

  Future<String> signTypedDataForAddress(
    String? address,
    String jsonData,
  ) async {
    final privateKeyHex = await getPrivateKey(address);
    if (privateKeyHex == null) {
      throw Exception('No wallet found');
    }

    final pk = privateKeyHex.startsWith('0x')
        ? privateKeyHex.substring(2)
        : privateKeyHex;

    final signature = EthSigUtil.signTypedData(
      privateKey: pk,
      jsonData: jsonData,
      version: TypedDataVersion.V4,
    );

    return signature;
  }

  /// Get EthPrivateKey credentials for transactions
  Future<EthPrivateKey> getCredentials() async {
    final privateKeyHex = await getPrivateKey();
    if (privateKeyHex == null) {
      throw Exception('No wallet found');
    }

    return EthPrivateKey.fromHex(privateKeyHex);
  }

  Web3Client _clientForRpc(String rpcUrl) {
    return _web3Clients.putIfAbsent(
      rpcUrl,
      () => Web3Client(rpcUrl, _httpClientService.client),
    );
  }

  /// Send native coin (ETH/BNB/MATIC/etc.) to an address
  /// Returns the transaction hash if successful
  Future<String> sendNativeTransaction({
    required String toAddress,
    required BigInt amountInBaseUnits,
    required String rpcUrl,
    required int chainId,
  }) async {
    final credentials = await getCredentials();
    final client = _clientForRpc(rpcUrl);
    final recipient = EthereumAddress.fromHex(toAddress);
    final gasPrice = await client.getGasPrice();
    final estimatedGas = await client.estimateGas(
      sender: credentials.address,
      to: recipient,
      value: EtherAmount.inWei(amountInBaseUnits),
    );
    final bufferedGas = BigInt.from((estimatedGas.toInt() * 1.1).ceil());

    return client.sendTransaction(
      credentials,
      Transaction(
        to: recipient,
        value: EtherAmount.inWei(amountInBaseUnits),
        gasPrice: gasPrice,
        maxGas: bufferedGas.toInt(),
      ),
      chainId: chainId,
    );
  }

  Future<String> sendTokenTransaction({
    required String tokenAddress,
    required String toAddress,
    required BigInt amountInBaseUnits,
    required String rpcUrl,
    required int chainId,
  }) async {
    final credentials = await getCredentials();
    final client = _clientForRpc(rpcUrl);
    final tokenContractAddress = EthereumAddress.fromHex(tokenAddress);
    final recipient = EthereumAddress.fromHex(toAddress);
    final contract = DeployedContract(_erc20Abi, tokenContractAddress);
    final transferFunction = contract.function('transfer');
    final data = transferFunction.encodeCall([recipient, amountInBaseUnits]);
    final gasPrice = await client.getGasPrice();
    final estimatedGas = await client.estimateGas(
      sender: credentials.address,
      to: tokenContractAddress,
      data: data,
    );
    final bufferedGas = BigInt.from((estimatedGas.toInt() * 1.1).ceil());

    return client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: transferFunction,
        parameters: [recipient, amountInBaseUnits],
        gasPrice: gasPrice,
        maxGas: bufferedGas.toInt(),
      ),
      chainId: chainId,
      fetchChainIdFromNetworkId: false,
    );
  }

  Future<Map<String, dynamic>> estimateTransferFee({
    required String fromAddress,
    required String toAddress,
    required BigInt amountInBaseUnits,
    required String rpcUrl,
    String? tokenAddress,
    double nativePriceUsd = 0,
  }) async {
    final client = _clientForRpc(rpcUrl);
    final sender = EthereumAddress.fromHex(fromAddress);
    final recipient = EthereumAddress.fromHex(toAddress);
    final gasPrice = await client.getGasPrice();

    BigInt estimatedGas;
    if (tokenAddress == null || tokenAddress.isEmpty) {
      estimatedGas = await client.estimateGas(
        sender: sender,
        to: recipient,
        value: EtherAmount.inWei(amountInBaseUnits),
      );
    } else {
      final tokenContractAddress = EthereumAddress.fromHex(tokenAddress);
      final contract = DeployedContract(_erc20Abi, tokenContractAddress);
      final transferFunction = contract.function('transfer');
      final data = transferFunction.encodeCall([recipient, amountInBaseUnits]);
      estimatedGas = await client.estimateGas(
        sender: sender,
        to: tokenContractAddress,
        data: data,
      );
    }

    final bufferedGas = BigInt.from((estimatedGas.toInt() * 1.1).ceil());
    final totalFeeWei = gasPrice.getInWei * bufferedGas;
    final totalFeeNativeDouble = EtherAmount.inWei(
      totalFeeWei,
    ).getValueInUnit(EtherUnit.ether).toDouble();

    return {
      'gasGwei': gasPrice.getValueInUnit(EtherUnit.gwei),
      'gasLimitUnits': bufferedGas.toDouble(),
      'totalFeeEth': totalFeeNativeDouble,
      'totalFeeUsd': totalFeeNativeDouble * nativePriceUsd,
      'totalFeeWei': totalFeeWei,
    };
  }

  Future<TransactionReceipt?> getTransactionReceipt({
    required String txHash,
    required String rpcUrl,
  }) {
    final client = _clientForRpc(rpcUrl);
    return client.getTransactionReceipt(txHash);
  }

  BigInt parseAmountToBaseUnits(String amount, {int decimals = 18}) {
    return AmountUtils.parseDecimalToBaseUnits(amount, decimals);
  }
}
