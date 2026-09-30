import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chain.dart';

import '../models/network_entry.dart';
import '../services/blockchain/blockchain_catalog.dart';
import '../services/blockchain_service.dart';
import 'theme_controller.dart';

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
      colors: [Color(0xFF1E284A), Color(0xFF111728), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFF627EEA), Color(0x00000000), Color(0xFF627EEA)],
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
      colors: [Color(0x66F7B617), Color(0x66000000), Color(0x66FFBD1B)],
      stops: [0.0, 0.77, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFFF3BA2F), Color(0x00000000), Color(0xFFF3BA2F)],
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
      colors: [Color(0x739945FF), Color(0x4014F195), Color(0xFF0A0A0A)],
      stops: [0.0, 0.6, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFF9945FF), Color(0x00000000), Color(0xFF14F195)],
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
      colors: [Color(0xFF0D2566), Color(0xFF09163D), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFF0052FF), Color(0x00000000), Color(0xFF0052FF)],
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
      colors: [Color(0xFF3B080A), Color(0xFF1F0607), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFFFF060A), Color(0x00000000), Color(0xFFFF060A)],
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

  /// FOMOwl Signature Brand Default Theme — Figma #321:2990
  static const AppChainTheme fomowlSignature = AppChainTheme(
    id: 'fomowl_signature',
    displayName: 'FOMOwl Classic',
    primaryColor: Color(0xFFEA2A33),
    accentColor: Color(0xFFEA2A33),
    secondaryAccent: Color(0xFFD31C31),
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF1C1C1C), Color(0xFF161616), Color(0xFF0F0F0F)],
      stops: [0.0, 0.6, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFFEA2A33), Color(0x00000000), Color(0xFFD31C31)],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFFEA2A33), Color(0xFFD31C31)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFFEA2A33),
    badgeColor: Color(0xFFD31C31),
    surfaceOverlay: Color(0x22EA2A33),
    activeIndicatorColor: Color(0xFFD31C31),
  );

  /// Arc Theme — Chain ID: 5042
  static const AppChainTheme arc = AppChainTheme(
    id: 'arc',
    displayName: 'Arc',
    primaryColor: Color(0xFF0066FF),
    accentColor: Color(0xFF00C0FF),
    secondaryAccent: Color(0xFF60A5FA),
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF0D2149), Color(0xFF081530), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFF0066FF), Color(0x00000000), Color(0xFF00C0FF)],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFF0066FF), Color(0xFF0044B3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFF0066FF),
    badgeColor: Color(0xFF0066FF),
    surfaceOverlay: Color(0x220066FF),
    activeIndicatorColor: Color(0xFF0066FF),
  );

  /// HyperEVM Theme — Chain ID: 999
  static const AppChainTheme hyperevm = AppChainTheme(
    id: 'hyperevm',
    displayName: 'HyperEVM',
    primaryColor: Color(0xFF1BE5B5),
    accentColor: Color(0xFF1BE5B5),
    secondaryAccent: Color(0xFF4FFAD0),
    balanceCardGradient: LinearGradient(
      colors: [Color(0xFF072E26), Color(0xFF041A15), Color(0xFF0A0A0A)],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    balanceCardBorderGradient: LinearGradient(
      colors: [Color(0xFF1BE5B5), Color(0x00000000), Color(0xFF1BE5B5)],
      stops: [0.0, 0.67, 1.0],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    buttonGradient: LinearGradient(
      colors: [Color(0xFF1BE5B5), Color(0xFF0DA380)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassTint: Color(0xFF1BE5B5),
    badgeColor: Color(0xFF1BE5B5),
    surfaceOverlay: Color(0x221BE5B5),
    activeIndicatorColor: Color(0xFF1BE5B5),
  );

  // --------------------------------------------------------------------------
  // Tier 4: Dynamic & Custom Chain Adaptive Theme Generator
  // --------------------------------------------------------------------------

  /// Dynamically computes a cohesive adaptive theme for any EVM chain
  static AppChainTheme fromChainId(int chainId, {String? displayName}) {
    final seed = chainId.abs();
    final hue = (seed * 137.5) % 360; // Golden angle color distribution
    final primary = HSLColor.fromAHSL(1.0, hue, 0.78, 0.52).toColor();
    final accent = HSLColor.fromAHSL(1.0, hue, 0.85, 0.58).toColor();
    final darkBase = HSLColor.fromAHSL(1.0, hue, 0.65, 0.12).toColor();

    return AppChainTheme(
      id: 'chain_$chainId',
      displayName: displayName ?? 'Chain $chainId',
      primaryColor: primary,
      accentColor: accent,
      balanceCardGradient: LinearGradient(
        colors: [darkBase, const Color(0xFF0A0A0A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      balanceCardBorderGradient: LinearGradient(
        colors: [accent, const Color(0x00000000), accent],
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

  /// Dynamically computes a cohesive theme for any user-added custom EVM chain
  static AppChainTheme fromCustomChain(EvmChain chain) {
    return fromChainId(chain.chainId, displayName: chain.name);
  }

  /// Helper to create a consistent, branded theme for any ecosystem chain
  static AppChainTheme createBrandTheme({
    required String id,
    required String displayName,
    required Color primary,
    required Color accent,
    Color? secondary,
    required Color darkBase,
  }) {
    return AppChainTheme(
      id: id,
      displayName: displayName,
      primaryColor: primary,
      accentColor: accent,
      secondaryAccent: secondary ?? accent,
      balanceCardGradient: LinearGradient(
        colors: [darkBase, const Color(0xFF0A0A0A)],
        stops: const [0.0, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      balanceCardBorderGradient: LinearGradient(
        colors: [accent, const Color(0x00000000), accent],
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
    // Hero & Curated Major Themes
    1: ethereum,
    56: bsc,
    8453: base,
    137: polygon,
    42161: arbitrum,
    10: optimism,
    43114: avalanche,
    5042: arc,
    999: hyperevm,

    // Dedicated Ecosystem Brand Themes
    324: createBrandTheme(
      id: 'zksync',
      displayName: 'ZKsync Era',
      primary: const Color(0xFF3B68FF),
      accent: const Color(0xFF5C82FF),
      darkBase: const Color(0xFF0D183B),
    ),
    250: createBrandTheme(
      id: 'fantom',
      displayName: 'Fantom',
      primary: const Color(0xFF1969FF),
      accent: const Color(0xFF387BFF),
      darkBase: const Color(0xFF061433),
    ),
    100: createBrandTheme(
      id: 'gnosis',
      displayName: 'Gnosis',
      primary: const Color(0xFF00A389),
      accent: const Color(0xFF00D1A7),
      darkBase: const Color(0xFF03241E),
    ),
    1313161554: createBrandTheme(
      id: 'aurora',
      displayName: 'Aurora',
      primary: const Color(0xFF70D44B),
      accent: const Color(0xFF85E65E),
      darkBase: const Color(0xFF122E09),
    ),
    4663: createBrandTheme(
      id: 'robinhood',
      displayName: 'Robinhood Chain',
      primary: const Color(0xFF00C805),
      accent: const Color(0xFF1FF224),
      darkBase: const Color(0xFF032404),
    ),
    130: createBrandTheme(
      id: 'unichain',
      displayName: 'Unichain',
      primary: const Color(0xFFFF007A),
      accent: const Color(0xFFFF3399),
      darkBase: const Color(0xFF36001A),
    ),
    143: createBrandTheme(
      id: 'monad',
      displayName: 'Monad',
      primary: const Color(0xFF836EF9),
      accent: const Color(0xFFA08EFF),
      darkBase: const Color(0xFF191238),
    ),
    146: createBrandTheme(
      id: 'sonic',
      displayName: 'Sonic',
      primary: const Color(0xFFFF8D3B),
      accent: const Color(0xFFFFA566),
      darkBase: const Color(0xFF361904),
    ),
    480: createBrandTheme(
      id: 'worldchain',
      displayName: 'World Chain',
      primary: const Color(0xFF3B82F6),
      accent: const Color(0xFF60A5FA),
      darkBase: const Color(0xFF0B1B38),
    ),
    2741: createBrandTheme(
      id: 'abstract',
      displayName: 'Abstract',
      primary: const Color(0xFF00E599),
      accent: const Color(0xFF33FFB5),
      darkBase: const Color(0xFF022B1D),
    ),
    5000: createBrandTheme(
      id: 'mantle',
      displayName: 'Mantle',
      primary: const Color(0xFF00D692),
      accent: const Color(0xFF26E6A7),
      darkBase: const Color(0xFF03261A),
    ),
    33139: createBrandTheme(
      id: 'apechain',
      displayName: 'ApeChain',
      primary: const Color(0xFF0054F5),
      accent: const Color(0xFF2E75FF),
      darkBase: const Color(0xFF05153D),
    ),
    34443: createBrandTheme(
      id: 'mode',
      displayName: 'Mode',
      primary: const Color(0xFFDFFE00),
      accent: const Color(0xFFE8FF33),
      darkBase: const Color(0xFF2B3000),
    ),
    57073: createBrandTheme(
      id: 'ink',
      displayName: 'Ink',
      primary: const Color(0xFF8B3DFF),
      accent: const Color(0xFFA666FF),
      darkBase: const Color(0xFF1B073B),
    ),
    59144: createBrandTheme(
      id: 'linea',
      displayName: 'Linea',
      primary: const Color(0xFF61DFFF),
      accent: const Color(0xFF8AE8FF),
      darkBase: const Color(0xFF082630),
    ),
    80094: createBrandTheme(
      id: 'berachain',
      displayName: 'Berachain',
      primary: const Color(0xFFE0702B),
      accent: const Color(0xFFF59E0B),
      darkBase: const Color(0xFF331604),
    ),
    81457: createBrandTheme(
      id: 'blast',
      displayName: 'Blast',
      primary: const Color(0xFFFCFC03),
      accent: const Color(0xFFFFF733),
      darkBase: const Color(0xFF302F00),
    ),
    9745: createBrandTheme(
      id: 'plasma',
      displayName: 'Plasma',
      primary: const Color(0xFFA855F7),
      accent: const Color(0xFFC084FC),
      darkBase: const Color(0xFF240938),
    ),
    1135: createBrandTheme(
      id: 'lisk',
      displayName: 'Lisk',
      primary: const Color(0xFF005AFF),
      accent: const Color(0xFF337CFF),
      darkBase: const Color(0xFF06153B),
    ),
    42220: createBrandTheme(
      id: 'celo',
      displayName: 'Celo',
      primary: const Color(0xFF35D07F),
      accent: const Color(0xFFFCFF52),
      darkBase: const Color(0xFF0B2917),
    ),
    25: createBrandTheme(
      id: 'cronos',
      displayName: 'Cronos',
      primary: const Color(0xFF0B4596),
      accent: const Color(0xFF1199FA),
      darkBase: const Color(0xFF041838),
    ),
    169: createBrandTheme(
      id: 'manta',
      displayName: 'Manta Pacific',
      primary: const Color(0xFF22C4FF),
      accent: const Color(0xFFE46AFF),
      darkBase: const Color(0xFF082033),
    ),
    1088: createBrandTheme(
      id: 'metis',
      displayName: 'Metis',
      primary: const Color(0xFF00D2C4),
      accent: const Color(0xFF29F0E2),
      darkBase: const Color(0xFF032623),
    ),
    1329: createBrandTheme(
      id: 'sei',
      displayName: 'Sei',
      primary: const Color(0xFFB81D24),
      accent: const Color(0xFFE02B33),
      darkBase: const Color(0xFF290507),
    ),
    98866: createBrandTheme(
      id: 'plume',
      displayName: 'Plume',
      primary: const Color(0xFFFF5722),
      accent: const Color(0xFFFF7A4D),
      darkBase: const Color(0xFF331005),
    ),
    534352: createBrandTheme(
      id: 'scroll',
      displayName: 'Scroll',
      primary: const Color(0xFFF69742),
      accent: const Color(0xFFFFB570),
      darkBase: const Color(0xFF2E1705),
    ),
  };

  /// Resolves the active theme for any [NetworkEntry]
  static AppChainTheme forNetwork(NetworkEntry? entry) {
    if (entry == null) {
      return fomowlSignature; // Original FOMOwl app theme fallback
    }

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

      return fromChainId(chainId, displayName: chain.name);
    }

    return fomowlSignature;
  }

  /// Resolves the active theme for any network key string (e.g., 'evm:56', 'solana:mainnet')
  static AppChainTheme forNetworkKey(String? networkKey) {
    if (networkKey == null || networkKey.isEmpty) {
      return fomowlSignature; // Original FOMOwl app theme fallback
    }

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
      final chain = BlockchainCatalog.findChain(chainId);
      return fromChainId(chainId, displayName: chain?.name);
    }

    return fomowlSignature;
  }

  /// Helper to get current chain theme from BuildContext, respecting ThemeController (Classic vs. Adaptive).
  static AppChainTheme of(BuildContext context) {
    try {
      final themeController = Provider.of<ThemeController>(
        context,
        listen: true,
      );
      if (themeController.isClassic) {
        return fomowlSignature;
      }
    } catch (_) {}

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: true);
      return forNetworkKey(blockchain.activeNetworkKey);
    } catch (_) {
      return fomowlSignature;
    }
  }
}

/// Convenient extension on BuildContext
extension AppChainThemeContextExtension on BuildContext {
  AppChainTheme get chainTheme => AppChainTheme.of(this);
}
