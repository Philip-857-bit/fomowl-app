import 'dart:typed_data';
import '../../models/bitcoin_account_state.dart';
import '../../src/rust/api/bitcoin_account.dart' as accounts;
import '../../src/rust/api/bitcoin_transaction.dart' as transactions;
import '../../src/rust/api/bitcoin_signing_account.dart' as custody;
import '../../src/rust/api/bitcoin_vault.dart' as vault;
import '../native_crypto.dart';

class SealedBitcoinAccount {
  final BitcoinHdAccountMetadata metadata;
  final String encryptedVault;
  const SealedBitcoinAccount(this.metadata, this.encryptedVault);
}

abstract interface class BitcoinSigningAccount {
  Future<BitcoinHdAccountMetadata> accountInfo();
  Future<transactions.SignedBitcoinTransactionDto> signTransaction(
    transactions.BitcoinTransactionPlanDto plan,
  );
  Future<String> signPsbt(String psbtBase64);
  Future<void> close();
}

abstract interface class BitcoinCryptoApi {
  Future<Uint8List> mnemonicToSeed(String mnemonic);
  Future<String> seedWalletIdentity(Uint8List seed, int accountIndex);
  Future<Uint8List> wrappingKey();
  Future<BitcoinHdAccountMetadata> deriveAccount(
    Uint8List seed,
    BitcoinProductNetwork network,
    int accountIndex,
    BitcoinPurpose purpose,
  );
  Future<String> deriveAddress(
    BitcoinHdAccountMetadata account,
    BitcoinKeychain keychain,
    int index,
  );
  Future<String> deriveScript(
    BitcoinHdAccountMetadata account,
    BitcoinKeychain keychain,
    int index,
  );
  Future<SealedBitcoinAccount> sealSeedAccount(
    Uint8List seed,
    BitcoinProductNetwork network,
    int accountIndex,
    BitcoinPurpose purpose,
    Uint8List wrappingKey,
  );
  Future<BitcoinSigningAccount> openAccount(
    BitcoinHdAccountMetadata account,
    String encryptedVault,
    Uint8List wrappingKey,
  );
  Future<transactions.BitcoinTransactionPlanDto> plan(
    BitcoinHdAccountMetadata account,
    List<transactions.BitcoinUtxoDto> utxos,
    List<transactions.BitcoinRecipientDto> recipients,
    BigInt feeRateSatVb,
    int changeIndex,
    bool rbf,
  );
}

