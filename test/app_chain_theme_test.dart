import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/models/chain.dart';

import 'package:fomowl_wallet/models/network_entry.dart';
import 'package:fomowl_wallet/services/blockchain/blockchain_catalog.dart';
import 'package:fomowl_wallet/services/blockchain/solana_catalog.dart';
import 'package:fomowl_wallet/services/blockchain/tron_catalog.dart';
import 'package:fomowl_wallet/theme/app_chain_theme.dart';

void main() {
  group('AppChainTheme Resolution Tests', () {
    test('Ethereum (Hero 1) resolves correct colors and theme properties', () {
      final ethChain = const EvmChain(
        chainId: 1,
        name: 'Ethereum',
        symbol: 'ETH',
        rpcUrl: 'https://rpc.ankr.com/eth',
      );
      final ethEntry = EvmNetworkEntry(ethChain);
      final theme = AppChainTheme.forNetwork(ethEntry);

      expect(theme.accentColor, const Color(0xFF627EEA));
      expect(theme.balanceCardGradient.colors.first, const Color(0xFF1E284A));
    });

    test('BNB Smart Chain (Hero 2) resolves correct gold accent', () {
      final bscChain = const EvmChain(
        chainId: 56,
        name: 'BNB Smart Chain',
        symbol: 'BNB',
        rpcUrl: 'https://rpc.ankr.com/bsc',
      );
      final bscEntry = EvmNetworkEntry(bscChain);
      final theme = AppChainTheme.forNetwork(bscEntry);

      expect(theme.accentColor, const Color(0xFFF3BA2F));
      expect(theme.balanceCardGradient.colors.first, const Color(0x66F7B617));
    });

    test('Solana (Hero 3) resolves solana gradient & neon accent', () {
      final solEntry = SolanaNetworkEntry(SolanaCatalog.mainnet);
      final theme = AppChainTheme.forNetwork(solEntry);

      expect(theme.accentColor, const Color(0xFF14F195));
      expect(theme.balanceCardGradient.colors.first, const Color(0x739945FF));
    });

    test('Base (Hero 4) resolves Base blue theme', () {
      final baseChain = const EvmChain(
        chainId: 8453,
        name: 'Base',
        symbol: 'ETH',
        rpcUrl: 'https://mainnet.base.org',
      );
      final baseEntry = EvmNetworkEntry(baseChain);
      final theme = AppChainTheme.forNetwork(baseEntry);

      expect(theme.accentColor, const Color(0xFF0052FF));
      expect(theme.balanceCardGradient.colors.first, const Color(0xFF0D2566));
    });

    test('Tron (Hero 5) resolves Tron red theme', () {
      final tronEntry = TronNetworkEntry(TronCatalog.mainnet);
      final theme = AppChainTheme.forNetwork(tronEntry);

      expect(theme.accentColor, const Color(0xFFFF060A));
      expect(theme.balanceCardGradient.colors.first, const Color(0xFF3B080A));
    });

    test(
      'Built-in Preset chains (Polygon, Arbitrum, Optimism, Avalanche) resolve correctly',
      () {
        final polygonTheme = AppChainTheme.forNetworkKey('evm:137');
        expect(polygonTheme.accentColor, const Color(0xFF8247E5));

        final arbTheme = AppChainTheme.forNetworkKey('evm:42161');
        expect(arbTheme.accentColor, const Color(0xFF28A0F0));

        final opTheme = AppChainTheme.forNetworkKey('evm:10');
        expect(opTheme.accentColor, const Color(0xFFFF0420));

        final avaxTheme = AppChainTheme.forNetworkKey('evm:43114');
        expect(avaxTheme.accentColor, const Color(0xFFE84142));

        final arcTheme = AppChainTheme.forNetworkKey('evm:5042');
        expect(arcTheme.id, 'arc');
        expect(arcTheme.accentColor, const Color(0xFF00C0FF));

        final hyperEvmTheme = AppChainTheme.forNetworkKey('evm:999');
        expect(hyperEvmTheme.id, 'hyperevm');
        expect(hyperEvmTheme.accentColor, const Color(0xFF1BE5B5));
      },
    );

    test('Custom unconfigured EVM chain resolves deterministic fallback', () {
      final customChain = const EvmChain(
        chainId: 999999,
        name: 'My Custom Chain',
        symbol: 'MCC',
        rpcUrl: 'https://rpc.custom.org',
        isCustom: true,
      );
      final customEntry = EvmNetworkEntry(customChain);
      final theme = AppChainTheme.forNetwork(customEntry);

      expect(theme.accentColor, isNotNull);
      expect(theme.balanceCardGradient.colors.isNotEmpty, true);
      expect(theme.buttonGradient.colors.isNotEmpty, true);
    });

    test('Every built-in chain has a dedicated non-fallback theme', () {
      for (final chain in BlockchainCatalog.builtInChains) {
        final theme = AppChainTheme.forNetworkKey('evm:${chain.chainId}');
        expect(theme.id, isNot('fomowl_signature'),
            reason: '${chain.name} (${chain.chainId}) fell back to classic FOMOwl theme');
        expect(theme.accentColor, isNotNull);
        expect(theme.balanceCardGradient.colors.isNotEmpty, true);
        expect(theme.buttonGradient.colors.isNotEmpty, true);
      }
    });

    test('Unresolvable/null key defaults to FOMOwl fallback signature', () {
      final fallbackTheme = AppChainTheme.forNetworkKey(null);
      expect(fallbackTheme.accentColor, const Color(0xFFEA2A33));
      expect(fallbackTheme.secondaryAccent, const Color(0xFFD31C31));
      expect(fallbackTheme.activeIndicatorColor, const Color(0xFFD31C31));
      expect(
        fallbackTheme.balanceCardGradient.colors.first,
        const Color(0xFF1C1C1C),
      );
    });
  });
}
