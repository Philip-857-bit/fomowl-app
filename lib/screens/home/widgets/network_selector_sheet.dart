import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../models/chain.dart';

class NetworkSelectorSheet extends StatelessWidget {
  final List<EvmChain> chains;
  final int activeChainId;
  final ValueChanged<EvmChain> onSelect;

  const NetworkSelectorSheet({
    super.key,
    required this.chains,
    required this.activeChainId,
    required this.onSelect,
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
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        ...chains.map((chain) {
          final isActive = chain.chainId == activeChainId;
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isActive ? AppColors.accentRed.withValues(alpha: 0.2) : Colors.white12,
              child: Text(
                chain.symbol.isEmpty ? '?' : chain.symbol.substring(0, chain.symbol.length > 3 ? 3 : chain.symbol.length),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.accentRed : Colors.white,
                ),
              ),
            ),
            title: Text(chain.name, style: GoogleFonts.outfit(color: Colors.white)),
            subtitle: Text('Chain ID: ${chain.chainId}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54)),
            trailing: isActive ? const Icon(Icons.check_circle, color: AppColors.accentRed) : null,
            onTap: () => onSelect(chain),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}
