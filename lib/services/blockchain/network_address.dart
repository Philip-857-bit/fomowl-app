// Stateless wallet-address validation per chain family, extracted from
// `BlockchainService`.

import '../../models/chain.dart';

/// Returns true when [walletAddress] has a valid on-chain format for the family
/// of [networkKey] (EVM hex, Solana base58, or Tron base58).
bool walletAddressLooksValidForNetwork(
  String walletAddress,
  String networkKey,
) {
  final address = walletAddress.trim();
  if (address.isEmpty) return false;
  return switch (NetworkKey.familyOf(networkKey)) {
    ChainFamily.bitcoin => false,
    ChainFamily.evm => RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address),
    ChainFamily.solana => RegExp(
      r'^[1-9A-HJ-NP-Za-km-z]{32,44}$',
    ).hasMatch(address),
    ChainFamily.tron => RegExp(
      r'^T[1-9A-HJ-NP-Za-km-z]{33}$',
    ).hasMatch(address),
  };
}
