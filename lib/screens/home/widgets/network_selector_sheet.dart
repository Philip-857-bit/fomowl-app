import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../models/chain.dart';

class NetworkSelectorSheet extends StatelessWidget {
  final List<EvmChain> chains;
  final int activeChainId;
  final ValueChanged<EvmChain> onSelect;
  final VoidCallback? onAddCustomNetwork;

  const NetworkSelectorSheet({
    super.key,
    required this.chains,
    required this.activeChainId,
    required this.onSelect,
    this.onAddCustomNetwork,
  });

  @override
  Widget build(BuildContext context) {
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
            'Select Network',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...chains.map((chain) {
          final isActive = chain.chainId == activeChainId;
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isActive
                  ? AppColors.accentRed.withValues(alpha: 0.2)
                  : Colors.white12,
              child: ClipOval(
                child: chain.logoUrl != null && chain.logoUrl!.isNotEmpty
                    ? Image.network(
                        chain.logoUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _fallbackSymbol(chain, isActive),
                      )
                    : _fallbackSymbol(chain, isActive),
              ),
            ),
            title: Text(
              chain.name,
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            subtitle: Text(
              'Chain ID: ${chain.chainId}',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
            ),
            trailing: isActive
                ? const Icon(Icons.check_circle, color: AppColors.accentRed)
                : null,
            onTap: () => onSelect(chain),
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
                'Add Custom Network',
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

  Widget _fallbackSymbol(EvmChain chain, bool isActive) {
    return Text(
      chain.symbol.isEmpty
          ? '?'
          : chain.symbol.substring(
              0,
              chain.symbol.length > 3 ? 3 : chain.symbol.length,
            ),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: isActive ? AppColors.accentRed : Colors.white,
      ),
    );
  }
}
