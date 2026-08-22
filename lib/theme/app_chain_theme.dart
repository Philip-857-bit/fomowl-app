import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/chain.dart';
import '../models/network_entry.dart';
import '../services/blockchain/blockchain_catalog.dart';
import '../services/blockchain_service.dart';

/// Dynamic theme definition corresponding to the 35 Figma designs
/// supporting Ethereum, BSC, Solana, Base, Tron, and curated ecosystem presets.
class AppChainTheme {
  final String id;
  final String displayName;
  final Color primaryColor;
  final Color accentColor;
  final Color? secondaryAccent;
  final LinearGradient balanceCardGradient;
  final LinearGradient? balanceCardBorderGradient;
  final LinearGradient buttonGradient;
  final Color glassTint;
  final Color badgeColor;
  final Color surfaceOverlay;
  final Color activeIndicatorColor;

  const AppChainTheme({
    required this.id,
    required this.displayName,
    required this.primaryColor,
    required this.accentColor,
    this.secondaryAccent,
    required this.balanceCardGradient,
    this.balanceCardBorderGradient,
    required this.buttonGradient,
    required this.glassTint,
    required this.badgeColor,
    required this.surfaceOverlay,
    required this.activeIndicatorColor,
  });

  // --------------------------------------------------------------------------
  // Tier 1: Explicit Figma Hero Themes (100% Pixel Match with Figma 35 Designs)
  // --------------------------------------------------------------------------

  /// Ethereum (ETH) Theme — Figma #315:7033, #315:2130, #315:3825, #315:5116
  static const AppChainTheme ethereum = AppChainTheme(
    id: 'ethereum',
    displayName: 'Ethereum',
    primaryColor: Color(0xFF627EEA),
    accentColor: Color(0xFF627EEA),
    secondaryAccent: Color(0xFF8C9FF5),
    balanceCardGradient: LinearGradient(
      colors: [
        Color(0xFF1E284A),
        Color(0xFF111728),
        Color(0xFF0A0A0A),
      ],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [
        Color(0xFF627EEA),
        Color(0x00000000),
        Color(0xFF627EEA),
      ],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFF627EEA), Color(0xFF3F5BB5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFF627EEA),
    badgeColor: Color(0xFF627EEA),
    surfaceOverlay: Color(0x22627EEA),
    activeIndicatorColor: Color(0xFF627EEA),
  );

  /// BNB Smart Chain (BSC) Theme — Figma #315:7034, #315:2469, #315:3982, #315:5290
  static const AppChainTheme bsc = AppChainTheme(
    id: 'bsc',
    displayName: 'BNB Smart Chain',
    primaryColor: Color(0xFFF3BA2F),
    accentColor: Color(0xFFF3BA2F),
    secondaryAccent: Color(0xFFF7B617),
    balanceCardGradient: LinearGradient(
      colors: [
        Color(0x66F7B617),
        Color(0x66000000),
        Color(0x66FFBD1B),
      ],
      stops: [0.0, 0.77, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [
        Color(0xFFF3BA2F),
        Color(0x00000000),
        Color(0xFFF3BA2F),
      ],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFFF3BA2F), Color(0xFFC79212)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFFF3BA2F),
    badgeColor: Color(0xFFF3BA2F),
    surfaceOverlay: Color(0x22F3BA2F),
    activeIndicatorColor: Color(0xFFF3BA2F),
  );

