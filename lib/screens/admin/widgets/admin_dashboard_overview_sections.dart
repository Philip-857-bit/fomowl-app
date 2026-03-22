import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chain.dart';
import 'admin_dashboard_common.dart';

class AdminOverviewSection extends StatelessWidget {
  const AdminOverviewSection({
    super.key,
    required this.l10n,
    required this.activeChain,
    required this.health,
    required this.stats,
    required this.ops,
  });

  final AppLocalizations l10n;
  final EvmChain activeChain;
  final Map<String, dynamic>? health;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? ops;

  @override
  Widget build(BuildContext context) {
    final statsData = stats ?? const <String, dynamic>{};
    final opsData = ops ?? const <String, dynamic>{};
    final push = (opsData['push'] as Map<String, dynamic>?) ?? const {};
    final activity = (opsData['activity'] as Map<String, dynamic>?) ?? const {};
    final systemStatus = (health?['status'] ?? 'unknown').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeading(
          title: 'Operational overview',
          subtitle:
              'Live admin summary for ${activeChain.name}, backend health, notifications, and registry coverage.',
        ),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AdminStatusPill(
                    label:
                        '${l10n.adminSystemStatus}: ${systemStatus.toUpperCase()}',
                    color: systemStatus.toLowerCase() == 'healthy'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  AdminStatusPill(
                    label:
                        'DB latency ${(statsData['db_latency_ms'] ?? statsData['latency_ms'] ?? '--')} ms',
                    color: Colors.white70,
                  ),
                  AdminStatusPill(
                    label:
                        'FCM ${push['fcmConfigured'] == true ? 'configured' : 'not configured'}',
                    color: push['fcmConfigured'] == true
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  AdminMetricTile(
                    label: l10n.adminTotalUsers,
                    value: adminFormatCount(statsData['users_count']),
                    icon: Icons.people_alt_outlined,
                  ),
                  AdminMetricTile(
                    label: '${l10n.adminTransactions} (24h)',
                    value: adminFormatCount(statsData['transactions_24h']),
                    icon: Icons.swap_horiz_rounded,
                  ),
                  AdminMetricTile(
                    label: 'Notifications (24h)',
                    value: adminFormatCount(statsData['notifications_24h']),
                    icon: Icons.mark_email_unread_outlined,
                  ),
                  AdminMetricTile(
                    label: l10n.adminRegistryTokens,
                    value: adminFormatCount(statsData['token_registry_size']),
                    icon: Icons.token_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AdminInfoRow(
                label: 'Registered devices',
                value: adminFormatCount(
                  statsData['registered_devices'] ?? push['registeredDevices'],
                ),
              ),
              AdminInfoRow(
                label: 'Registered wallets',
                value: adminFormatCount(statsData['registered_wallets']),
              ),
              AdminInfoRow(
                label: 'Events per minute',
                value: adminFormatCount(activity['estimatedEventsPerMinute']),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminStatsSection extends StatelessWidget {
  const AdminStatsSection({
    super.key,
    required this.l10n,
    required this.stats,
    required this.ops,
  });

  final AppLocalizations l10n;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? ops;

  @override
  Widget build(BuildContext context) {
    final statsData = stats ?? const <String, dynamic>{};
    final opsData = ops ?? const <String, dynamic>{};
    final activity = (opsData['activity'] as Map<String, dynamic>?) ?? const {};
    final errors =
        (opsData['errorSignals'] as Map<String, dynamic>?) ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'Key metrics',
          subtitle:
              'Live counts for wallet adoption, transactions, notifications, feedback, and operational load.',
        ),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.34,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            AdminMetricTile(
              label: l10n.adminTotalUsers,
              value: adminFormatCount(statsData['users_count']),
              icon: Icons.person_outline_rounded,
            ),
            AdminMetricTile(
              label: 'Feedback (24h)',
              value: adminFormatCount(statsData['feedback_24h']),
              icon: Icons.feedback_outlined,
            ),
            AdminMetricTile(
              label: l10n.adminMaintainers,
              value: adminFormatCount(statsData['maintainers_count']),
              icon: Icons.verified_user_outlined,
            ),
            AdminMetricTile(
              label: 'Registered devices',
              value: adminFormatCount(statsData['registered_devices']),
              icon: Icons.phone_android_outlined,
            ),
            AdminMetricTile(
              label: 'Events / sec',
              value: adminFormatDecimal(activity['estimatedEventsPerSecond']),
              icon: Icons.speed_rounded,
            ),
            AdminMetricTile(
              label: 'Server errors (24h)',
              value: adminFormatCount(errors['serverErrors24h']),
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class AdminOpsSection extends StatelessWidget {
  const AdminOpsSection({
    super.key,
    required this.ops,
    required this.errorLogs,
    required this.errorLogsPage,
    required this.errorLogsTotal,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final Map<String, dynamic>? ops;
  final List<Map<String, dynamic>> errorLogs;
  final int errorLogsPage;
  final int errorLogsTotal;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    final opsData = ops ?? const <String, dynamic>{};
    final activity = (opsData['activity'] as Map<String, dynamic>?) ?? const {};
    final errorSignals =
        (opsData['errorSignals'] as Map<String, dynamic>?) ?? const {};
    final rateLimits =
        (opsData['rateLimits'] as Map<String, dynamic>?) ?? const {};
    final push = (opsData['push'] as Map<String, dynamic>?) ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'Ops and error audit',
          subtitle:
              'Current throughput, rate-limit posture, push readiness, and recent server-side errors.',
        ),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AdminInfoPill(
                    label: 'Events / min',
                    value: adminFormatCount(
                      activity['estimatedEventsPerMinute'],
                    ),
                  ),
                  AdminInfoPill(
                    label: 'Events / sec',
                    value: adminFormatDecimal(
                      activity['estimatedEventsPerSecond'],
                    ),
                  ),
                  AdminInfoPill(
                    label: 'Error signals (24h)',
                    value: adminFormatCount(
                      errorSignals['feedbackErrorSignals24h'],
                    ),
                  ),
                  AdminInfoPill(
                    label: 'Registered devices',
                    value: adminFormatCount(push['registeredDevices']),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AdminInfoRow(
                label: 'Configured rate limit',
                value:
                    '${adminFormatCount(rateLimits['configuredRequestsPerSecond'])} rps - burst ${adminFormatCount(rateLimits['configuredBurstSize'])}',
              ),
              AdminInfoRow(
                label: 'Server errors last minute',
                value: adminFormatCount(errorSignals['serverErrorsLastMinute']),
              ),
              AdminInfoRow(
                label: 'Broadcast mode',
                value: (push['broadcastMode'] ?? '--').toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Server error audit',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Page $errorLogsPage - ${errorLogs.length} of $errorLogsTotal',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              if (errorLogs.isEmpty)
                const Text(
                  'No server errors recorded yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...errorLogs.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${item['source'] ?? 'unknown'} - ${item['message'] ?? ''}',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onPreviousPage,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Previous'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onNextPage,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
