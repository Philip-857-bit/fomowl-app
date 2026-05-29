// Pure EVM ABI/hex decoding helpers extracted from `BlockchainService`.
// Stateless utilities (no instance state, no notifications) for decoding
// `eth_call` string results and building token logo URLs.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Build the TrustWallet asset logo URL for a token contract on a supported
/// chain, or null when the chain is unsupported or the address is malformed.
String? trustWalletTokenLogoUrl(int chainId, String contractAddress) {
  final normalized = contractAddress.trim().toLowerCase();
  final folder = switch (chainId) {
    1 => 'ethereum',
    56 => 'smartchain',
    137 => 'polygon',
    42161 => 'arbitrum',
    10 => 'optimism',
    8453 => 'base',
    43114 => 'avalanchec',
    250 => 'fantom',
    100 => 'xdai',
    _ => null,
  };
  if (folder == null || normalized.length != 42) {
    return null;
  }
  return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/$folder/assets/$normalized/logo.png';
}

/// Decode an ABI-encoded `string` return value (dynamic-offset layout or a
/// bytes32-style fallback) from an `eth_call` hex result.
String? decodeAbiStringResult(String rawHexResult) {
  final hex = rawHexResult.startsWith('0x')
      ? rawHexResult.substring(2)
      : rawHexResult;
  if (hex.isEmpty) return null;

  if (hex.length >= 192) {
    try {
      final offset = int.parse(hex.substring(0, 64), radix: 16);
      final lengthPos = offset * 2;
      if (lengthPos + 64 <= hex.length) {
        final strLen = int.parse(
          hex.substring(lengthPos, lengthPos + 64),
          radix: 16,
        );
        final dataStart = lengthPos + 64;
        final dataEnd = dataStart + (strLen * 2);
        if (strLen > 0 && dataEnd <= hex.length) {
          return _hexToUtf8(hex.substring(dataStart, dataEnd));
        }
      }
    } catch (e) {
      debugPrint('Error parsing hex as string: $e');
    }
  }

  final bytes32 = hex.substring(0, hex.length >= 64 ? 64 : hex.length);
  return _hexToUtf8(bytes32);
}

String? _hexToUtf8(String hex) {
  if (hex.isEmpty) return null;
  final bytes = <int>[];
  for (var i = 0; i + 1 < hex.length; i += 2) {
    final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
    if (byte == null || byte == 0) continue;
    bytes.add(byte);
  }
  if (bytes.isEmpty) return null;
  try {
    return utf8.decode(bytes).trim();
  } catch (_) {
    return String.fromCharCodes(bytes).trim();
  }
}
