import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';

// Shared presentation only; each chain supplies its own verified facts.
class HistoryDetailSection extends StatelessWidget {
  const HistoryDetailSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class HistoryDetailRow extends StatelessWidget {
  const HistoryDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: SelectableText(
              value,
              style:
                  (monospace ? GoogleFonts.robotoMono() : GoogleFonts.outfit())
                      .copyWith(
                        fontSize: monospace ? 12.5 : 13.5,
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? Colors.white,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryInfoBanner extends StatelessWidget {
  const HistoryInfoBanner({
    super.key,
    required this.message,
    this.loading = false,
  });

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentRed,
              ),
            )
          else
            Icon(
              Icons.receipt_long_rounded,
              color: Colors.white.withValues(alpha: 0.75),
              size: 18,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
