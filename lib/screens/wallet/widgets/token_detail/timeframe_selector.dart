import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimeframeSelector extends StatelessWidget {
  final List<String> timeframes;
  final String selected;
  final ValueChanged<String> onSelected;

  const TimeframeSelector({
    super.key,
    required this.timeframes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: timeframes.map((tf) {
        final isSelected = selected == tf;
        return GestureDetector(
          onTap: () => onSelected(tf),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              tf,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
