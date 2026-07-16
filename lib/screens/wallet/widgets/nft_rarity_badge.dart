import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NftRarityBadge extends StatelessWidget {
  const NftRarityBadge({
    super.key,
    required this.label,
    this.rank,
    this.compact = true,
  });

  final String label;
  final int? rank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(label);
    final visibleLabel = compact || rank == null
        ? label.trim()
        : '${label.trim()} · Rank #$rank';

    return Semantics(
      label: rank == null
          ? 'Rarity: ${label.trim()}'
          : 'Rarity: ${label.trim()}, rank $rank',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 11,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xE619191D),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x52000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: compact ? 11 : 14,
              color: color,
            ),
            SizedBox(width: compact ? 4 : 6),
            Flexible(
              child: Text(
                visibleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color colorFor(String rarity) {
    switch (rarity.trim().toLowerCase()) {
      case 'uncommon':
        return const Color(0xFF58D68D);
      case 'rare':
        return const Color(0xFF5DADE2);
      case 'epic':
        return const Color(0xFFAF7AC5);
      case 'legendary':
        return const Color(0xFFF5B942);
      case 'mythic':
      case 'mythical':
        return const Color(0xFFFF5C8A);
      case 'common':
        return const Color(0xFFB8BEC9);
      default:
        return const Color(0xFF67E8F9);
    }
  }
}
