import '../models/token.dart';

enum TokenTrustLevel { verified, unverified, suspicious }

class TokenTrustUtils {
  TokenTrustUtils._();

  static const Set<String> protectedStablecoinSymbols = {'USDT', 'USDC'};

  static const Map<int, Map<String, Set<String>>> _canonicalContracts = {
    1: {
      'USDC': {'0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'},
      'USDT': {'0xdac17f958d2ee523a2206206994597c13d831ec7'},
    },
    56: {
      'USDC': {'0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d'},
      'USDT': {'0x55d398326f99059ff775485246999027b3197955'},
    },
    137: {
      'USDC': {'0x3c499c542cef5e3811e1192ce70d8cc03d5c3359'},
      'USDT': {'0xc2132d05d31c914a87c6611c10748aeb04b58e8f'},
    },
    8453: {
      'USDC': {'0x833589fcd6edb6e08f4c7c32d4f71b54bda02913'},
      'USDT': {'0xfde4c96c8593536e31f229ea8f37b2ada2699bb2'},
    },
    42161: {
      'USDC': {'0xaf88d065e77c8cc2239327c5edb3a432268e5831'},
      'USDT': {'0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'},
    },
    792703809: {
      'USDC': {'epjfwdd5aufqssqem2qn1xzybapc8g4wegkgzwytdt1v'},
      'USDT': {'es9vmfrzacermjfrf4h2fyd4kconky11mcce8benwnyb'},
    },
    728126428: {
      'USDT': {'tr7nhqjekqxgtci8q8zy4pl8otszgjlj6t'},
      'USDC': {'tekxitehnzsmse2xqrbj4w32run966rdz8'},
    },
    -501: {
      'USDC': {'epjfwdd5aufqssqem2qn1xzybapc8g4wegkgzwytdt1v'},
      'USDT': {'es9vmfrzacermjfrf4h2fyd4kconky11mcce8benwnyb'},
    },
    -195: {
      'USDT': {'tr7nhqjekqxgtci8q8zy4pl8otszgjlj6t'},
      'USDC': {'tekxitehnzsmse2xqrbj4w32run966rdz8'},
    },
  };

  static TokenTrustLevel levelFor(Token token, {required int chainId}) {
    if (token.contractAddress == null || token.contractAddress!.isEmpty) {
      return TokenTrustLevel.verified;
    }
    if (token.isCertified || isCanonicalStablecoin(token, chainId: chainId)) {
      return TokenTrustLevel.verified;
    }
    if (protectedStablecoinSymbols.contains(
      token.symbol.trim().toUpperCase(),
    )) {
      return TokenTrustLevel.suspicious;
    }
    return TokenTrustLevel.unverified;
  }

  static bool isCanonicalStablecoin(Token token, {required int chainId}) {
    final address = token.contractAddress?.trim().toLowerCase();
    if (address == null || address.isEmpty) return false;
    final symbol = token.symbol.trim().toUpperCase();
    return _canonicalContracts[chainId]?[symbol]?.contains(address) ?? false;
  }

  static bool blocksDestination(Token token, {required int chainId}) =>
      levelFor(token, chainId: chainId) == TokenTrustLevel.suspicious;

  static String label(Token token, {required int chainId}) {
    return switch (levelFor(token, chainId: chainId)) {
      TokenTrustLevel.verified => 'Verified',
      TokenTrustLevel.unverified => 'Unverified',
      TokenTrustLevel.suspicious => 'Suspicious stablecoin',
    };
  }

  static String shortenedAddress(String? address) {
    final value = address?.trim() ?? '';
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }
}
