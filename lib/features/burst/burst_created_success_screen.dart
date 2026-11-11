import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'burst_share.dart';
import 'burst_theme.dart';

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const BurstHeader(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffea2a33).withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/burst/create_icon.png',
                  width: 105,
                  height: 105,
                  fit: BoxFit.contain,
                  color: const Color(0xffea2a33),
                  colorBlendMode: BlendMode.srcIn,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Burst Created!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Owllet Burst is live and ready for guests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff191516),
                    border: Border.all(color: const Color(0xff302829)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: SelectableText(
                          joinCode,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xffea2a33),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy code',
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: joinCode)),
                        icon: const Icon(
                          Icons.content_copy,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'INVITE CODE',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (shareContext) => Container(
                decoration: const BoxDecoration(
                  boxShadow: burstPrimaryActionShadow,
                ),
                child: FilledButton(
                  onPressed: () => shareBurstCode(shareContext, joinCode),
                  style: FilledButton.styleFrom(
                    shape: burstButtonShape,
                    backgroundColor: const Color(0xffea2a33),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Share code'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onViewBurst ?? () => Navigator.of(context).pop(true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: const Color(0xff1b1b1b),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xff414141)),
                shape: burstButtonShape,
              ),
              child: const Text('View My Burst'),
            ),
          ],
        ),
      ),
    );
  }
}
