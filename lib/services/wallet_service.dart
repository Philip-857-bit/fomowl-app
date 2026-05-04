import 'dart:convert';

import 'package:crypto/crypto.dart' as pkg_crypto;
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'http_client_service.dart';
import '../config/app_environment.dart';
import '../models/chain.dart';
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

    // Derive family addresses from the same seed/account index.
    final privateKey = await NativeCrypto.deriveEvmPrivateKeyFromSeed(
      seed,
      derivationIndex,
    );
    final evmAddress = await NativeCrypto.deriveEvmAddressFromSeed(
      seed,
      derivationIndex,
    );
    final solanaAddress = await NativeCrypto.deriveSolanaAddressFromSeed(
      seed,
      derivationIndex,
    );
    final tronAddress = await NativeCrypto.deriveTronAddressFromSeed(
      seed,
      derivationIndex,
    );

    // Create credentials from private key
    final credentials = EthPrivateKey.fromHex(privateKey);

    // Get address and public key from web3dart for existing EVM call sites.
    final address = credentials.address.hexEip55;
    if (address.toLowerCase() != evmAddress.toLowerCase()) {
      throw Exception('Derived EVM address mismatch');
    }

    final publicKey = HEX.encode(credentials.encodedPublicKey);

    // Store wallet data securely
    await _storage.saveWallet(
      address: address,
      privateKey: privateKey,
      mnemonic: normalizedMnemonic,
      walletName: walletName ?? 'Wallet ${derivationIndex + 1}',
      origin: WalletOrigin.derived,
      derivationIndex: derivationIndex,
      addressesByFamily: {
        ChainFamily.evm: address,
        ChainFamily.solana: solanaAddress,
        ChainFamily.tron: tronAddress,
      },
    );

    return {
      'address': address,
      'evmAddress': address,
      'solanaAddress': solanaAddress,
      'tronAddress': tronAddress,
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

  /// Import wallet from a 32-byte Ed25519 Solana private key (64 hex chars).
  Future<Map<String, String>> importWalletFromSolanaKey(
    String privateKey, {
    String? walletName,
  }) async {
    try {
      privateKey = privateKey.trim();
      if (privateKey.startsWith('0x')) {
        privateKey = privateKey.substring(2);
      }
      if (privateKey.length != 64) {
        throw Exception(
          'Invalid Solana private key length (expected 32 bytes / 64 hex chars)',
        );
      }
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(privateKey)) {
        throw Exception(
          'Invalid Solana private key format: must be hexadecimal',
        );
      }

      final address = await NativeCrypto.deriveSolanaAddressFromPrivateKey(
        privateKey,
      );

      await _storage.saveWallet(
        address: address,
        privateKey: privateKey,
        walletName: walletName ?? 'Solana Wallet',
        origin: WalletOrigin.imported,
        addressesByFamily: {ChainFamily.solana: address},
      );
      await _storage.saveFamilyPrivateKey(
        family: ChainFamily.solana,
        address: address,
        privateKey: privateKey,
      );

      return {'address': address, 'privateKey': privateKey};
    } catch (e) {
      throw Exception('Failed to import Solana wallet: ${e.toString()}');
    }
  }

  /// Import wallet from a 32-byte secp256k1 Tron private key (64 hex chars).
  Future<Map<String, String>> importWalletFromTronKey(
    String privateKey, {
    String? walletName,
  }) async {
    try {
      privateKey = privateKey.trim();
      if (privateKey.startsWith('0x')) {
        privateKey = privateKey.substring(2);
      }
      if (privateKey.length != 64) {
        throw Exception(
          'Invalid Tron private key length (expected 32 bytes / 64 hex chars)',
        );
      }
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(privateKey)) {
        throw Exception('Invalid Tron private key format: must be hexadecimal');
      }

      final address = await NativeCrypto.deriveTronAddressFromPrivateKey(
        privateKey,
      );

      await _storage.saveWallet(
        address: address,
        privateKey: privateKey,
        walletName: walletName ?? 'Tron Wallet',
        origin: WalletOrigin.imported,
        addressesByFamily: {ChainFamily.tron: address},
      );
      await _storage.saveFamilyPrivateKey(
        family: ChainFamily.tron,
        address: address,
        privateKey: privateKey,
      );

      return {'address': address, 'privateKey': privateKey};
    } catch (e) {
      throw Exception('Failed to import Tron wallet: ${e.toString()}');
    }
  }

  /// Get current wallet address
  Future<String?> getCurrentWalletAddress() async {
    return await _storage.getWalletAddress();
  }

  /// Get the active wallet address for a specific network family.
  ///
  /// Existing callers should keep using [getCurrentWalletAddress] for EVM
  /// compatibility. Non-EVM families return null until the account has a
  /// derived/imported address for that family.
  Future<String?> getWalletAddressForFamily(ChainFamily family) async {
    final account = await getActiveWalletAccount();
    return account?.getWalletAddressForFamily(family);
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

    try {
      return await NativeCrypto.signTypedData(
        privateKeyHex: pk,
        jsonData: jsonData,
      );
    } catch (error) {
      debugPrint(
        '[WalletService] Falling back to Dart typed-data signer: $error',
      );
      return EthSigUtil.signTypedData(
        privateKey: pk,
        jsonData: jsonData,
        version: TypedDataVersion.V4,
      );
    }
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

  Future<String> sendRawTransactionRequest({
    required String rpcUrl,
    required int chainId,
    String? toAddress,
    BigInt? valueInWei,
    String? dataHex,
    BigInt? gasPriceWei,
    int? gasLimit,
    int? nonce,
  }) async {
    final credentials = await getCredentials();
    final client = _clientForRpc(rpcUrl);
    final data = _decodeHexBytes(dataHex);

    return client.sendTransaction(
      credentials,
      Transaction(
        to: (toAddress == null || toAddress.isEmpty)
            ? null
            : EthereumAddress.fromHex(toAddress),
        value: valueInWei == null ? null : EtherAmount.inWei(valueInWei),
        data: data,
        gasPrice: gasPriceWei == null ? null : EtherAmount.inWei(gasPriceWei),
        maxGas: gasLimit,
        nonce: nonce,
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

  // ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Solana send ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬

  /// Send SOL or an SPL token via the backend prepare-transfer ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ sign ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ broadcast pipeline.
  ///
  /// [amountLamports] is the amount in the token's smallest unit (lamports for
  /// SOL, or raw token units for SPL).  Pass [tokenMint] for SPL transfers.
  Future<String> sendSolanaTransaction({
    required String fromAddress,
    required String toAddress,
    required BigInt amountLamports,
    String? tokenMint,
  }) async {
    if (amountLamports <= BigInt.zero) {
      throw Exception('amountLamports must be greater than zero');
    }
    // Solana amounts are u64 on-chain; guard against overflow before JSON serialisation.
    final maxU64 = BigInt.parse('18446744073709551615');
    if (amountLamports > maxU64) {
      throw Exception('amountLamports exceeds maximum u64 value');
    }
    final privateKeyHex = await _getSolanaPrivateKey(fromAddress);

    // 1. Ask the backend to build the serialized unsigned message.
    final prepareUri = AppEnvironment.blockchain(
      '/networks/solana:mainnet/prepare-transfer',
    );
    final prepareResp = await _httpClientService.client
        .post(
          prepareUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fromAddress': fromAddress,
            'toAddress': toAddress,
            'amountLamports': amountLamports.toString(),
            'tokenMint': tokenMint,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (prepareResp.statusCode < 200 || prepareResp.statusCode >= 300) {
      throw Exception('Failed to prepare Solana transfer: ${prepareResp.body}');
    }
    final prepareData = jsonDecode(prepareResp.body) as Map<String, dynamic>;

    // The backend returns the fully serialized unsigned message as base64.
    // Sign those exact bytes ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â do NOT rebuild the message locally.
    final unsignedMessageB64 = prepareData['unsignedMessage'] as String?;
    if (unsignedMessageB64 == null || unsignedMessageB64.isEmpty) {
      throw Exception('Backend did not return unsignedMessage');
    }
    final messageBytes = base64Decode(unsignedMessageB64);

    // 2. Sign the message bytes with the Ed25519 key via Rust FFI.
    //    signSolanaMessage returns a base58-encoded 64-byte signature.
    final signatureBase58 = await NativeCrypto.signSolanaMessage(
      privateKeyHex: privateKeyHex,
      message: messageBytes,
    );
    final sigBytes = decodeBase58Signature(signatureBase58);

    // 3. Serialise: [1, <64-byte sig>, <message bytes>] ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ base64.
    final txBytes = Uint8List(1 + sigBytes.length + messageBytes.length);
    txBytes[0] = 1; // one signature
    txBytes.setRange(1, 1 + sigBytes.length, sigBytes);
    txBytes.setRange(1 + sigBytes.length, txBytes.length, messageBytes);
    final signedBase64 = base64Encode(txBytes);

    // 4. Broadcast.
    final broadcastUri = AppEnvironment.blockchain(
      '/networks/solana:mainnet/broadcast',
    );
    final broadcastResp = await _httpClientService.client
        .post(
          broadcastUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'signedTransaction': signedBase64}),
        )
        .timeout(const Duration(seconds: 15));

    if (broadcastResp.statusCode < 200 || broadcastResp.statusCode >= 300) {
      throw Exception(
        'Failed to broadcast Solana transaction: ${broadcastResp.body}',
      );
    }
    final broadcastData =
        jsonDecode(broadcastResp.body) as Map<String, dynamic>;
    final txHash = broadcastData['transactionHash']?.toString();
    if (txHash == null || txHash.isEmpty) {
      throw Exception('Broadcast succeeded but no transaction hash returned');
    }
    return txHash;
  }

  // ── Solana DApp signing helpers ───────────────────────────────────────────

  /// Sign [messageBytes] with the Ed25519 key for the Solana [address].
  /// Returns the base58-encoded 64-byte signature.
  Future<String> signSolanaMessageRaw(
    String address,
    Uint8List messageBytes,
  ) async {
    final privateKeyHex = await _getSolanaPrivateKey(address);
    return NativeCrypto.signSolanaMessage(
      privateKeyHex: privateKeyHex,
      message: messageBytes,
    );
  }

  /// Sign [messageBytes] and return the fully-serialised signed Solana
  /// transaction as a base64 string: [1, <64-byte sig>, <message bytes>].
  Future<String> signSolanaTransactionRaw(
    String address,
    Uint8List messageBytes,
  ) async {
    final privateKeyHex = await _getSolanaPrivateKey(address);
    final signatureBase58 = await NativeCrypto.signSolanaMessage(
      privateKeyHex: privateKeyHex,
      message: messageBytes,
    );
    final sigBytes = decodeBase58Signature(signatureBase58);
    final txBytes = Uint8List(1 + sigBytes.length + messageBytes.length);
    txBytes[0] = 1;
    txBytes.setRange(1, 1 + sigBytes.length, sigBytes);
    txBytes.setRange(1 + sigBytes.length, txBytes.length, messageBytes);
    return base64Encode(txBytes);
  }

  /// Sign and broadcast a pre-built Solana transaction message.
  /// [messageBytes] must be the raw serialised unsigned transaction message.
  /// Returns the transaction hash on success.
  Future<String> signAndBroadcastSolanaTransactionRaw(
    String address,
    Uint8List messageBytes,
  ) async {
    final signedBase64 = await signSolanaTransactionRaw(address, messageBytes);
    final broadcastUri = AppEnvironment.blockchain(
      '/networks/solana:mainnet/broadcast',
    );
    final broadcastResp = await _httpClientService.client
        .post(
          broadcastUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'signedTransaction': signedBase64}),
        )
        .timeout(const Duration(seconds: 30));
    if (broadcastResp.statusCode < 200 || broadcastResp.statusCode >= 300) {
      throw Exception(
        'Failed to broadcast Solana transaction: ${broadcastResp.body}',
      );
    }
    final broadcastData =
        jsonDecode(broadcastResp.body) as Map<String, dynamic>;
    final txHash = broadcastData['transactionHash']?.toString();
    if (txHash == null || txHash.isEmpty) {
      throw Exception('Broadcast succeeded but no transaction hash returned');
    }
    return txHash;
  }

  // ── Tron DApp signing helpers ─────────────────────────────────────────────

  /// Sign a Tron transaction JSON object with the key for [address].
  /// [unsignedTx] must contain a `raw_data_hex` field.
  /// Returns the transaction map with a `signature` list appended.
  Future<Map<String, dynamic>> signTronTransactionRaw(
    String address,
    Map<String, dynamic> unsignedTx,
  ) async {
    final privateKeyHex = await _getTronPrivateKey(address);
    final rawDataHex = (unsignedTx['raw_data_hex'] ?? unsignedTx['rawDataHex'])
        ?.toString();
    if (rawDataHex == null || rawDataHex.isEmpty) {
      throw Exception('signTronTransactionRaw: missing raw_data_hex');
    }
    final rawBytes = HEX.decode(rawDataHex);
    final digestBytes = _sha256(Uint8List.fromList(rawBytes));
    final digestHex = HEX.encode(digestBytes);
    final signature = await NativeCrypto.signTronRawHash(
      privateKeyHex: privateKeyHex,
      rawHashHex: digestHex,
    );
    final signatureHex = signature.startsWith('0x')
        ? signature.substring(2)
        : signature;
    return {
      ...unsignedTx,
      'signature': [signatureHex],
    };
  }

  /// Sign a raw Tron message hash [messageHex] with the key for [address].
  /// Returns a 0x-prefixed hex signature.
  Future<String> signTronMessageRaw(String address, String messageHex) async {
    final privateKeyHex = await _getTronPrivateKey(address);
    final normalized = messageHex.startsWith('0x')
        ? messageHex.substring(2)
        : messageHex;
    final signature = await NativeCrypto.signTronRawHash(
      privateKeyHex: privateKeyHex,
      rawHashHex: normalized,
    );
    return signature.startsWith('0x') ? signature : '0x$signature';
  }

  /// Decode a base58-encoded Ed25519 signature (64 bytes) to raw bytes.
  /// Uses an O(n) lookup-table approach instead of BigInt arithmetic.
  static Uint8List decodeBase58Signature(String input) {
    // Lookup table: ASCII code ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ base58 digit value, -1 for invalid chars.
    const int invalidDigit = -1;
    const List<int> base58Table = [
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 0-7
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 8-15
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 16-23
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 24-31
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 32-39
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 40-47
      invalidDigit, 0, 1, 2, 3, 4, 5, 6, // 48-55  '1'-'7'
      7,
      8,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 56-63  '8','9'
      invalidDigit, 9, 10, 11, 12, 13, 14, 15, // 64-71  'A'-'G'
      16, 17, 18, 19, 20, 21, invalidDigit, 22, // 72-79  'H'-'N' (no 'I')
      23, 24, 25, 26, 27, 28, 29, 30, // 80-87  'P'-'W' (no 'O')
      31,
      32,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 88-95  'X','Y','Z'
      invalidDigit, 33, 34, 35, 36, 37, 38, 39, // 96-103 'a'-'g'
      40, 41, 42, 43, invalidDigit, 44, 45, 46, // 104-111 'h'-'o' (no 'l')
      47, 48, 49, 50, 51, 52, 53, 54, // 112-119 'p'-'w'
      55,
      56,
      57,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 120-127 'x','y','z'
    ];

    // Count leading '1' chars (each maps to a leading 0x00 byte).
    int leadingZeros = 0;
    for (final ch in input.codeUnits) {
      if (ch == 49) {
        // '1'
        leadingZeros++;
      } else {
        break;
      }
    }

    // Decode into a byte array using base-58 long division.
    // Output size upper bound: ceil(inputLen * log(58) / log(256)) ÃƒÂ¢Ã¢â‚¬Â°Ã‹â€  inputLen * 0.733
    final output = List<int>.filled(input.length, 0);
    int outputLen = 0;

    for (final ch in input.codeUnits) {
      if (ch >= base58Table.length) {
        throw FormatException('Invalid base58 character: $ch');
      }
      int carry = base58Table[ch];
      if (carry == invalidDigit) {
        throw FormatException('Invalid base58 character: $ch');
      }
      for (int i = 0; i < outputLen; i++) {
        carry += output[i] * 58;
        output[i] = carry & 0xff;
        carry >>= 8;
      }
      while (carry > 0) {
        output[outputLen++] = carry & 0xff;
        carry >>= 8;
      }
    }

    // output is little-endian; reverse to big-endian and prepend leading zeros.
    final result = Uint8List(leadingZeros + outputLen);
    for (int i = 0; i < outputLen; i++) {
      result[leadingZeros + i] = output[outputLen - 1 - i];
    }

    if (result.length != 64) {
      throw FormatException(
        'Expected 64-byte Ed25519 signature, got ${result.length} bytes',
      );
    }
    return result;
  }

  // ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Tron send ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬

  /// Send TRX or a TRC-20 token via the backend prepare-transfer ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ sign ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ broadcast pipeline.
  ///
  /// [amount] is in SUN for TRX, or the token's smallest unit for TRC-20.
  Future<String> sendTronTransaction({
    required String fromAddress,
    required String toAddress,
    required BigInt amount,
    String? tokenContract,
  }) async {
    if (amount <= BigInt.zero) {
      throw Exception('amount must be greater than zero');
    }
    final maxU64 = BigInt.parse('18446744073709551615');
    if (amount > maxU64) {
      throw Exception('amount exceeds maximum u64 value');
    }
    final privateKeyHex = await _getTronPrivateKey(fromAddress);

    // 1. Prepare the unsigned transaction via the backend.
    final prepareUri = AppEnvironment.blockchain(
      '/networks/tron:mainnet/prepare-transfer',
    );
    final prepareResp = await _httpClientService.client
        .post(
          prepareUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fromAddress': fromAddress,
            'toAddress': toAddress,
            'amount': amount.toString(),
            'tokenContract': tokenContract,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (prepareResp.statusCode < 200 || prepareResp.statusCode >= 300) {
      throw Exception('Failed to prepare Tron transfer: ${prepareResp.body}');
    }
    final prepareData = jsonDecode(prepareResp.body) as Map<String, dynamic>;
    final unsignedTx = prepareData['unsignedTransaction'];
    if (unsignedTx == null) {
      throw Exception('Backend did not return unsignedTransaction');
    }

    // 2. Tron signs SHA-256(raw_data_hex bytes), not the raw bytes directly.
    //    raw_data_hex is the hex-encoded serialized transaction body.
    final rawDataHex = (unsignedTx['raw_data_hex'] ?? unsignedTx['rawDataHex'])
        ?.toString();
    if (rawDataHex == null || rawDataHex.isEmpty) {
      throw Exception('unsignedTransaction missing raw_data_hex');
    }
    final rawBytes = HEX.decode(rawDataHex);
    // SHA-256 hash the raw bytes ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â this 32-byte digest is what gets signed.
    final digestBytes = _sha256(Uint8List.fromList(rawBytes));
    final digestHex = HEX.encode(digestBytes);

    final signature = await NativeCrypto.signTronRawHash(
      privateKeyHex: privateKeyHex,
      rawHashHex: digestHex,
    );
    final signatureHex = signature.startsWith('0x')
        ? signature.substring(2)
        : signature;

    // 3. Attach signature and broadcast.
    final signedTx = Map<String, dynamic>.from(unsignedTx as Map);
    signedTx['signature'] = [signatureHex];

    final broadcastUri = AppEnvironment.blockchain(
      '/networks/tron:mainnet/broadcast',
    );
    final broadcastResp = await _httpClientService.client
        .post(
          broadcastUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'signedTransactionJson': signedTx}),
        )
        .timeout(const Duration(seconds: 15));

    if (broadcastResp.statusCode < 200 || broadcastResp.statusCode >= 300) {
      throw Exception(
        'Failed to broadcast Tron transaction: ${broadcastResp.body}',
      );
    }
    final broadcastData =
        jsonDecode(broadcastResp.body) as Map<String, dynamic>;
    final txHash = broadcastData['transactionHash']?.toString();
    if (txHash == null || txHash.isEmpty) {
      throw Exception('Broadcast succeeded but no transaction hash returned');
    }
    return txHash;
  }

  /// SHA-256 hash of [input] bytes.
  static Uint8List _sha256(Uint8List input) {
    return Uint8List.fromList(pkg_crypto.sha256.convert(input).bytes);
  }

  Future<Uint8List> _getSeedBytes() async {
    final mnemonic = await getMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception(
        'Seed phrase not available. Non-EVM transactions require a seed-phrase wallet.',
      );
    }
    return NativeCrypto.mnemonicToSeed(mnemonic);
  }

  /// Returns the Ed25519 private key hex for the given Solana [address].
  /// Checks for a directly-imported key first; falls back to mnemonic derivation.
  Future<String> _getSolanaPrivateKey(String address) async {
    final imported = await _storage.getFamilyPrivateKey(
      ChainFamily.solana,
      address,
    );
    if (imported != null && imported.isNotEmpty) return imported;
    final seed = await _getSeedBytes();
    final account = await getActiveWalletAccount();
    final derivationIndex = account?.derivationIndex ?? 0;
    return NativeCrypto.deriveSolanaPrivateKeyFromSeed(seed, derivationIndex);
  }

  /// Returns the secp256k1 private key hex for the given Tron [address].
  /// Checks for a directly-imported key first; falls back to mnemonic derivation.
  Future<String> _getTronPrivateKey(String address) async {
    final imported = await _storage.getFamilyPrivateKey(
      ChainFamily.tron,
      address,
    );
    if (imported != null && imported.isNotEmpty) return imported;
    final seed = await _getSeedBytes();
    final account = await getActiveWalletAccount();
    final derivationIndex = account?.derivationIndex ?? 0;
    return NativeCrypto.deriveTronPrivateKeyFromSeed(seed, derivationIndex);
  }

  Uint8List? _decodeHexBytes(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == '0x') {
      return null;
    }
    final normalized = trimmed.startsWith('0x')
        ? trimmed.substring(2)
        : trimmed;
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length.isOdd) {
      throw const FormatException(
        'Invalid transaction data hex: expected an even number of characters.',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) {
      throw const FormatException(
        'Invalid transaction data hex: contains non-hex characters.',
      );
    }
    return Uint8List.fromList(HEX.decode(normalized));
  }
}
