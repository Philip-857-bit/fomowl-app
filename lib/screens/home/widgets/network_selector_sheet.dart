import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chain.dart';
import '../../../models/network_entry.dart';
import '../../../theme/app_chain_theme.dart';
import '../../../widgets/chain_logo_image.dart';

class NetworkSelectorSheet extends StatefulWidget {
  final List<NetworkEntry> entries;
  final String activeNetworkKey;
  final ValueChanged<NetworkEntry> onSelect;
  final VoidCallback? onAddCustomNetwork;

  /// Invoked when the user chooses to edit a user-added (custom) EVM network.
  final ValueChanged<EvmChain>? onEditCustom;

  /// Invoked when the user chooses to delete a user-added (custom) EVM network.
  final ValueChanged<EvmChain>? onDeleteCustom;

  const NetworkSelectorSheet({
    super.key,
    required this.entries,
    required this.activeNetworkKey,
    required this.onSelect,
    this.onAddCustomNetwork,
    this.onEditCustom,
    this.onDeleteCustom,
  });

  /// Backwards-compatible constructor for callers that still pass EVM chains.
  factory NetworkSelectorSheet.fromEvmChains({
    Key? key,
    required List<EvmChain> chains,
    required int activeChainId,
    required ValueChanged<EvmChain> onSelect,
    VoidCallback? onAddCustomNetwork,
    ValueChanged<EvmChain>? onEditCustom,
    ValueChanged<EvmChain>? onDeleteCustom,
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
      onEditCustom: onEditCustom,
      onDeleteCustom: onDeleteCustom,
    );
  }

  @override
  State<NetworkSelectorSheet> createState() => _NetworkSelectorSheetState();
}

class _NetworkSelectorSheetState extends State<NetworkSelectorSheet> {
  String _searchQuery = '';

  List<NetworkEntry> get _visibleEntries {
    final indexedEntries = widget.entries.asMap().entries.toList();

    // Keep the existing network order, but promote Bitcoin mainnet to the
    // first position and Ethereum immediately after it.
    indexedEntries.sort((a, b) {
      final aPriority = _networkPriority(a.value);
      final bPriority = _networkPriority(b.value);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      return a.key.compareTo(b.key);
    });

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return indexedEntries.map((item) => item.value).toList();
    }

    return indexedEntries
        .map((item) => item.value)
        .where((entry) => _matchesSearch(entry, query))
        .toList();
  }

  int _networkPriority(NetworkEntry entry) {
    if (entry is BitcoinNetworkEntry && entry.chain.isMainnet) {
      return 0;
    }
    if (entry is EvmNetworkEntry && entry.chain.chainId == 1) {
      return 1;
    }
    return 2;
  }

  bool _matchesSearch(NetworkEntry entry, String query) {
    final searchableValues = <String>[
      entry.name,
      _displayName(entry),
      entry.symbol,
      entry.identitySymbol,
      entry.networkKey,
      _subtitle(entry),
      if (entry is EvmNetworkEntry) entry.chain.chainId.toString(),
    ];

    return searchableValues.any(
      (value) => value.toLowerCase().contains(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = context.chainTheme;
    final visibleEntries = _visibleEntries;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020202),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Center(
              child: Container(
                width: 73,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C6C6D),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                l.selectNetwork,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('network-search-field'),
                onChanged: (value) => setState(() => _searchQuery = value),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                cursorColor: theme.accentColor,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search networks',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white54,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF101010),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.accentColor.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (visibleEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Center(
                  child: Text(
                    'No networks found',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8894A0),
                    ),
                  ),
                ),
              )
            else
              ...visibleEntries.asMap().entries.map((item) {
                final index = item.key;
                final entry = item.value;
                final isActive = entry.networkKey == widget.activeNetworkKey;
                final entryTheme = AppChainTheme.forNetwork(entry);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    InkWell(
                      onTap: () => widget.onSelect(entry),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF161616),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? entryTheme.accentColor.withValues(
                                          alpha: 0.5,
                                        )
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ChainLogoImage(
                                  chainId: entry is EvmNetworkEntry
                                      ? entry.chain.chainId
                                      : null,
                                  logoUrl: entry.logoUrl,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.contain,
                                  fallback: _fallbackSymbol(
                                    entry,
                                    isActive,
                                    entryTheme.accentColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _displayName(entry),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _subtitle(entry),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF8894A0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildTrailing(
                              entry,
                              isActive,
                              entryTheme.accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            if (widget.onAddCustomNetwork != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: widget.onAddCustomNetwork,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: Text(
                    l.addCustomNetwork,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _displayName(NetworkEntry entry) {
    final raw = entry.name;
    if (raw.toLowerCase().contains('chain')) return raw;
    return '$raw Chain';
  }

  /// Trailing widget: an active check, plus an edit/delete menu for custom
  /// (user-added) EVM networks when the relevant callbacks are provided.
  Widget _buildTrailing(NetworkEntry entry, bool isActive, Color accentColor) {
    final isCustomEvm =
        entry is EvmNetworkEntry &&
        entry.chain.isCustom &&
        (widget.onEditCustom != null || widget.onDeleteCustom != null);

    final activeIcon = isActive
        ? Icon(Icons.check_circle_rounded, color: accentColor, size: 20)
        : const SizedBox.shrink();

    if (!isCustomEvm) return activeIcon;

    final chain = entry.chain;
    final menu = PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
      color: AppColors.cardDark,
      onSelected: (value) {
        if (value == 'edit') {
          widget.onEditCustom?.call(chain);
        } else if (value == 'delete') {
          widget.onDeleteCustom?.call(chain);
        }
      },
      itemBuilder: (context) => [
        if (widget.onEditCustom != null)
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (widget.onDeleteCustom != null)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );

    if (!isActive) return menu;
    return Row(mainAxisSize: MainAxisSize.min, children: [activeIcon, menu]);
  }

  String _subtitle(NetworkEntry entry) => switch (entry) {
    BitcoinNetworkEntry(:final chain) =>
      chain.isMainnet ? 'Bitcoin · BTC' : 'Bitcoin Testnet4 · BTC',
    EvmNetworkEntry(:final chain) => 'Chain ID: ${chain.chainId}',
    SolanaNetworkEntry() => 'Solana · SPL tokens',
    TronNetworkEntry() => 'Tron · TRC-20 tokens',
  };

  Widget _fallbackSymbol(NetworkEntry entry, bool isActive, Color accent) {
    final sym = entry.symbol;
    return Text(
      sym.isEmpty ? '?' : sym.substring(0, sym.length > 3 ? 3 : sym.length),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isActive ? accent : Colors.white,
      ),
    );
  }
}
