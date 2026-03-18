import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';

class AdminOpsSection extends StatelessWidget {
  final Map<String, dynamic>? ops;

  const AdminOpsSection({Key? key, required this.ops}) : super(key: key);

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
            'FCM: enabled=${push['fcmEnabled'] ?? false}, configured=${push['fcmConfigured'] ?? false}, devices=${push['registeredDevices'] ?? 0}',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
