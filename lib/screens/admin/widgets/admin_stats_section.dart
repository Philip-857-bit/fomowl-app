import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'admin_stat_card.dart';

class AdminStatsSection extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? ops;

  const AdminStatsSection({Key? key, required this.stats, required this.ops})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = stats ?? const <String, dynamic>{};
    final activity =
        (ops?['activity'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.adminAppPerformance,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AdminStatCard(
              label: l.adminRegistryTokens,
              value: (s['token_registry_size'])?.toString() ?? '0',
              icon: Icons.local_offer_outlined,
            ),
            const SizedBox(width: 12),
            AdminStatCard(
              label: l.adminTotalUsers,
              value: (s['totalUsers'] ?? s['users_count'])?.toString() ?? '0',
              icon: Icons.person_add,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AdminStatCard(
              label: l.adminTransactions,
              value:
                  (s['totalTransactions'] ?? s['transactions_24h'])
                      ?.toString() ??
                  '0',
              icon: Icons.swap_horiz,
            ),
            const SizedBox(width: 12),
            AdminStatCard(
              label: l.adminMaintainers,
              value: (s['maintainers_count'])?.toString() ?? '0',
              icon: Icons.verified_user,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AdminStatCard(
              label: 'RPS (est)',
              value: ((activity['estimatedEventsPerSecond'] ?? 0.0) as num)
                  .toStringAsFixed(2),
              icon: Icons.speed,
            ),
            const SizedBox(width: 12),
            AdminStatCard(
              label: 'RPM (est)',
              value: (activity['estimatedEventsPerMinute'] ?? 0).toString(),
              icon: Icons.timer,
            ),
          ],
        ),
      ],
    );
  }
}