/// Platform transport only. Every derivation, script, planner and signature is an SDK operation.
class NativeBitcoinCrypto implements BitcoinCryptoApi {
  const NativeBitcoinCrypto();
  static accounts.BitcoinNetworkDto networkDto(BitcoinProductNetwork network) =>
      switch (network) {
        BitcoinProductNetwork.mainnet => accounts.BitcoinNetworkDto.mainnet,
        BitcoinProductNetwork.testnet4 => accounts.BitcoinNetworkDto.testnet4,
      };
  static accounts.BitcoinPurposeDto purposeDto(BitcoinPurpose purpose) =>
      switch (purpose) {
        BitcoinPurpose.bip84 => accounts.BitcoinPurposeDto.bip84,
        BitcoinPurpose.bip86 => accounts.BitcoinPurposeDto.bip86,
      };
  static accounts.BitcoinKeychainDto keychainDto(BitcoinKeychain keychain) =>
      switch (keychain) {
        BitcoinKeychain.receive => accounts.BitcoinKeychainDto.external_,
        BitcoinKeychain.change => accounts.BitcoinKeychainDto.internal,
      };
  static accounts.BitcoinAccountDto accountDto(
    BitcoinHdAccountMetadata account,
  ) => accounts.BitcoinAccountDto(
    network: networkDto(account.network),
    purpose: purposeDto(account.purpose),
    accountIndex: account.accountIndex,
    masterFingerprint: account.masterFingerprint,
    accountXpub: account.accountXpub,
  );
  static BitcoinHdAccountMetadata metadata(
    accounts.BitcoinAccountDto account,
  ) => BitcoinHdAccountMetadata(
    network: switch (account.network) {
      accounts.BitcoinNetworkDto.mainnet => BitcoinProductNetwork.mainnet,
      accounts.BitcoinNetworkDto.testnet4 => BitcoinProductNetwork.testnet4,
    },
    purpose: switch (account.purpose) {
      accounts.BitcoinPurposeDto.bip84 => BitcoinPurpose.bip84,
      accounts.BitcoinPurposeDto.bip86 => BitcoinPurpose.bip86,
    },
    accountIndex: account.accountIndex,
    masterFingerprint: account.masterFingerprint,
    accountXpub: account.accountXpub,
  );
  @override
  Future<Uint8List> mnemonicToSeed(String mnemonic) =>
      NativeCrypto.mnemonicToSeed(mnemonic);
  @override
  Future<String> seedWalletIdentity(Uint8List seed, int accountIndex) =>
      NativeCrypto.deriveEvmAddressFromSeed(seed, accountIndex);
  @override
  Future<Uint8List> wrappingKey() => NativeCrypto.generateVaultWrappingKey();
  @override
  Future<BitcoinHdAccountMetadata> deriveAccount(
    Uint8List seed,
    BitcoinProductNetwork network,
    int accountIndex,
    BitcoinPurpose purpose,
  ) async => metadata(
    await accounts.deriveBitcoinAccountMetadata(
      seed: seed,
      network: networkDto(network),
      accountIndex: accountIndex,
      purpose: purposeDto(purpose),
    ),
  );
  @override
  Future<String> deriveAddress(
    BitcoinHdAccountMetadata account,
    BitcoinKeychain keychain,
    int index,
  ) => accounts.deriveBitcoinAccountAddress(
    account: accountDto(account),
    network: networkDto(account.network),
    keychain: keychainDto(keychain),
    addressIndex: index,
  );
  @override
  Future<String> deriveScript(
    BitcoinHdAccountMetadata account,
    BitcoinKeychain keychain,
    int index,
  ) => accounts.deriveBitcoinOwnedScript(
    account: accountDto(account),
    network: networkDto(account.network),
    keychain: keychainDto(keychain),
    addressIndex: index,
  );
  @override
  Future<SealedBitcoinAccount> sealSeedAccount(
    Uint8List seed,
    BitcoinProductNetwork network,
    int accountIndex,
    BitcoinPurpose purpose,
    Uint8List wrappingKey,
  ) async {
    final sealed = await vault.sealBitcoinSeedAccount(
      seed: seed,
      network: networkDto(network),
      accountIndex: accountIndex,
      purpose: purposeDto(purpose),
      wrappingKey: wrappingKey,
    );
    return SealedBitcoinAccount(
      metadata(sealed.account),
      sealed.encryptedVault,
    );
  }

  @override
  Future<BitcoinSigningAccount> openAccount(
    BitcoinHdAccountMetadata account,
    String encryptedVault,
    Uint8List wrappingKey,
  ) async => _NativeBitcoinSigner(
    await custody.openBitcoinSigningAccount(
      account: accountDto(account),
      encryptedVault: encryptedVault,
      wrappingKey: wrappingKey,
    ),
  );
  @override
  Future<transactions.BitcoinTransactionPlanDto> plan(
    BitcoinHdAccountMetadata account,
    List<transactions.BitcoinUtxoDto> utxos,
    List<transactions.BitcoinRecipientDto> recipients,
    BigInt feeRateSatVb,
    int changeIndex,
    bool rbf,
  ) => transactions.planBitcoinTransfer(
    network: networkDto(account.network),
    account: accountDto(account),
    candidateUtxos: utxos,
    recipients: recipients,
    feeRateSatVb: feeRateSatVb,
    changeIndex: changeIndex,
    rbf: rbf,
  );
}

class _NativeBitcoinSigner implements BitcoinSigningAccount {
  final custody.RustBitcoinSigningAccount signer;
  Future<void>? _closing;
  _NativeBitcoinSigner(this.signer);
  void _requireOpen() {
    if (_closing != null || signer.isDisposed) {
      throw StateError('Bitcoin signing account is closed');
    }
  }

  @override
  Future<BitcoinHdAccountMetadata> accountInfo() async {
    _requireOpen();
    return NativeBitcoinCrypto.metadata(await signer.accountInfo());
  }

  @override
  Future<transactions.SignedBitcoinTransactionDto> signTransaction(
    transactions.BitcoinTransactionPlanDto plan,
  ) {
    _requireOpen();
    return signer.signTransaction(plan: plan);
  }

  @override
  Future<String> signPsbt(String psbtBase64) {
    _requireOpen();
    return signer.signPsbt(psbtBase64: psbtBase64);
  }

  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (signer.isDisposed) return;
    try {
      await signer.close();
    } finally {
      signer.dispose();
    }
  }
}
