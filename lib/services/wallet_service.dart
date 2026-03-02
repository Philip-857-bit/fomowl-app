import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:eth_sig_util/eth_sig_util.dart';
import 'dart:typed_data';
import '../models/wallet_account.dart';
import 'storage_service.dart';

/// Wallet Service
/// Handles wallet creation, import, and key management
class WalletService {
  final StorageService _storage = StorageService();

  /// Generate a new 12-word mnemonic phrase
  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  /// Validate a mnemonic phrase
  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  /// Create wallet from mnemonic
  /// Returns: {address, privateKey, publicKey}
  Future<Map<String, String>> createWalletFromMnemonic(
    String mnemonic, {
    String? walletName,
    int derivationIndex = 0,
  }) async {
    if (!validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    // Generate seed from mnemonic
    final seed = bip39.mnemonicToSeed(mnemonic);

    // Derive Ethereum wallet (m/44'/60'/0'/0/0)
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath("m/44'/60'/0'/0/$derivationIndex");

    // Get private key
    final privateKey = HEX.encode(child.privateKey!);

    // Create credentials from private key
    final credentials = EthPrivateKey.fromHex(privateKey);

    // Get address
    final address = credentials.address.hexEip55;

    // Get public key
    final publicKey = HEX.encode(child.publicKey);

    // Store wallet data securely
    await _storage.saveWallet(
      address: address,
      privateKey: privateKey,
      mnemonic: mnemonic,
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
      // Remove 0x prefix if present
      if (privateKey.startsWith('0x')) {
        privateKey = privateKey.substring(2);
      }

      // Validate private key length (64 hex characters = 32 bytes)
      if (privateKey.length != 64) {
        throw Exception('Invalid private key length');
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

  /// Sign a message
  Future<String> signMessage(String message) async {
    final privateKeyHex = await getPrivateKey();
    if (privateKeyHex == null) {
      throw Exception('No wallet found');
    }

    final credentials = EthPrivateKey.fromHex(privateKeyHex);
    final signature = credentials.signPersonalMessageToUint8List(
      Uint8List.fromList(message.codeUnits),
    );

    return HEX.encode(signature);
  }

  /// Sign EIP-712 Typed Data
  Future<String> signTypedData(String jsonData) async {
    final privateKeyHex = await getPrivateKey();
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

  /// Send native coin (ETH/BNB/MATIC/etc.) to an address
  /// Returns the transaction hash if successful
  Future<String> sendNativeTransaction({
    required String toAddress,
    required double amount,
    required String rpcUrl,
    required int chainId,
  }) async {
    final credentials = await getCredentials();
    final client = Web3Client(rpcUrl, http.Client());

    try {
      final amountInWei = BigInt.from(amount * 1e18);

      final txHash = await client.sendTransaction(
        credentials,
        Transaction(
          to: EthereumAddress.fromHex(toAddress),
          value: EtherAmount.inWei(amountInWei),
          gasPrice: await client.getGasPrice(),
          maxGas: 21000,
        ),
        chainId: chainId,
      );

      return txHash;
    } finally {
      client.dispose();
    }
  }
}
