import '../../models/bitcoin_account_state.dart';
import '../../models/wallet_account.dart';
import '../storage_service.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_protected_record.dart';
import 'bitcoin_wallet_vault_service.dart';

/// Restart-safe seed provisioning. Existing ciphertext is authoritative; corrupt records never trigger resealing.
class BitcoinProvisioningService {
  final StorageService storage;
  final BitcoinCryptoApi crypto;
  BitcoinProvisioningService({
    required this.storage,
    this.crypto = const NativeBitcoinCrypto(),
  });
  static final Expando<Map<String, Future<BitcoinWalletAccountState>>>
  _pending = Expando();
  Future<BitcoinWalletAccountState?> ensureWallet(
    String walletIdentity, {
    BitcoinProductNetwork network = BitcoinProductNetwork.mainnet,
    bool restoreRemovedWallet = false,
  }) async {
    final generation = BitcoinWalletVaultService.beginOperation();
    final wallet = (await storage.getWalletAccounts())
        .where(
          (account) =>
              account.address.toLowerCase() == walletIdentity.toLowerCase(),
        )
        .firstOrNull;
    BitcoinWalletVaultService.checkOperation(generation);
    if (wallet == null) throw StateError('Wallet not found');
    if (wallet.origin != WalletOrigin.derived) return null;
    final index = wallet.derivationIndex ?? 0;
    if (index < 0 || index >= 0x80000000) {
      throw StateError('Invalid Bitcoin account index');
    }
    final pending = _pending[storage.bitcoinAccounts.secureStore] ??= {};
    final key =
        '${wallet.address.toLowerCase()}:${network.id}:$index:$generation';
    final existing = pending[key];
    if (existing != null) return existing;
    final operation = _provision(
      wallet,
      network,
      restoreRemovedWallet,
      generation,
    );
    pending[key] = operation;
    try {
      return await operation;
    } finally {
      if (identical(pending[key], operation)) pending.remove(key);
    }
  }

  Future<BitcoinWalletAccountState> _provision(
    WalletAccount wallet,
    BitcoinProductNetwork network,
    bool restoreRemovedWallet,
    int generation,
  ) async {
    BitcoinWalletVaultService.checkOperation(generation);
    final store = storage.bitcoinAccounts;
    if (restoreRemovedWallet) await store.activateWallet(wallet.address);
    final index = wallet.derivationIndex ?? 0;
    final current = await store.readWalletState(wallet.address, network, index);
    if (current != null && current.accounts.length == 2) {
      for (final purpose in BitcoinPurpose.values) {
        await _verifyStored(
          store,
          _slot(wallet, network, purpose),
          current.accounts[purpose]!.metadata,
          generation,
        );
      }
      BitcoinWalletVaultService.checkOperation(generation);
      await storage.setWalletBitcoinSupport(wallet.address, true);
      return current;
    }
    final mnemonic = await storage.getMnemonicForSeedWallet(wallet.address);
    if (mnemonic == null || mnemonic.isEmpty) {
      throw StateError('Seed phrase is unavailable for Bitcoin provisioning');
    }
    final seed = await crypto.mnemonicToSeed(mnemonic);
    try {
      final identity = await crypto.seedWalletIdentity(seed, index);
      if (identity.toLowerCase() != wallet.address.toLowerCase()) {
        throw StateError('Seed does not match this wallet');
      }
      for (final purpose in BitcoinPurpose.values) {
        BitcoinWalletVaultService.checkOperation(generation);
        final location = _slot(wallet, network, purpose);
        final expected = await crypto.deriveAccount(
          seed,
          network,
          index,
          purpose,
        );
        final state = await store.readState(location);
        if (state != null) {
          if (state.metadata != expected) {
            throw StateError('Bitcoin account identity mismatch');
          }
          await _verifyStored(store, location, expected, generation);
          continue;
        }
        final wrappingKey = await crypto.wrappingKey();
        ProtectedBitcoinRecord? candidate;
        try {
          final sealed = await crypto.sealSeedAccount(
            seed,
            network,
            index,
            purpose,
            wrappingKey,
          );
          if (sealed.metadata != expected) {
            throw StateError('Bitcoin account identity mismatch');
          }
          candidate = ProtectedBitcoinRecord(
            walletIdentity: location.walletIdentity,
            state: BitcoinPurposeAccountState(metadata: expected),
            encryptedVault: sealed.encryptedVault,
            wrappingKey: wrappingKey,
          );
          BitcoinWalletVaultService.checkOperation(generation);
          await store.createIfAbsent(location, candidate);
          await _verifyStored(store, location, expected, generation);
        } finally {
          if (candidate != null) {
            candidate.dispose();
          } else {
            wrappingKey.fillRange(0, wrappingKey.length, 0);
          }
        }
      }
      final result = await store.readWalletState(
        wallet.address,
        network,
        index,
      );
      if (result == null || result.accounts.length != 2) {
        throw StateError('Bitcoin custody provisioning was not retained');
      }
      BitcoinWalletVaultService.checkOperation(generation);
      await storage.setWalletBitcoinSupport(wallet.address, true);
      return result;
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  BitcoinAccountSlot _slot(
    WalletAccount wallet,
    BitcoinProductNetwork network,
    BitcoinPurpose purpose,
  ) => BitcoinAccountSlot(
    walletIdentity: wallet.address,
    network: network,
    accountIndex: wallet.derivationIndex ?? 0,
    purpose: purpose,
  );
  Future<void> _verifyStored(
    BitcoinAccountStore store,
    BitcoinAccountSlot location,
    BitcoinHdAccountMetadata expected,
    int generation,
  ) => store.withRecord(location, (record) async {
    if (record.state.metadata != expected) {
      throw StateError('Bitcoin account identity mismatch');
    }
    BitcoinWalletVaultService.checkOperation(generation);
    final signer = await crypto.openAccount(
      expected,
      record.encryptedVault,
      record.wrappingKey,
    );
    try {
      BitcoinWalletVaultService.checkOperation(generation);
      if (await signer.accountInfo() != expected) {
        throw StateError('Bitcoin account identity mismatch');
      }
    } finally {
      await signer.close();
    }
  });
}
