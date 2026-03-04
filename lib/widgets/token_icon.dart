import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

/// Token Icon Widget
/// Displays token icons with fallback support
/// Priority: Local assets -> Network URL -> TrustWallet CDN (chain-aware) -> Placeholder
class TokenIcon extends StatelessWidget {
  final String tokenSymbol;
  final String? tokenAddress;
  final String? tokenImageUrl;
  final double size;
  final Color? backgroundColor;
  final int? chainId;

  const TokenIcon({
    super.key,
    required this.tokenSymbol,
    this.tokenAddress,
    this.tokenImageUrl,
    this.size = 40,
    this.backgroundColor,
    this.chainId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? _getDefaultColor(tokenSymbol),
        shape: BoxShape.circle,
      ),
      child: ClipOval(child: _buildIcon()),
    );
  }

  Widget _buildIcon() {
    // Try local asset first only if we know it exists in the bundle.
    final symbolKey = tokenSymbol.toLowerCase();
    if (_bundledTokenIcons.contains(symbolKey)) {
      final localPath = 'assets/images/tokens/$symbolKey.png';
      return Image.asset(
        localPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    // Then try backend-provided image URL.
    if (tokenImageUrl != null && tokenImageUrl!.isNotEmpty) {
      return Image.network(
        tokenImageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildTrustWalletIcon(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }

    // If image URL is not available, fallback to Trust Wallet.
    return _buildTrustWalletIcon();
  }

  static const Set<String> _bundledTokenIcons = {
    'bnb',
    'btc',
    'dai',
    'eth',
    'link',
    'matic',
    'usdc',
    'usdt',
  };

  Widget _buildTrustWalletIcon() {
    // Try network (Trust Wallet) with chain-aware path
    if (tokenAddress != null && tokenAddress!.isNotEmpty) {
      final blockchainName = _trustWalletBlockchainName(chainId);
      final candidates = _trustWalletAddressCandidates(tokenAddress!);
      return _buildTrustWalletCandidate(blockchainName, candidates, 0);
    }

    // No address available, show placeholder
    return _buildPlaceholder();
  }

  /// Maps a chainId to the TrustWallet assets directory name.
  static String _trustWalletBlockchainName(int? chainId) {
    switch (chainId) {
      case 1:
        return 'ethereum';
      case 56:
        return 'smartchain';
      case 137:
        return 'polygon';
      case 42161:
        return 'arbitrum';
      case 10:
        return 'optimism';
      case 8453:
        return 'base';
      case 324:
        return 'zksync';
      case 43114:
        return 'avalanchec';
      case 250:
        return 'fantom';
      case 100:
        return 'xdai';
      case 8217:
        return 'klaytn';
      case 1313161554:
        return 'aurora';
      default:
        return 'ethereum';
    }
  }

  List<String> _trustWalletAddressCandidates(String address) {
    final trimmed = address.trim();
    final values = <String>{trimmed};
    values.add(trimmed.toLowerCase());
    try {
      values.add(EthereumAddress.fromHex(trimmed).hexEip55);
    } catch (_) {}
    return values.toList();
  }

  Widget _buildTrustWalletCandidate(
    String blockchainName,
    List<String> candidates,
    int index,
  ) {
    if (index >= candidates.length) {
      // Try ethereum as final fallback if we haven't already
      if (blockchainName != 'ethereum') {
        return _buildTrustWalletCandidate('ethereum', candidates, 0);
      }
      return _buildPlaceholder();
    }
    final addr = candidates[index];
    return Image.network(
      'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/$blockchainName/assets/$addr/logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildTrustWalletCandidate(
          blockchainName,
          candidates,
          index + 1,
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        tokenSymbol.isNotEmpty ? tokenSymbol[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getDefaultColor(String symbol) {
    // Default colors for common tokens
    final colors = {
      'ETH': const Color(0xFF627EEA),
      'ETHEREUM': const Color(0xFF627EEA),
      'BTC': const Color(0xFFF7931A),
      'BITCOIN': const Color(0xFFF7931A),
      'USDC': const Color(0xFF2775CA),
      'USDT': const Color(0xFF26A17B),
      'BNB': const Color(0xFFF3BA2F),
      'MATIC': const Color(0xFF8247E5),
      'AVAX': const Color(0xFFE84142),
      'FTM': const Color(0xFF1969FF),
      'FOWL': const Color(0xFFFF6B35),
      'FOMOWL': const Color(0xFFFF6B35),
    };

    return colors[symbol.toUpperCase()] ?? const Color(0xFF6B7280);
  }
}
