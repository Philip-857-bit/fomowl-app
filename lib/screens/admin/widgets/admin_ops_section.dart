import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';

class AdminOpsSection extends StatelessWidget {
  final Map<String, dynamic>? ops;
  final List<dynamic> errorLogs;
  final int errorLogsPage;
  final int errorLogsTotal;
  final bool errorLogsHasNext;
  final bool loadingErrorLogs;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  const AdminOpsSection({
    super.key,
    required this.ops,
    required this.errorLogs,
    required this.errorLogsPage,
    required this.errorLogsTotal,
    required this.errorLogsHasNext,
    required this.loadingErrorLogs,
    this.onPreviousPage,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    final activity =
        (ops?['activity'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final errorSignals =
        (ops?['errorSignals'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final limits =
        (ops?['rateLimits'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final push =
        (ops?['push'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ops, Errors & Throughput',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Events: ${activity['estimatedEventsPerSecond'] ?? 0} / sec, ${activity['estimatedEventsPerMinute'] ?? 0} / min',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
          Text(
            'Feedback/min: ${activity['feedbackLastMinute'] ?? 0} | Notifications/min: ${activity['notificationsLastMinute'] ?? 0} | Tx/min: ${activity['transactionsLastMinute'] ?? 0}',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
          Text(
            'Configured limit: ${limits['configuredRequestsPerSecond'] ?? 0} rps (burst ${limits['configuredBurstSize'] ?? 0})',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Error signals (feedback, 24h): ${errorSignals['feedbackErrorSignals24h'] ?? 0}',
            style: GoogleFonts.outfit(color: Colors.orange, fontSize: 13),
          ),
          Text(
            'Server errors: ${errorSignals['serverErrorsLastMinute'] ?? 0}/min, ${errorSignals['serverErrors24h'] ?? 0}/24h',
            style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 13),
          ),
          Text(
            'FCM: enabled=${push['fcmEnabled'] ?? false}, configured=${push['fcmConfigured'] ?? false}, devices=${push['registeredDevices'] ?? 0}',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Text(
            'Server Error Audit',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (loadingErrorLogs)
            const LinearProgressIndicator(minHeight: 2)
          else if (errorLogs.isEmpty)
            Text(
              'No server errors recorded yet.',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
            )
          else
            ...errorLogs
                .take(8)
                .map(
                  (item) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['source'] ?? 'unknown'} • ${item['category'] ?? 'error'}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['message']?.toString() ?? '',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['createdAt']?.toString() ?? '',
                          style: GoogleFonts.outfit(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Page $errorLogsPage • ${errorLogs.length}/$errorLogsTotal',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: onPreviousPage,
                child: const Text('Prev'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onNextPage, child: const Text('Next')),
            ],
          ),
        ],
      ),
    );
  }
}
