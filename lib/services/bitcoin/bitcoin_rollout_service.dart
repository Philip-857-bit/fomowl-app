import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/bitcoin_account_state.dart';
import '../../models/chain.dart';
import '../../models/wallet_account.dart';
import '../blockchain_service.dart';
import '../runtime_config_service.dart';
import '../wallet_service.dart';
import 'bitcoin_wallet_vault_service.dart';
import 'bitcoin_network_service.dart';

enum BitcoinBuildAudience { internal, testUsers, beta, production }

/// Admission policy is public; it never transmits wallet identity or XPUB.
class BitcoinRolloutPolicy {
  static const _channel = String.fromEnvironment(
    'BITCOIN_BUILD_AUDIENCE',
    defaultValue: 'production',
  );
  static BitcoinBuildAudience get buildAudience => switch (_channel) {
    'internal' => BitcoinBuildAudience.internal,
    'test-users' => BitcoinBuildAudience.testUsers,
    'beta' => BitcoinBuildAudience.beta,
    _ => BitcoinBuildAudience.production,
  };
  static bool admits(
    RuntimePolicySnapshot policy,
    BitcoinBuildAudience audience,
    String identity,
  ) {
    if (!policy.bitcoinEnabled || policy.fullMaintenance) return false;
    final eligible = switch (policy.bitcoinRolloutStage) {
      'internal' => audience == BitcoinBuildAudience.internal,
      'test-users' => audience.index <= BitcoinBuildAudience.testUsers.index,
      'beta' => audience.index <= BitcoinBuildAudience.beta.index,
      'controlled-production' || 'default' => true,
      _ => false,
    };
    if (!eligible) return false;
    if (policy.bitcoinRolloutStage != 'controlled-production') return true;
    if (identity.trim().isEmpty ||
        policy.bitcoinRolloutPercent < 1 ||
        policy.bitcoinRolloutPercent > 100) {
      return false;
    }
    final digest = sha256
        .convert(utf8.encode(identity.trim().toLowerCase()))
        .bytes;
    final bucket = ((digest[0] << 8) | digest[1]) % 100;
    return bucket < policy.bitcoinRolloutPercent;
  }
}

/// Rechecks configured backend capabilities on the existing runtime refresh cycle.
/// Capability availability is configuration, not a guarantee of provider uptime.
class BitcoinRolloutService {
  final BlockchainService blockchain;
  final BitcoinNetworkApi network;
  final BitcoinBuildAudience audience;
  int _generation = 0;
  bool _disposed = false;
  final Future<void> Function(BlockchainService, bool Function())? provision;

  BitcoinRolloutService({
    required this.blockchain,
    BitcoinNetworkApi? network,
    BitcoinBuildAudience? audience,
    this.provision = provisionSeedWallet,
  }) : network = network ?? BitcoinNetworkService(),
       audience = audience ?? BitcoinRolloutPolicy.buildAudience;
  Future<void> refresh(RuntimePolicySnapshot policy) async {
    final generation = ++_generation;
    final identity = blockchain.activeWalletAddress.toLowerCase();
    if (!BitcoinRolloutPolicy.admits(policy, audience, identity)) {
      blockchain.configureBitcoinAvailability(available: false);
      return;
    }
    var mainnet = false;
    var testnet = false;
    try {
      mainnet = await network.available(BitcoinProductNetwork.mainnet);
      if (policy.bitcoinTestnetEnabled &&
          audience != BitcoinBuildAudience.production) {
        testnet = await network.available(BitcoinProductNetwork.testnet4);
      }
    } catch (_) {
      mainnet = false;
      testnet = false;
    }
    if (_disposed ||
        generation != _generation ||
        blockchain.activeWalletAddress.toLowerCase() != identity) {
      return;
    }
    blockchain.configureBitcoinAvailability(
      available: mainnet,
      testnetEnabled: testnet,
    );
    bool current() =>
        !_disposed &&
        generation == _generation &&
        blockchain.activeWalletAddress.toLowerCase() == identity;
    if (mainnet &&
        identity.isNotEmpty &&
        BitcoinWalletVaultService.isUnlocked &&
        provision != null) {
      try {
        await provision!(blockchain, current);
      } catch (_) {
        /* Custody remains fail-closed; retry after a later authenticated refresh. */
      }
    }
  }

  static Future<void> provisionSeedWallet(
    BlockchainService blockchain,
    bool Function() current,
  ) async {
    final wallet = WalletService();
    final account = await wallet.getActiveWalletAccount();
    if (!current() || account == null || account.origin != WalletOrigin.derived) {
      return;
    }
    final state = await wallet.ensureBitcoinAccount(account.address);
    if (!current() || state == null) return;
    final refreshed = await wallet.getActiveWalletAccount();
    if (!current() ||
        refreshed?.address.toLowerCase() != account.address.toLowerCase()) {
      return;
    }
    blockchain.setActiveWalletContext(
      address: refreshed!.address,
      supportedFamilies: refreshed.supportedFamilies,
    );
    if (!blockchain.enabledFamilies.contains(ChainFamily.bitcoin)) {
      await blockchain.setEnabledFamilies({
        ...blockchain.enabledFamilies,
        ChainFamily.bitcoin,
      });
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }
}
