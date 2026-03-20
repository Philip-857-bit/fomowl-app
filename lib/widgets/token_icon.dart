import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

import '../services/blockchain/blockchain_catalog.dart';

/// Token Icon Widget
/// Displays token icons with fallback support
/// Priority: Local assets -> Network URL -> TrustWallet CDN (chain-aware) -> Native chain logo -> Placeholder
class TokenIcon extends StatelessWidget {
  static final Set<String> _knownMissingUrls = <String>{};

  final String tokenSymbol;
  final String? tokenAddress;
  final String? tokenImageUrl;
  final double size;
  final Color? backgroundColor;
  final int? chainId;
  final bool isCertified;

  const TokenIcon({
    super.key,
    required this.tokenSymbol,
    this.tokenAddress,
    this.tokenImageUrl,
    this.size = 40,
    this.backgroundColor,
    this.chainId,
    this.isCertified = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget icon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? _getDefaultColor(tokenSymbol),
        shape: BoxShape.circle,
      ),
      child: ClipOval(child: _buildIcon()),
    );

    if (!isCertified) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified, size: size * 0.35, color: Colors.red),
          ),
        ),
      ],
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
      return _buildNetworkImage(
        tokenImageUrl!,
        fallback: _buildTrustWalletIcon(),
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
    return _buildNativeLogoFallback();
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
    } catch (e) {
      debugPrint('Error converting checksum address: $e');
    }
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
      return _buildNativeLogoFallback();
    }
    final addr = candidates[index];
    final url =
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/$blockchainName/assets/$addr/logo.png';
    return _buildNetworkImage(
      url,
      fallback: _buildTrustWalletCandidate(
        blockchainName,
        candidates,
        index + 1,
      ),
    );
  }

  Widget _buildNativeLogoFallback() {
    final nativeLogoUrl = chainId == null
        ? null
        : BlockchainCatalog.defaultChainLogoUrl(chainId!);
    if (nativeLogoUrl == null || nativeLogoUrl.isEmpty) {
      return _buildPlaceholder();
    }
    return _buildNetworkImage(nativeLogoUrl, fallback: _buildPlaceholder());
  }

  Widget _buildNetworkImage(String url, {required Widget fallback}) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty || _knownMissingUrls.contains(normalizedUrl)) {
      return fallback;
    }
    return Image.network(
      normalizedUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        _knownMissingUrls.add(normalizedUrl);
        return fallback;
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