  /// Solana (SOL) Theme — Figma #315:7035, #315:2808, #315:4139, #315:5464
  static const AppChainTheme solana = AppChainTheme(
    id: 'solana',
    displayName: 'Solana',
    primaryColor: Color(0xFF9945FF),
    accentColor: Color(0xFF14F195),
    secondaryAccent: Color(0xFF9945FF),
    balanceCardGradient: LinearGradient(
      colors: [
        Color(0x739945FF),
        Color(0x4014F195),
        Color(0xFF0A0A0A),
      ],
      stops: [0.0, 0.6, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [
        Color(0xFF9945FF),
        Color(0x00000000),
        Color(0xFF14F195),
      ],
      stops: [0.0, 0.5, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFF9945FF), Color(0xFF14F195)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFF14F195),
    badgeColor: Color(0xFF14F195),
    surfaceOverlay: Color(0x2214F195),
    activeIndicatorColor: Color(0xFF14F195),
  );

  /// Base Theme — Figma #315:7036, #315:3147, #315:4293, #315:5637
  static const AppChainTheme base = AppChainTheme(
    id: 'base',
    displayName: 'Base',
    primaryColor: Color(0xFF0052FF),
    accentColor: Color(0xFF0052FF),
    secondaryAccent: Color(0xFF2563EB),
    balanceCardGradient: LinearGradient(
      colors: [
        Color(0xFF0D2566),
        Color(0xFF09163D),
        Color(0xFF0A0A0A),
      ],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [
        Color(0xFF0052FF),
        Color(0x00000000),
        Color(0xFF0052FF),
      ],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFF0052FF), Color(0xFF003AB8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFF0052FF),
    badgeColor: Color(0xFF0052FF),
    surfaceOverlay: Color(0x220052FF),
    activeIndicatorColor: Color(0xFF0052FF),
  );

  /// Tron Theme — Figma #315:7037, #315:3486, #315:4447, #315:5810
  static const AppChainTheme tron = AppChainTheme(
    id: 'tron',
    displayName: 'Tron',
    primaryColor: Color(0xFFFF060A),
    accentColor: Color(0xFFFF060A),
    secondaryAccent: Color(0xFFEF0027),
    balanceCardGradient: LinearGradient(
      colors: [
        Color(0xFF3B080A),
        Color(0xFF1F0607),
        Color(0xFF0A0A0A),
      ],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [
        Color(0xFFFF060A),
        Color(0x00000000),
        Color(0xFFFF060A),
      ],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFFFF060A), Color(0xFFB30407)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFFFF060A),
    badgeColor: Color(0xFFFF060A),
    surfaceOverlay: Color(0x22FF060A),
    activeIndicatorColor: Color(0xFFFF060A),
  );

  // --------------------------------------------------------------------------
  // Tier 2 & 3: Curated Ecosystem Presets for Other Built-in Chains
  // --------------------------------------------------------------------------

