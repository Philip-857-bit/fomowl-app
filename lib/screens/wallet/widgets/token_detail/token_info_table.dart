import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class TokenInfoRowData {
  final String label;
  final String value;
  final Widget? trailing;

  const TokenInfoRowData({
    required this.label,
    required this.value,
    this.trailing,
  });
}

class TokenInfoTable extends StatelessWidget {
  final List<TokenInfoRowData> rows;

  const TokenInfoTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOKEN INFO',
          style: GoogleFonts.outfit(
            fontSize: 12,
            letterSpacing: 1,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                _TokenInfoRow(data: rows[i]),
                if (i != rows.length - 1)
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TokenInfoRow extends StatelessWidget {
  final TokenInfoRowData data;

  const _TokenInfoRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data.label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            data.value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (data.trailing != null) ...[
            const SizedBox(width: 8),
            data.trailing!,
          ],
        ],
      ),
    );
  }
}
