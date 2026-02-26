import 'package:flutter/material.dart';

/// Token Icon Widget
/// Displays token icons with fallback support
/// Priority: Local assets -> Network URL -> Placeholder
class TokenIcon extends StatelessWidget {
  final String tokenSymbol;
  final String? tokenAddress;
  final double size;
  final Color? backgroundColor;

  const TokenIcon({
    super.key,
    required this.tokenSymbol,
    this.tokenAddress,
    this.size = 40,
    this.backgroundColor,
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
      child: ClipOval(
        child: _buildIcon(),
      ),
    );
  }

  Widget _buildIcon() {
    // Try local asset first
    final localPath = 'assets/images/tokens/${tokenSymbol.toLowerCase()}.png';
    
    return Image.asset(
      localPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // If local asset fails, try network (Trust Wallet)
        if (tokenAddress != null && tokenAddress!.isNotEmpty) {
          return Image.network(
            'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/$tokenAddress/logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // If network fails, show placeholder
              return _buildPlaceholder();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildPlaceholder();
            },
          );
        }
        
        // No address available, show placeholder
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
      'FOWL': const Color(0xFFFF6B35),
      'FOMOWL': const Color(0xFFFF6B35),
    };
    
    return colors[symbol.toUpperCase()] ?? const Color(0xFF6B7280);
  }
}
