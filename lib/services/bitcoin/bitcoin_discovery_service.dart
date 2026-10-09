import 'dart:math';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_discovery.dart';
import '../../models/bitcoin_network_data.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_protected_record.dart';

class _LaneResult {
  final int? lastUsed;
  const _LaneResult(this.lastUsed);
}

/// Public watch-only discovery. Providers see address batches, never extended account keys.
class BitcoinDiscoveryService {
  final BitcoinAccountStore store;
  final BitcoinCryptoApi crypto;
  final BitcoinNetworkApi network;
  final int gapLimit;
  final int maximumScanIndex;
  final DateTime Function() now;
  BitcoinDiscoveryService({
    required this.store,
    required this.network,
    this.crypto = const NativeBitcoinCrypto(),
    this.gapLimit = 20,
    this.maximumScanIndex = 10000,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    if (gapLimit < 1 ||
        gapLimit > 40 ||
        maximumScanIndex < gapLimit ||
        maximumScanIndex > 100000) {
      throw ArgumentError('Invalid Bitcoin discovery limits');
    }
  }
  Future<BitcoinDiscoverySnapshot> scan(
    BitcoinWalletAccountState initial, {
    bool Function()? isCurrent,
  }) async {
    if (initial.accounts.length != 2) {
      throw StateError('Bitcoin custody is not fully provisioned');
    }
    final current = isCurrent ?? () => true;
    final ownership = <String, BitcoinDerivedAddress>{};
    final activity = <String, BitcoinAddressActivity>{};
    final outpoints = <String>{};
    final states = <BitcoinPurpose, BitcoinPurposeAccountState>{};
    final scannedAt = now().toUtc();
    for (final purpose in BitcoinPurpose.values) {
      _checkCurrent(current);
      final state = initial.accounts[purpose]!;
      final external = await _scanLane(
        initial.walletIdentity,
        state,
        BitcoinKeychain.receive,
        ownership,
        activity,
        outpoints,
        current,
      );
      final internal = await _scanLane(
        initial.walletIdentity,
        state,
        BitcoinKeychain.change,
        ownership,
        activity,
        outpoints,
        current,
      );
      _checkCurrent(current);
      final location = BitcoinAccountSlot(
        walletIdentity: initial.walletIdentity,
        network: initial.network,
        accountIndex: initial.accountIndex,
        purpose: purpose,
      );
      states[purpose] = await store.updateState(location, (latest) {
        final receiveUsed = _latestIndex(
          latest.lastUsedExternal,
          external.lastUsed,
        );
        final changeUsed = _latestIndex(
          latest.lastUsedInternal,
          internal.lastUsed,
        );
        return latest.advance(
          lastUsedExternal: receiveUsed,
          lastUsedInternal: changeUsed,
          nextExternal: max(
            latest.nextExternal,
            receiveUsed == null ? 0 : receiveUsed + 1,
          ),
          nextInternal: max(
            latest.nextInternal,
            changeUsed == null ? 0 : changeUsed + 1,
          ),
          lastScan:
              latest.lastScan != null && latest.lastScan!.isAfter(scannedAt)
              ? latest.lastScan
              : scannedAt,
        );
      });
    }
    _checkCurrent(current);
    return BitcoinDiscoverySnapshot(
      state: BitcoinWalletAccountState(
        walletIdentity: initial.walletIdentity,
        network: initial.network,
        accountIndex: initial.accountIndex,
        accounts: states,
      ),
      ownership: ownership,
      activity: activity,
      scannedAt: scannedAt,
    );
  }

  int? _latestIndex(int? before, int? observed) => before == null
      ? observed
      : observed == null
      ? before
      : max(before, observed);
  void _checkCurrent(bool Function() current) {
    if (!current()) throw StateError('Bitcoin discovery context changed');
  }

  Future<_LaneResult> _scanLane(
    String identity,
    BitcoinPurposeAccountState state,
    BitcoinKeychain keychain,
    Map<String, BitcoinDerivedAddress> ownership,
    Map<String, BitcoinAddressActivity> activity,
    Set<String> outpoints,
    bool Function() current,
  ) async {
    final anchor = keychain == BitcoinKeychain.receive
        ? state.nextExternal
        : state.nextInternal;
    if (anchor + gapLimit > maximumScanIndex) {
      throw StateError('Bitcoin discovery scan limit reached');
    }
    var nextIndex = 0;
    var unused = 0;
    int? lastUsed;
    while (nextIndex < maximumScanIndex) {
      _checkCurrent(current);
      final count = min(gapLimit, maximumScanIndex - nextIndex);
      final addresses = <String>[];
      final refs = <String, BitcoinDerivedAddress>{};
      for (var offset = 0; offset < count; offset++) {
        final index = nextIndex + offset;
        final address = await crypto.deriveAddress(
          state.metadata,
          keychain,
          index,
        );
        _checkCurrent(current);
        if (ownership.containsKey(address) || refs.containsKey(address)) {
          throw StateError('Conflicting Bitcoin address derivations');
        }
        addresses.add(address);
        refs[address] = BitcoinDerivedAddress(
          account: state.metadata,
          keychain: keychain,
          addressIndex: index,
          address: address,
        );
      }
      final response = await network.fetchAccountState(
        identity,
        state.metadata.network,
        addresses,
      );
      _checkCurrent(current);
      final rows = <String, BitcoinAddressActivity>{};
      for (final row in response) {
        if (!refs.containsKey(row.address) || rows.containsKey(row.address)) {
          throw const FormatException(
            'Bitcoin discovery address response mismatch',
          );
        }
        for (final utxo in row.utxos) {
          if (!outpoints.add(utxo.outpoint)) {
            throw const FormatException('Duplicate Bitcoin discovery outpoint');
          }
        }
        rows[row.address] = row;
      }
      if (rows.length != addresses.length) {
        throw const FormatException('Incomplete Bitcoin discovery response');
      }
      // Process the complete fetched batch, including activity beyond its first empty address.
      for (final address in addresses) {
        final ref = refs[address]!;
        final row = rows[address]!;
        if (row.used) {
          lastUsed = ref.addressIndex;
          unused = 0;
        } else {
          unused++;
        }
        ownership[address] = ref;
        activity[address] = row;
      }
      nextIndex += count;
      if (unused >= gapLimit && nextIndex >= anchor + gapLimit) {
        return _LaneResult(lastUsed);
      }
    }
    throw StateError('Bitcoin discovery scan limit reached');
  }
}
