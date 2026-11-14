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
    final tall = MediaQuery.sizeOf(context).height >= 700;
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
              SizedBox(height: tall ? 52 : 4),
              Center(
                child: Container(
                  width: tall ? 105 : 80,
                  height: tall ? 105 : 80,
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
                  child: Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: burstOnAccent(context),
                      size: tall ? 44 : 36,
                    ),
                  ),
                ),
              ),
              SizedBox(height: tall ? 44 : 12),
              const Text(
                'Burst Created!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE5E2E1),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.75,
                ),
              ),
              SizedBox(height: tall ? 22 : 6),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 245),
                  child: const Text(
                    'Your Owllet Burst is live and ready for guests.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xCCB9CBBC),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: tall ? 38 : 16),
              BurstInviteCodeCard(code: joinCode),
              SizedBox(height: tall ? 12 : 8),
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
              SizedBox(height: tall ? 84 : 16),
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
                      foregroundColor: burstOnAccent(context),
                      minimumSize: Size.fromHeight(tall ? 56 : 48),
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
              SizedBox(height: tall ? 16 : 10),
              OutlinedButton(
                onPressed: onViewBurst,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(tall ? 56 : 48),
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