  /// Polygon (MATIC / POL)
  static const AppChainTheme polygon = AppChainTheme(
    id: 'polygon',
    displayName: 'Polygon',
    primaryColor: Color(0xFF8247E5),
    accentColor: Color(0xFF8247E5),
    secondaryAccent: Color(0xFFA56DFF),
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF2C1354), Color(0xFF170A2E), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFF8247E5), Color(0x00000000), Color(0xFF8247E5)],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFF8247E5), Color(0xFF5B1FB8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFF8247E5),
    badgeColor: Color(0xFF8247E5),
    surfaceOverlay: Color(0x228247E5),
    activeIndicatorColor: Color(0xFF8247E5),
  );

  /// Arbitrum One
  static const AppChainTheme arbitrum = AppChainTheme(
    id: 'arbitrum',
    displayName: 'Arbitrum One',
    primaryColor: Color(0xFF28A0F0),
    accentColor: Color(0xFF28A0F0),
    secondaryAccent: Color(0xFF65BEF6),
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF0C3352), Color(0xFF071D2E), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFF28A0F0), Color(0x00000000), Color(0xFF28A0F0)],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFF28A0F0), Color(0xFF166AA3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFF28A0F0),
    badgeColor: Color(0xFF28A0F0),
    surfaceOverlay: Color(0x2228A0F0),
    activeIndicatorColor: Color(0xFF28A0F0),
  );

  /// Optimism
  static const AppChainTheme optimism = AppChainTheme(
    id: 'optimism',
    displayName: 'Optimism',
    primaryColor: Color(0xFFFF0420),
    accentColor: Color(0xFFFF0420),
    secondaryAccent: Color(0xFFFF5264),
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF380309), Color(0xFF1C0205), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFFFF0420), Color(0x00000000), Color(0xFFFF0420)],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFFFF0420), Color(0xFFB00215)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFFFF0420),
    badgeColor: Color(0xFFFF0420),
    surfaceOverlay: Color(0x22FF0420),
    activeIndicatorColor: Color(0xFFFF0420),
  );

  /// Avalanche C-Chain
  static const AppChainTheme avalanche = AppChainTheme(
    id: 'avalanche',
    displayName: 'Avalanche',
    primaryColor: Color(0xFFE84142),
    accentColor: Color(0xFFE84142),
    secondaryAccent: Color(0xFFFF6E6E),
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF330F10), Color(0xFF1C0909), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFFE84142), Color(0x00000000), Color(0xFFE84142)],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFFE84142), Color(0xFFA12425)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFFE84142),
    badgeColor: Color(0xFFE84142),
    surfaceOverlay: Color(0x22E84142),
    activeIndicatorColor: Color(0xFFE84142),
  );

  /// Ethereum Layer-2 Adaptive Fallback
  static const AppChainTheme ethereumL2 = AppChainTheme(
    id: 'ethereum_l2',
    displayName: 'Ethereum Layer 2',
    primaryColor: Color(0xFF4C7FFF),
    accentColor: Color(0xFF4C7FFF),
    secondaryAccent: Color(0xFF85A7FF),
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF142247), Color(0xFF0B1226), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFF4C7FFF), Color(0x00000000), Color(0xFF4C7FFF)],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFF4C7FFF), Color(0xFF2956CC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFF4C7FFF),
    badgeColor: Color(0xFF4C7FFF),
    surfaceOverlay: Color(0x224C7FFF),
    activeIndicatorColor: Color(0xFF4C7FFF),
  );

  /// FOMOwl Signature Brand Fallback Theme
  static const AppChainTheme fomowlSignature = AppChainTheme(
    id: 'fomowl_signature',
    displayName: 'FOMOwl Wallet',
    primaryColor: AppColors.primaryAccent,
    accentColor: AppColors.accentRed,
    secondaryAccent: AppColors.accentGradientStart,
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF2A0808), Color(0xFF1A0505), Color(0xFF0A0A0B)],
      stops: [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [AppColors.accentRed, Color(0x00000000), AppColors.accentRed],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: AppColors.primaryGradient,
    glassTint: AppColors.accentRed,
    badgeColor: AppColors.accentRed,
    surfaceOverlay: Color(0x22FF3344),
    activeIndicatorColor: AppColors.accentRed,
  );

  // --------------------------------------------------------------------------
  // Tier 4: Custom Chain Deterministic Theme Generator
  // --------------------------------------------------------------------------

  /// Dynamically computes a cohesive theme for any user-added custom EVM chain
  static AppChainTheme fromCustomChain(EvmChain chain) {
    final seed = chain.chainId.abs();
    final hue = (seed * 137.5) % 360; // Golden angle color distribution
    final primary = HSLColor.fromAHSL(1.0, hue, 0.78, 0.52).toColor();
    final accent = HSLColor.fromAHSL(1.0, hue, 0.85, 0.58).toColor();
    final darkBase = HSLColor.fromAHSL(1.0, hue, 0.65, 0.12).toColor();

    return AppChainTheme(
      id: 'custom_${chain.chainId}',
      displayName: chain.name,
      primaryColor: primary,
      accentColor: accent,
      balanceCardGradient: LinearGradient(
        colors: [darkBase, Color(0xFF0A0A0A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      balanceCardBorderGradient: LinearGradient(
        colors: [accent, Color(0x00000000), accent],
        stops: const [0.0, 0.67, 1.0],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      buttonGradient: LinearGradient(
        colors: [primary, darkBase],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glassTint: accent,
      badgeColor: accent,
      surfaceOverlay: accent.withValues(alpha: 0.15),
      activeIndicatorColor: accent,
    );
  }

  // --------------------------------------------------------------------------
  // Resolution Registry (O(1) lookup)
  // --------------------------------------------------------------------------

  static final Map<int, AppChainTheme> _evmPresetMap = {
    1: ethereum,
    56: bsc,
    8453: base,
    137: polygon,
    42161: arbitrum,
    10: optimism,
    43114: avalanche,
  };

  /// Resolves the active theme for any [NetworkEntry]
  static AppChainTheme forNetwork(NetworkEntry? entry) {
    if (entry == null) return bsc; // Default to BSC per Figma primary showcase

    if (entry is SolanaNetworkEntry) return solana;
    if (entry is TronNetworkEntry) return tron;
    if (entry is EvmNetworkEntry) {
      final chain = entry.chain;
      final chainId = chain.chainId;

      final preset = _evmPresetMap[chainId];
      if (preset != null) return preset;

      if (BlockchainCatalog.ethereumLayer2BadgeChainIds.contains(chainId)) {
        return ethereumL2;
      }

      if (chain.isCustom) {
        return fromCustomChain(chain);
      }
    }

    return fomowlSignature;
  }

  /// Resolves the active theme for any network key string (e.g., 'evm:56', 'solana:mainnet')
  static AppChainTheme forNetworkKey(String? networkKey) {
    if (networkKey == null || networkKey.isEmpty) return bsc;

    final trimmed = networkKey.trim().toLowerCase();
    if (trimmed.startsWith('solana')) return solana;
    if (trimmed.startsWith('tron')) return tron;

    final chainId = NetworkKey.evmChainIdOf(trimmed);
    if (chainId != null) {
      final preset = _evmPresetMap[chainId];
      if (preset != null) return preset;
      if (BlockchainCatalog.ethereumLayer2BadgeChainIds.contains(chainId)) {
        return ethereumL2;
      }
    }

    return fomowlSignature;
  }

  /// Helper to get current chain theme from BuildContext
  static AppChainTheme of(BuildContext context) {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: true);
      return forNetworkKey(blockchain.activeNetworkKey);
    } catch (_) {
      return bsc;
    }
  }

}

/// Convenient extension on BuildContext
extension AppChainThemeContextExtension on BuildContext {
  AppChainTheme get chainTheme => AppChainTheme.of(this);
}
