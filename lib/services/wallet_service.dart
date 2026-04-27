import 'dart:convert';
import 'dart:typed_data';

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

  // ── Solana send ────────────────────────────────────────────────────────────

  /// Send SOL or an SPL token via the backend prepare-transfer → sign → broadcast pipeline.
  ///
  /// [amountLamports] is the amount in the token's smallest unit (lamports for
  /// SOL, or raw token units for SPL).  Pass [tokenMint] for SPL transfers.
  Future<String> sendSolanaTransaction({
    required String fromAddress,
    required String toAddress,
    required int amountLamports,
    String? tokenMint,
  }) async {
    final seed = await _getSeedBytes();
    final account = await getActiveWalletAccount();
    final derivationIndex = account?.derivationIndex ?? 0;
    final privateKeyHex = await NativeCrypto.deriveSolanaPrivateKeyFromSeed(
      seed,
      derivationIndex,
    );

    // 1. Ask the backend to prepare the transaction and return a recent blockhash.
    final prepareUri = AppEnvironment.blockchain(
      '/networks/solana:mainnet/prepare-transfer',
    );
    final prepareBody = jsonEncode({
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'amountLamports': amountLamports,
      if (tokenMint != null) 'tokenMint': tokenMint,
    });
    final prepareResp = await _httpClientService.client
        .post(
          prepareUri,
          headers: const {'Content-Type': 'application/json'},
          body: prepareBody,
        )
        .timeout(const Duration(seconds: 15));

    if (prepareResp.statusCode < 200 || prepareResp.statusCode >= 300) {
      throw Exception('Failed to prepare Solana transfer: ${prepareResp.body}');
    }
    final prepareData = jsonDecode(prepareResp.body) as Map<String, dynamic>;
    final recentBlockhash = prepareData['recentBlockhash'] as String?;
    if (recentBlockhash == null || recentBlockhash.isEmpty) {
      throw Exception('Backend did not return a recentBlockhash');
    }

    // 2. Build and sign the legacy Solana transaction message in Dart, then
    //    sign the raw message bytes with the ed25519 key via Rust FFI.
    final messageBytes = _buildSolanaTransferMessage(
      fromAddress: fromAddress,
      toAddress: toAddress,
      amountLamports: amountLamports,
      recentBlockhash: recentBlockhash,
    );
    // signSolanaMessage returns a base58-encoded 64-byte ed25519 signature.
    final signatureBase58 = await NativeCrypto.signSolanaMessage(
      privateKeyHex: privateKeyHex,
      message: messageBytes,
    );
    final signatureBytes = _base58Decode(signatureBase58);

    // 3. Serialise: [compact_array(1), signature_bytes, message_bytes] → base64.
    final txBytes = Uint8List(1 + signatureBytes.length + messageBytes.length);
    txBytes[0] = 1; // one signature
    txBytes.setRange(1, 1 + signatureBytes.length, signatureBytes);
    txBytes.setRange(1 + signatureBytes.length, txBytes.length, messageBytes);
    final signedBase64 = base64Encode(txBytes);

    // 4. Broadcast the signed transaction.
    final broadcastUri = AppEnvironment.blockchain(
      '/networks/solana:mainnet/broadcast',
    );
    final broadcastResp = await _httpClientService.client
        .post(
          broadcastUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'signedTransactionBase64': signedBase64}),
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

  /// Build a Solana legacy transaction message for a SOL transfer.
  /// Spec: https://docs.solana.com/developing/programming-model/transactions
  static Uint8List _buildSolanaTransferMessage({
    required String fromAddress,
    required String toAddress,
    required int amountLamports,
    required String recentBlockhash,
  }) {
    // System program public key (all zeros except last byte = 0)
    const systemProgramId = '11111111111111111111111111111111';

    final from = _base58Decode(fromAddress);
    final to = _base58Decode(toAddress);
    final system = _base58Decode(systemProgramId);
    final blockhash = _base58Decode(recentBlockhash);

    // Header: numRequiredSignatures=1, numReadonlySignedAccounts=0,
    //         numReadonlyUnsignedAccounts=1
    const header = [1, 0, 1];

    // Account keys: [from(signer+writable), to(writable), systemProgram(readonly)]
    final accountKeys = [from, to, system];

    // Instruction data for SystemProgram.transfer:
    //   instruction index (u32 LE) = 2
    //   lamports (u64 LE)
    final instructionData = Uint8List(12);
    final byteData = ByteData.view(instructionData.buffer);
    byteData.setUint32(0, 2, Endian.little);
    byteData.setUint64(4, amountLamports, Endian.little);

    // Build message
    final buf = BytesBuilder();
    buf.add(header);

    // Compact-array of account keys (3 keys)
    buf.addByte(accountKeys.length);
    for (final key in accountKeys) {
      buf.add(key);
    }

    // Recent blockhash (32 bytes)
    buf.add(blockhash);

    // Compact-array of instructions (1 instruction)
    buf.addByte(1);
    // program_id_index = 2 (systemProgram is account index 2)
    buf.addByte(2);
    // accounts involved: compact-array [0 (from), 1 (to)]
    buf.addByte(2);
    buf.addByte(0);
    buf.addByte(1);
    // data length + data
    buf.addByte(instructionData.length);
    buf.add(instructionData);

    return buf.toBytes();
  }

  /// Minimal base58 decoder (Bitcoin/Solana alphabet).
  static Uint8List _base58Decode(String input) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var result = BigInt.zero;
    var base = BigInt.from(58);
    for (final ch in input.runes) {
      final digit = alphabet.indexOf(String.fromCharCode(ch));
      if (digit < 0) throw FormatException('Invalid base58 character: $ch');
      result = result * base + BigInt.from(digit);
    }
    final bytes = <int>[];
    while (result > BigInt.zero) {
      bytes.insert(0, (result % BigInt.from(256)).toInt());
      result ~/= BigInt.from(256);
    }
    // Leading '1' chars → leading 0x00 bytes
    for (var i = 0; i < input.length && input[i] == '1'; i++) {
      bytes.insert(0, 0);
    }
    return Uint8List.fromList(bytes);
  }

  // ── Tron send ──────────────────────────────────────────────────────────────

  /// Send TRX or a TRC-20 token via the backend prepare-transfer → sign → broadcast pipeline.
  ///
  /// [amount] is in SUN for TRX, or the token's smallest unit for TRC-20.
  Future<String> sendTronTransaction({
    required String fromAddress,
    required String toAddress,
    required int amount,
    String? tokenContract,
  }) async {
    final seed = await _getSeedBytes();
    final account = await getActiveWalletAccount();
    final derivationIndex = account?.derivationIndex ?? 0;
    final privateKeyHex = await NativeCrypto.deriveTronPrivateKeyFromSeed(
      seed,
      derivationIndex,
    );

    // 1. Prepare the unsigned transaction via the backend.
    final prepareUri = AppEnvironment.blockchain(
      '/networks/tron:mainnet/prepare-transfer',
    );
    final prepareBody = jsonEncode({
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'amount': amount,
      if (tokenContract != null) 'tokenContract': tokenContract,
    });
    final prepareResp = await _httpClientService.client
        .post(
          prepareUri,
          headers: const {'Content-Type': 'application/json'},
          body: prepareBody,
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

    // 2. Sign the raw transaction hash using secp256k1 (Rust FFI).
    final rawDataHex = (unsignedTx['raw_data_hex'] ?? unsignedTx['rawDataHex'])
        ?.toString();
    if (rawDataHex == null || rawDataHex.isEmpty) {
      throw Exception('unsignedTransaction missing raw_data_hex');
    }
    // Tron signs the SHA-256 hash of raw_data_hex bytes.
    final signature = await NativeCrypto.signTronRawHash(
      privateKeyHex: privateKeyHex,
      rawHashHex: rawDataHex,
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
          body: jsonEncode({'signedTransaction': signedTx}),
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

  Future<Uint8List> _getSeedBytes() async {
    final mnemonic = await getMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception(
        'Seed phrase not available. Non-EVM transactions require a seed-phrase wallet.',
      );
    }
    return NativeCrypto.mnemonicToSeed(mnemonic);
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
