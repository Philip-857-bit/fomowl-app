import 'package:flutter/material.dart';

import '../services/blockchain/blockchain_catalog.dart';

/// Displays a bundled chain logo when one exists, otherwise falls back to the
/// configured remote URL. Bundled logos keep core network UI deterministic
/// when the device is offline or a remote image host is unavailable.
class ChainLogoImage extends StatelessWidget {
  const ChainLogoImage({
    super.key,
    required this.chainId,
    required this.logoUrl,
    required this.width,
    required this.height,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final int? chainId;
  final String? logoUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final assetPath = chainId == null
        ? null
        : BlockchainCatalog.localChainLogoAsset(chainId!);
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    final remoteUrl = logoUrl?.trim() ?? '';
    if (remoteUrl.isEmpty) return fallback;
    return Image.network(
      remoteUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
