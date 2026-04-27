import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chain.dart';
import '../../../models/network_entry.dart';

class NetworkSelectorSheet extends StatelessWidget {
  final List<NetworkEntry> entries;
  final String activeNetworkKey;
  final ValueChanged<NetworkEntry> onSelect;
  final VoidCallback? onAddCustomNetwork;

  const NetworkSelectorSheet({
    super.key,
    required this.entries,
    required this.activeNetworkKey,
    required this.onSelect,
    this.onAddCustomNetwork,
  });

  /// Backwards-compatible constructor for callers that still pass EVM chains.
  factory NetworkSelectorSheet.fromEvmChains({
    Key? key,
    required List<EvmChain> chains,
    required int activeChainId,
    required ValueChanged<EvmChain> onSelect,
    VoidCallback? onAddCustomNetwork,
  }) {
    return NetworkSelectorSheet(
      key: key,
      entries: chains.map(EvmNetworkEntry.new).toList(),
      activeNetworkKey: NetworkKey.evm(activeChainId),
      onSelect: (entry) {
        if (entry case EvmNetworkEntry(:final chain)) {
          onSelect(chain);
        }
      },
      onAddCustomNetwork: onAddCustomNetwork,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      shrinkWrap: true,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            l.selectNetwork,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map((entry) {
          final isActive = entry.networkKey == activeNetworkKey;
          final accentColor = _accentFor(entry.family);
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isActive
                  ? accentColor.withValues(alpha: 0.2)
                  : Colors.white12,
              child: ClipOval(
                child: entry.logoUrl != null && entry.logoUrl!.isNotEmpty
                    ? Image.network(
                        entry.logoUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _fallbackSymbol(entry, isActive, accentColor),
                      )
                    : _fallbackSymbol(entry, isActive, accentColor),
              ),
            ),
            title: Text(
              entry.name,
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            subtitle: Text(
              _subtitle(entry),
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
            ),
            trailing: isActive
                ? Icon(Icons.check_circle, color: accentColor)
                : null,
            onTap: () => onSelect(entry),
          );
        }),
        if (onAddCustomNetwork != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ElevatedButton.icon(
              onPressed: onAddCustomNetwork,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: Text(
                l.addCustomNetwork,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Color _accentFor(ChainFamily family) => switch (family) {
    ChainFamily.evm => AppColors.accentRed,
    ChainFamily.solana => const Color(0xFF9945FF),
    ChainFamily.tron => const Color(0xFFEF0027),
  };

  String _subtitle(NetworkEntry entry) => switch (entry) {
    EvmNetworkEntry(:final chain) => 'Chain ID: ${chain.chainId}',
    SolanaNetworkEntry() => 'Solana · SPL tokens',
    TronNetworkEntry() => 'Tron · TRC-20 tokens',
  };

  Widget _fallbackSymbol(NetworkEntry entry, bool isActive, Color accent) {
    final sym = entry.symbol;
    return Text(
      sym.isEmpty ? '?' : sym.substring(0, sym.length > 3 ? 3 : sym.length),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: isActive ? accent : Colors.white,
      ),
    );
  }
}
