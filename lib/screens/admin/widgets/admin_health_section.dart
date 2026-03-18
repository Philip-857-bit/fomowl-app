import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class AdminHealthSection extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final int? activeChainId;
  final String? adminWalletAddress;
  final String backendBaseUrl;
  final String? lastError;

  const AdminHealthSection({
    super.key,
    required this.stats,
    required this.activeChainId,
    required this.adminWalletAddress,
    required this.backendBaseUrl,
    this.lastError,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = (stats?['health'] ?? stats?['status'] ?? 'unknown')
        .toString();
    final latency = (stats?['latencyMs'] ?? stats?['latency_ms'] ?? '??')
        .toString();
    final isHealthy = status.toLowerCase() == 'healthy';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.warning,
            color: isHealthy ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.adminSystemStatus}: ${status.toUpperCase()}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${l.adminBackendLatency}: ${latency}ms',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chain: ${activeChainId ?? '--'} | Wallet: ${adminWalletAddress ?? '--'}',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Backend: $backendBaseUrl',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                if (lastError != null && lastError!.isNotEmpty)
                  Text(
                    lastError!,
                    style: GoogleFonts.outfit(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
