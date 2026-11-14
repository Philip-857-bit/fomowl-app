import 'package:flutter/material.dart';

import 'burst_share.dart';
import 'burst_theme.dart';

/// Shared Figma-aligned Burst creation success body (Figma node 5888:9424).
class BurstCreatedSuccessBody extends StatelessWidget {
  const BurstCreatedSuccessBody({
    super.key,
    required this.joinCode,
    required this.onViewBurst,
  });

  final String joinCode;
  final VoidCallback onViewBurst;

  @override
  Widget build(BuildContext context) {
    final accent = burstAccent(context);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.85,
                  colors: [
                    accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.6),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Color(0xFF050505),
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Burst Created!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your Owllet Burst is live and ready for guests.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              BurstInviteCodeCard(code: joinCode),
              const SizedBox(height: 8),
              const Text(
                'INVITE CODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0x99B9CBBC),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (shareContext) => Container(
                  decoration: BoxDecoration(
                    boxShadow: burstActionShadow(context),
                  ),
                  child: FilledButton(
                    onPressed: () => shareBurstCode(shareContext, joinCode),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Share code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onViewBurst,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF201F1F),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'View My Burst',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Standalone celebration route pushed only after the on-chain creation
/// transaction succeeds (matching Figma node 5888:9424).
class BurstCreatedSuccessScreen extends StatelessWidget {
  const BurstCreatedSuccessScreen({
    super.key,
    required this.campaign,
    required this.joinCode,
    required this.nativeSymbol,
    this.chainName,
    this.onViewBurst,
  });

  final Map<String, dynamic> campaign;
  final String joinCode;
  final String nativeSymbol;
  final String? chainName;
  final VoidCallback? onViewBurst;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const BurstHeader(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BurstCreatedSuccessBody(
          joinCode: joinCode,
          onViewBurst: onViewBurst ?? () => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}
