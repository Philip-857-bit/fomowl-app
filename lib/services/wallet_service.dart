import 'dart:convert';

import 'package:crypto/crypto.dart' as pkg_crypto;
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:hex/hex.dart';
import 'package:eth_sig_util/eth_sig_util.dart';

import 'http_client_service.dart';

import 'package:hex/hex.dart' as pkg_hex;

import '../config/app_environment.dart';
import '../models/chain.dart';
import '../models/wallet_account.dart';
import 'storage_service.dart';
import '../utils/amount_utils.dart';
import '../utils/app_error_utils.dart';
import 'native_crypto.dart';

typedef SeedAccountActivityChecker = Future<bool> Function({
  required String evmAddress,
  required String solanaAddress,
  required String tronAddress,
  required int derivationIndex,
});

/// Wallet Service
/// Handles wallet creation, import, and key management
class WalletService {
  WalletService({
    StorageService? storageService,
    SeedAccountActivityChecker? seedAccountActivityChecker,
  }) : _storage = storageService ?? StorageService(),
       _seedAccountActivityChecker = seedAccountActivityChecker;

  final StorageService _storage;
  final SeedAccountActivityChecker? _seedAccountActivityChecker;
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
  static final ContractAbi _erc721Abi = ContractAbi.fromJson('''[
      {
        "constant": false,
        "inputs": [
          {"name": "from", "type": "address"},
          {"name": "to", "type": "address"},
          {"name": "tokenId", "type": "uint256"}
        ],
        "name": "safeTransferFrom",
        "outputs": [],
        "type": "function"
      }
    ]''', 'ERC721');
  static final ContractAbi _erc1155Abi = ContractAbi.fromJson('''[
      {
        "constant": false,
        "inputs": [
          {"name": "from", "type": "address"},
          {"name": "to", "type": "address"},
          {"name": "id", "type": "uint256"},
          {"name": "amount", "type": "uint256"},
          {"name": "data", "type": "bytes"}
        ],
        "name": "safeTransferFrom",
        "outputs": [],
        "type": "function"
      }
    ]''', 'ERC1155');

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
    // Strip invisible/non-printable characters (zero-width spaces, BOM, smart
    // quotes, non-breaking spaces, punctuation, numbering, etc.) that copy-paste
    // from phones/browsers can silently inject, then normalize to English
    // BIP-39 words separated by single spaces.
    final cleaned = mnemonic
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), ' ')
        .replaceAll(
          RegExp(
            r'[\u00A0\u1680\u2000-\u200F\u2028\u2029\u202F\u205F\u3000\uFEFF]',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'[\u2018\u2019\u201A\u201B\u201C\u201D\u201E\u201F\u2032\u2033]',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^A-Za-z]+'), ' ');
    return cleaned
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
    String? seedGroupId,
  }) async {
    final normalizedMnemonic = normalizeMnemonic(mnemonic);
    if (!await validateMnemonic(normalizedMnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    final seed = await NativeCrypto.mnemonicToSeed(normalizedMnemonic);
    final material = await _deriveWalletMaterialFromSeed(seed, derivationIndex);
    final resolvedSeedGroupId =
        seedGroupId ?? _seedGroupIdFromMnemonic(normalizedMnemonic);

    await _saveDerivedWalletMaterial(
      material,
      mnemonic: normalizedMnemonic,
      walletName: walletName ?? 'Wallet ${derivationIndex + 1}',
      seedGroupId: resolvedSeedGroupId,
    );

    return material.toResult();
  }

  Future<List<Map<String, String>>> importWalletsFromMnemonic(
    String mnemonic, {
    String? walletName,
  }) async {
    final normalizedMnemonic = normalizeMnemonic(mnemonic);
    if (!await validateMnemonic(normalizedMnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    final seed = await NativeCrypto.mnemonicToSeed(normalizedMnemonic);
    final seedGroupId = _seedGroupIdFromMnemonic(normalizedMnemonic);
    final imported = <Map<String, String>>[];
    var consecutiveUnused = 0;

    for (var index = 0; index < 20; index++) {
      final material = await _deriveWalletMaterialFromSeed(seed, index);
      var shouldSave = index == 0;

      if (index > 0) {
        try {
          shouldSave = await _hasSeedAccountActivity(
            evmAddress: material.evmAddress,
            solanaAddress: material.solanaAddress,
            tronAddress: material.tronAddress,
            derivationIndex: index,
          );
        } catch (error) {
          debugPrint(
            '[WalletService] Seed account discovery stopped at index $index: $error',
          );
          break;
        }

        if (!shouldSave) {
          consecutiveUnused++;
          if (consecutiveUnused >= 5) break;
          continue;
        }
        consecutiveUnused = 0;
      }

      await _saveDerivedWalletMaterial(
        material,
        mnemonic: normalizedMnemonic,
        walletName: index == 0
            ? (walletName?.trim().isNotEmpty == true
                  ? walletName!.trim()
                  : 'Wallet 1')
            : 'Wallet ${index + 1}',
        seedGroupId: seedGroupId,
      );
      imported.add(material.toResult());
    }

    return imported;
  }

  Future<_DerivedWalletMaterial> _deriveWalletMaterialFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) async {
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

    return _DerivedWalletMaterial(
      derivationIndex: derivationIndex,
      privateKey: privateKey,
      evmAddress: address,
      solanaAddress: solanaAddress,
      tronAddress: tronAddress,
      publicKey: publicKey,
    );
  }

  Future<void> _saveDerivedWalletMaterial(
    _DerivedWalletMaterial material, {
    required String mnemonic,
    required String walletName,
    required String seedGroupId,
  }) async {
    await _storage.saveWallet(
      address: material.evmAddress,
      privateKey: material.privateKey,
      mnemonic: mnemonic,
      walletName: walletName,
      origin: WalletOrigin.derived,
      derivationIndex: material.derivationIndex,
      seedGroupId: seedGroupId,
      addressesByFamily: {
        ChainFamily.evm: material.evmAddress,
        ChainFamily.solana: material.solanaAddress,
        ChainFamily.tron: material.tronAddress,
      },
    );
  }

  String _seedGroupIdFromMnemonic(String normalizedMnemonic) {
    final digest = pkg_crypto.sha256.convert(utf8.encode(normalizedMnemonic));
    return 'seed_${digest.toString().substring(0, 16)}';
  }

  Future<bool> _hasSeedAccountActivity({
    required String evmAddress,
    required String solanaAddress,
    required String tronAddress,
    required int derivationIndex,
  }) async {
    final checker = _seedAccountActivityChecker;
    if (checker != null) {
      return checker(
        evmAddress: evmAddress,
        solanaAddress: solanaAddress,
        tronAddress: tronAddress,
        derivationIndex: derivationIndex,
      );
    }

    final response = await _httpClientService
        .sendWithRetry(
          () => _httpClientService.client.get(
            AppEnvironment.blockchain('/portfolio/${evmAddress.toLowerCase()}'),
          ),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return false;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return false;
    final sections = decoded['sections'];
    if (sections is! List) return false;
    for (final section in sections) {
      if (section is! Map) continue;
      final tokens = section['tokens'];
      if (tokens is! List) continue;
      for (final token in tokens) {
        if (token is! Map) continue;
        final balance = _asDouble(token['balance']);
        final valueUsd = _asDouble(token['valueUsd']);
        if (balance > 0 || valueUsd > 0) return true;
      }
    }
    return false;
  }

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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

      await _ensureFamilyAddressNotManaged(ChainFamily.evm, address);

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

  /// Import wallet from a Solana private key.
  /// Accepts multiple formats:
  ///   - 64 hex chars: 32-byte raw private key
  ///   - 128 hex chars: 64-byte keypair export
  ///   - JSON array: `[b0,b1,...,b63]` or `[b0,...,b31]`
  ///   - Base58 string: 32-byte seed or 64-byte keypair
  Future<Map<String, String>> importWalletFromSolanaKey(
    String privateKey, {
    String? walletName,
  }) async {
    try {
      privateKey = privateKey.trim();
      final keyMaterial = await NativeCrypto.normalizeSolanaPrivateKey(
        privateKey,
      );
      final hexKey = pkg_hex.HEX.encode(keyMaterial.privateKeyBytes);
      final address = keyMaterial.address;

      await _ensureFamilyAddressNotManaged(ChainFamily.solana, address);

      await _storage.saveWallet(
        address: address,
        privateKey: hexKey,
        walletName: walletName ?? 'Solana Wallet',
        origin: WalletOrigin.imported,
        addressesByFamily: {ChainFamily.solana: address},
      );
      await _storage.saveFamilyPrivateKey(
        family: ChainFamily.solana,
        address: address,
        privateKey: hexKey,
      );

      return {'address': address, 'privateKey': hexKey};
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

      await _ensureFamilyAddressNotManaged(ChainFamily.tron, address);

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

  Future<String?> getActiveAddressForFamily(ChainFamily family) {
    return getWalletAddressForFamily(family);
  }

  /// Get wallet private key (use with caution!)
  /// Prefer signing helpers for transactional/auth flows.
  Future<String?> getPrivateKey([String? address]) async {
    if (address == null || address.isEmpty) {
      return await _storage.getPrivateKey();
    }
    return await _storage.getPrivateKeyForAddress(address);
  }

  /// Exports the private key that belongs to [family] for [account].
  ///
  /// Seed-backed accounts use different derivation paths for EVM, Solana, and
  /// Tron. Solana is returned as the standard base58-encoded 64-byte keypair;
  /// EVM and Tron are returned as 32-byte hexadecimal keys.
  Future<String> exportPrivateKeyForFamily(
    WalletAccount account,
    ChainFamily family,
  ) async {
    final familyAddress = account.getWalletAddressForFamily(family)?.trim();
    if (familyAddress == null || familyAddress.isEmpty) {
      throw Exception('This account does not support ${family.wireValue}.');
    }

    switch (family) {
      case ChainFamily.evm:
        final privateKey = await _storage.getPrivateKeyForAddress(
          account.address,
        );
        if (privateKey == null || privateKey.isEmpty) {
          throw Exception('EVM private key is unavailable for this account.');
        }
        final derivedAddress =
            await NativeCrypto.deriveEvmAddressFromPrivateKey(privateKey);
        if (derivedAddress.toLowerCase() != familyAddress.toLowerCase()) {
          throw Exception('Stored EVM key does not match this account.');
        }
        return privateKey.startsWith('0x')
            ? privateKey.substring(2)
            : privateKey;

      case ChainFamily.solana:
        final privateKeyBytes = await _solanaPrivateKeyForAccount(
          account,
          familyAddress,
        );
        final publicKeyBytes = decodeBase58Bytes(familyAddress);
        if (publicKeyBytes.length != 32) {
          throw Exception('Stored Solana address is invalid.');
        }
        final derivedAddress =
            await NativeCrypto.deriveSolanaAddressFromPrivateKey(
              privateKeyBytes,
            );
        if (derivedAddress != familyAddress) {
          throw Exception('Stored Solana key does not match this account.');
        }
        return encodeBase58Bytes(
          Uint8List.fromList([...privateKeyBytes, ...publicKeyBytes]),
        );

      case ChainFamily.tron:
        final privateKey = await _tronPrivateKeyForAccount(
          account,
          familyAddress,
        );
        final derivedAddress =
            await NativeCrypto.deriveTronAddressFromPrivateKey(privateKey);
        if (derivedAddress != familyAddress) {
          throw Exception('Stored Tron key does not match this account.');
        }
        return privateKey.startsWith('0x')
            ? privateKey.substring(2)
            : privateKey;
    }
  }

  Future<void> _ensureFamilyAddressNotManaged(
    ChainFamily family,
    String address,
  ) async {
    final accounts = await getWalletAccounts();
    final duplicate = accounts.any((account) {
      final existing = account.getWalletAddressForFamily(family)?.trim();
      if (existing == null || existing.isEmpty) return false;
      return family == ChainFamily.evm
          ? existing.toLowerCase() == address.toLowerCase()
          : existing == address;
    });
    if (duplicate) {
      throw Exception(
        'This ${family.wireValue.toUpperCase()} wallet is already in Owllet. Switch to the existing account instead.',
      );
    }
  }

  Future<Uint8List> _solanaPrivateKeyForAccount(
    WalletAccount account,
    String familyAddress,
  ) async {
    final imported = await _storage.getFamilyPrivateKey(
      ChainFamily.solana,
      familyAddress,
    );
    if (imported != null && imported.isNotEmpty) {
      return Uint8List.fromList(pkg_hex.HEX.decode(imported));
    }
    final mnemonic = await getMnemonic(account.address);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception('Solana private key is unavailable for this account.');
    }
    final seed = await NativeCrypto.mnemonicToSeed(mnemonic);
    return NativeCrypto.deriveSolanaPrivateKeyFromSeed(
      seed,
      account.derivationIndex ?? 0,
    );
  }

  Future<String> _tronPrivateKeyForAccount(
    WalletAccount account,
    String familyAddress,
  ) async {
    final imported = await _storage.getFamilyPrivateKey(
      ChainFamily.tron,
      familyAddress,
    );
    if (imported != null && imported.isNotEmpty) return imported;
    final mnemonic = await getMnemonic(account.address);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception('Tron private key is unavailable for this account.');
    }
    final seed = await NativeCrypto.mnemonicToSeed(mnemonic);
    return NativeCrypto.deriveTronPrivateKeyFromSeed(
      seed,
      account.derivationIndex ?? 0,
    );
  }

  /// Get wallet mnemonic (if available)
  Future<String?> getMnemonic([String? address]) async {
    return await _storage.getMnemonic(address);
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

  /// Fully reset local wallet state, including passcode, wallet lists, cached
  /// token visibility, backend sessions, and all stored key material.
  Future<void> resetAppData() async {
    await _storage.clearAll();
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
    String? seedGroupId,
  }) async {
    final targetSeedGroupId = await _resolveSeedGroupId(seedGroupId);
    if (targetSeedGroupId == null) {
      throw Exception(
        'Seed phrase not available. Import or create a seed phrase wallet first.',
      );
    }

    final mnemonic = await _mnemonicForSeedGroup(targetSeedGroupId);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception(
        'Original seed phrase not available. Unable to derive new wallet.',
      );
    }
    final index = await _storage.getNextDerivationIndex(targetSeedGroupId);
    return await createWalletFromMnemonic(
      mnemonic,
      walletName: walletName ?? 'Wallet ${index + 1}',
      derivationIndex: index,
      seedGroupId: targetSeedGroupId,
    );
  }

  Future<String?> _resolveSeedGroupId(String? seedGroupId) async {
    final provided = seedGroupId?.trim();
    if (provided != null && provided.isNotEmpty) return provided;

    final active = await getActiveWalletAccount();
    final activeGroup = active?.seedGroupId?.trim();
    if (activeGroup != null && activeGroup.isNotEmpty) return activeGroup;

    final accounts = await getWalletAccounts();
    for (final account in accounts) {
      final group = account.seedGroupId?.trim();
      if (account.origin == WalletOrigin.derived &&
          group != null &&
          group.isNotEmpty) {
        return group;
      }
    }
    return null;
  }

  Future<String?> _mnemonicForSeedGroup(String seedGroupId) async {
    final grouped = await _storage.getMnemonicForSeedGroup(seedGroupId);
    if (grouped != null && grouped.isNotEmpty) return grouped;

    final accounts = await getWalletAccounts();
    for (final account in accounts) {
      if (account.seedGroupId == seedGroupId) {
        final mnemonic = await _storage.getMnemonic(account.address);
        if (mnemonic != null && mnemonic.isNotEmpty) return mnemonic;
      }
    }
    return null;
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
    BigInt? gasPriceWei,
    int? gasLimit,
  }) async {
    if ((gasPriceWei == null) != (gasLimit == null)) {
      throw ArgumentError(
        'gasPriceWei and gasLimit must either both be supplied or both omitted',
      );
    }
    final credentials = await getCredentials();
    final client = _clientForRpc(rpcUrl);
    final recipient = EthereumAddress.fromHex(toAddress);
    final gasPrice = gasPriceWei == null
        ? await client.getGasPrice()
        : EtherAmount.inWei(gasPriceWei);
    final resolvedGasLimit =
        gasLimit ??
        BigInt.from(
          ((await client.estimateGas(
                    sender: credentials.address,
                    to: recipient,
                    value: EtherAmount.inWei(amountInBaseUnits),
                  )).toInt() *
                  1.1)
              .ceil(),
        ).toInt();

    return client.sendTransaction(
      credentials,
      Transaction(
        to: recipient,
        value: EtherAmount.inWei(amountInBaseUnits),
        gasPrice: gasPrice,
        maxGas: resolvedGasLimit,
      ),
      chainId: chainId,
      fetchChainIdFromNetworkId: false,
    );
  }

  Future<String> sendTokenTransaction({
    required String tokenAddress,
    required String toAddress,
    required BigInt amountInBaseUnits,
    required String rpcUrl,
    required int chainId,
    BigInt? gasPriceWei,
    int? gasLimit,
  }) async {
    if ((gasPriceWei == null) != (gasLimit == null)) {
      throw ArgumentError(
        'gasPriceWei and gasLimit must either both be supplied or both omitted',
      );
    }
    final credentials = await getCredentials();
    final client = _clientForRpc(rpcUrl);
    final tokenContractAddress = EthereumAddress.fromHex(tokenAddress);
    final recipient = EthereumAddress.fromHex(toAddress);
    final contract = DeployedContract(_erc20Abi, tokenContractAddress);
    final transferFunction = contract.function('transfer');
    final data = transferFunction.encodeCall([recipient, amountInBaseUnits]);
    final gasPrice = gasPriceWei == null
        ? await client.getGasPrice()
        : EtherAmount.inWei(gasPriceWei);
    final resolvedGasLimit =
        gasLimit ??
        BigInt.from(
          ((await client.estimateGas(
                    sender: credentials.address,
                    to: tokenContractAddress,
                    data: data,
                  )).toInt() *
                  1.1)
              .ceil(),
        ).toInt();

    return client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: transferFunction,
        parameters: [recipient, amountInBaseUnits],
        gasPrice: gasPrice,
        maxGas: resolvedGasLimit,
      ),
      chainId: chainId,
      fetchChainIdFromNetworkId: false,
    );
  }

  Future<String> sendNftTransaction({
    required String contractAddress,
    required String fromAddress,
    required String toAddress,
    required BigInt tokenId,
    required String tokenType,
    required BigInt amount,
    required String rpcUrl,
    required int chainId,
  }) async {
    if (contractAddress.trim().isEmpty) {
      throw Exception('NFT contract address is missing');
    }
    if (tokenId < BigInt.zero) {
      throw Exception('NFT token ID is invalid');
    }
    if (amount <= BigInt.zero) {
      throw Exception('NFT transfer amount must be greater than zero');
    }

    final credentials = await getCredentials();
    final sender = EthereumAddress.fromHex(fromAddress);
    final contractAddressHex = EthereumAddress.fromHex(contractAddress);
    final recipient = EthereumAddress.fromHex(toAddress);
    final isErc1155 = tokenType.toUpperCase().contains('1155');
    final contract = DeployedContract(
      isErc1155 ? _erc1155Abi : _erc721Abi,
      contractAddressHex,
    );
    final transferFunction = contract.function('safeTransferFrom');
    final parameters = isErc1155
        ? <dynamic>[sender, recipient, tokenId, amount, Uint8List(0)]
        : <dynamic>[sender, recipient, tokenId];
    final data = transferFunction.encodeCall(parameters);
    final client = _clientForRpc(rpcUrl);
    final gasPrice = await client.getGasPrice();
    final estimatedGas = await client.estimateGas(
      sender: sender,
      to: contractAddressHex,
      data: data,
    );
    final bufferedGas = BigInt.from((estimatedGas.toInt() * 1.15).ceil());

    return client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: transferFunction,
        parameters: parameters,
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
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
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
        maxFeePerGas: maxFeePerGasWei == null
            ? null
            : EtherAmount.inWei(maxFeePerGasWei),
        maxPriorityFeePerGas: maxPriorityFeePerGasWei == null
            ? null
            : EtherAmount.inWei(maxPriorityFeePerGasWei),
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
    late final Future<BigInt> estimatedGasFuture;
    if (tokenAddress == null || tokenAddress.isEmpty) {
      estimatedGasFuture = client.estimateGas(
        sender: sender,
        to: recipient,
        value: EtherAmount.inWei(amountInBaseUnits),
      );
    } else {
      final tokenContractAddress = EthereumAddress.fromHex(tokenAddress);
      final contract = DeployedContract(_erc20Abi, tokenContractAddress);
      final transferFunction = contract.function('transfer');
      final data = transferFunction.encodeCall([recipient, amountInBaseUnits]);
      estimatedGasFuture = client.estimateGas(
        sender: sender,
        to: tokenContractAddress,
        data: data,
      );
    }

    final estimates = await Future.wait<Object>([
      client.getGasPrice(),
      estimatedGasFuture,
    ]);
    final gasPrice = estimates[0] as EtherAmount;
    final estimatedGas = estimates[1] as BigInt;
    final bufferedGas = BigInt.from((estimatedGas.toInt() * 1.1).ceil());
    final totalFeeWei = gasPrice.getInWei * bufferedGas;
    final totalFeeNativeDouble = EtherAmount.inWei(totalFeeWei)
        .getValueInUnit(EtherUnit.ether)
        .toDouble();

    return {
      'gasGwei': gasPrice.getValueInUnit(EtherUnit.gwei),
      'gasPriceWei': gasPrice.getInWei,
      'gasLimitUnits': bufferedGas.toDouble(),
      'totalFeeEth': totalFeeNativeDouble,
      'totalFeeUsd': totalFeeNativeDouble * nativePriceUsd,
      'totalFeeWei': totalFeeWei,
    };
  }

  Future<Map<String, dynamic>> estimateNftTransferFee({
    required String fromAddress,
    required String toAddress,
    required String contractAddress,
    required BigInt tokenId,
    required String tokenType,
    required BigInt amount,
    required String rpcUrl,
    double nativePriceUsd = 0,
  }) async {
    final client = _clientForRpc(rpcUrl);
    final sender = EthereumAddress.fromHex(fromAddress);
    final recipient = EthereumAddress.fromHex(toAddress);
    final nftContractAddress = EthereumAddress.fromHex(contractAddress);
    final isErc1155 = tokenType.toUpperCase().contains('1155');
    final contract = DeployedContract(
      isErc1155 ? _erc1155Abi : _erc721Abi,
      nftContractAddress,
    );
    final transferFunction = contract.function('safeTransferFrom');
    final parameters = isErc1155
        ? <dynamic>[sender, recipient, tokenId, amount, Uint8List(0)]
        : <dynamic>[sender, recipient, tokenId];
    final data = transferFunction.encodeCall(parameters);
    final gasPrice = await client.getGasPrice();
    final estimatedGas = await client.estimateGas(
      sender: sender,
      to: nftContractAddress,
      data: data,
    );
    final bufferedGas = BigInt.from((estimatedGas.toInt() * 1.15).ceil());
    final totalFeeWei = gasPrice.getInWei * bufferedGas;
    final totalFeeNativeDouble = EtherAmount.inWei(totalFeeWei)
        .getValueInUnit(EtherUnit.ether)
        .toDouble();

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
    final privateKeyBytes = await _getSolanaPrivateKey(fromAddress);

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
      throw Exception(
        AppErrorUtils.backendMessage(
          prepareResp.body,
          fallback: 'Solana transaction failed. Please check your balance and try again.',
        ),
      );
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
      privateKeyBytes: privateKeyBytes,
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
        AppErrorUtils.backendMessage(
          broadcastResp.body,
          fallback: 'Solana transaction failed. Please check your balance and try again.',
        ),
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
    final privateKeyBytes = await _getSolanaPrivateKey(address);
    return NativeCrypto.signSolanaMessage(
      privateKeyBytes: privateKeyBytes,
      message: messageBytes,
    );
  }

  /// Compile Relay bridge instructions into a signed Solana v0 transaction
  /// (base64) using the native Rust builder. [address] is the fee payer.
  Future<String> buildAndSignSolanaBridgeTransaction({
    required String address,
    required String recentBlockhash,
    required String instructionsJson,
    required String lookupTablesJson,
  }) async {
    final privateKeyBytes = await _getSolanaPrivateKey(address);
    return NativeCrypto.buildAndSignSolanaTransaction(
      payer: address,
      recentBlockhash: recentBlockhash,
      instructionsJson: instructionsJson,
      lookupTablesJson: lookupTablesJson,
      privateKeyBytes: privateKeyBytes,
    );
  }

  /// Sign [messageBytes] and return the fully-serialised signed Solana
  /// transaction as a base64 string: [1, <64-byte sig>, <message bytes>].
  Future<String> signSolanaTransactionRaw(
    String address,
    Uint8List messageBytes,
  ) async {
    final privateKeyBytes = await _getSolanaPrivateKey(address);
    final signatureBase58 = await NativeCrypto.signSolanaMessage(
      privateKeyBytes: privateKeyBytes,
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
    return broadcastSignedSolanaTransactionRaw(signedBase64);
  }

  /// Broadcast a fully serialized and signed Solana transaction.
  Future<String> broadcastSignedSolanaTransactionRaw(
    String signedBase64,
  ) async {
    if (signedBase64.trim().isEmpty) {
      throw ArgumentError.value(
        signedBase64,
        'signedBase64',
        'Signed transaction must not be empty',
      );
    }
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
        AppErrorUtils.backendMessage(
          broadcastResp.body,
          fallback: 'Solana transaction failed. Please check your balance and try again.',
        ),
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

  /// Fetches the current Bubblegum Merkle proof, signs the prepared Solana
  /// message locally, and broadcasts the compressed NFT transfer.
  Future<String> sendCompressedNft({
    required String assetId,
    required String fromAddress,
    required String toAddress,
  }) async {
    final prepareUri = AppEnvironment.blockchain(
      '/networks/solana:mainnet/prepare-cnft-transfer',
    );
    final response = await _httpClientService.client
        .post(
          prepareUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'assetId': assetId,
            'fromAddress': fromAddress,
            'toAddress': toAddress,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        AppErrorUtils.backendMessage(
          response.body,
          fallback: 'The compressed NFT transfer proof could not be prepared. Please try again.',
        ),
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final unsignedMessage = data['unsignedMessage']?.toString();
    if (unsignedMessage == null || unsignedMessage.isEmpty) {
      throw Exception('The compressed NFT transfer message is missing.');
    }
    return signAndBroadcastSolanaTransactionRaw(
      fromAddress,
      Uint8List.fromList(base64Decode(unsignedMessage)),
    );
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

  /// Sign a UTF-8 message using TRON's personal-message prefix.
  /// Returns a 0x-prefixed recoverable signature.
  Future<String> signTronMessageRaw(String address, String message) async {
    final privateKeyHex = await _getTronPrivateKey(address);
    final digest = tronPersonalMessageDigest(message);
    final digestHex = HEX.encode(digest);
    final signature = await NativeCrypto.signTronRawHash(
      privateKeyHex: privateKeyHex,
      rawHashHex: digestHex,
    );
    return signature.startsWith('0x') ? signature : '0x$signature';
  }

  @visibleForTesting
  static Uint8List tronPersonalMessageDigest(String message) {
    final messageBytes = utf8.encode(message);
    final prefix = utf8.encode(
      '\x19TRON Signed Message:\n${messageBytes.length}',
    );
    return web3_crypto.keccak256(
      Uint8List.fromList(<int>[...prefix, ...messageBytes]),
    );
  }

  /// Encode raw bytes as a base58 string.
  static String encodeBase58Bytes(Uint8List bytes) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    int leadingZeros = 0;
    for (final byte in bytes) {
      if (byte == 0) {
        leadingZeros++;
      } else {
        break;
      }
    }

    final digits = List<int>.filled((bytes.length * 138 ~/ 100) + 1, 0);
    int digitLen = 0;
    for (final byte in bytes) {
      int carry = byte;
      for (int i = 0; i < digitLen; i++) {
        carry += digits[i] << 8;
        digits[i] = carry % 58;
        carry ~/= 58;
      }
      while (carry > 0) {
        digits[digitLen++] = carry % 58;
        carry ~/= 58;
      }
    }

    final result = StringBuffer();
    for (int i = 0; i < leadingZeros; i++) {
      result.write('1');
    }
    for (int i = digitLen - 1; i >= 0; i--) {
      result.write(alphabet[digits[i]]);
    }
    return result.toString();
  }

  /// Decode any base58-encoded byte sequence to raw bytes.
  /// Uses an O(n) lookup-table approach instead of BigInt arithmetic.
  static Uint8List decodeBase58Bytes(String input) {
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
      16,
      invalidDigit,
      17,
      18,
      19,
      20,
      21,
      invalidDigit, // 72-79  'H'-'O' (no 'I','O')
      22, 23, 24, 25, 26, 27, 28, 29, // 80-87  'P'-'W'
      30,
      31,
      32,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit,
      invalidDigit, // 88-96  'X','Y','Z','['...
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

    return result;
  }

  /// Decode a base58-encoded Ed25519 signature (64 bytes) to raw bytes.
  static Uint8List decodeBase58Signature(String input) {
    final result = decodeBase58Bytes(input);
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
    String networkKey = 'tron:mainnet',
  }) async {
    if (amount <= BigInt.zero) {
      throw Exception('amount must be greater than zero');
    }
    final privateKeyHex = await _getTronPrivateKey(fromAddress);

    // 1. Prepare the unsigned transaction via the backend.
    final prepareUri = AppEnvironment.blockchain(
      '/networks/${Uri.encodeComponent(networkKey)}/prepare-transfer',
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
      throw Exception(
        AppErrorUtils.backendMessage(
          prepareResp.body,
          fallback: 'Tron transaction failed. Please check your balance and try again.',
        ),
      );
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
      '/networks/${Uri.encodeComponent(networkKey)}/broadcast',
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
        AppErrorUtils.backendMessage(
          broadcastResp.body,
          fallback: 'Tron transaction failed. Please check your balance and try again.',
        ),
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
    final activeAccount = await getActiveWalletAccount();
    final mnemonic = await getMnemonic(activeAccount?.address);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception(
        'Seed phrase not available. Non-EVM transactions require a seed-phrase wallet.',
      );
    }
    return NativeCrypto.mnemonicToSeed(mnemonic);
  }

  /// Returns the Ed25519 private key bytes for the given Solana [address].
  /// Checks for a directly-imported key first; falls back to mnemonic derivation.
  Future<Uint8List> _getSolanaPrivateKey(String address) async {
    final imported = await _storage.getFamilyPrivateKey(
      ChainFamily.solana,
      address,
    );
    if (imported != null && imported.isNotEmpty) {
      return Uint8List.fromList(pkg_hex.HEX.decode(imported));
    }
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

class _DerivedWalletMaterial {
  const _DerivedWalletMaterial({
    required this.derivationIndex,
    required this.privateKey,
    required this.evmAddress,
    required this.solanaAddress,
    required this.tronAddress,
    required this.publicKey,
  });

  final int derivationIndex;
  final String privateKey;
  final String evmAddress;
  final String solanaAddress;
  final String tronAddress;
  final String publicKey;

  Map<String, String> toResult() => {
    'address': evmAddress,
    'evmAddress': evmAddress,
    'solanaAddress': solanaAddress,
    'tronAddress': tronAddress,
    'privateKey': privateKey,
    'publicKey': publicKey,
    'derivationIndex': derivationIndex.toString(),
  };
}
