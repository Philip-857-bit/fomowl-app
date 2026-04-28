import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../widgets/mobile_scaffold.dart';

class BlockchainSelectionScreen extends StatefulWidget {
  const BlockchainSelectionScreen({super.key});

  @override
  State<BlockchainSelectionScreen> createState() =>
      _BlockchainSelectionScreenState();
}

class _BlockchainSelectionScreenState extends State<BlockchainSelectionScreen> {
  final Set<ChainFamily> _enabled = {
    ChainFamily.evm,
    ChainFamily.solana,
    ChainFamily.tron,
  };

  // First family the user ever toggled ON becomes the default network.
  // We track insertion order via a list.
  final List<ChainFamily> _selectionOrder = [
    ChainFamily.evm,
    ChainFamily.solana,
    ChainFamily.tron,
  ];

  static const _chains = [
    _ChainOption(
      family: ChainFamily.evm,
      label: 'EVM Networks',
      subtitle: 'Ethereum, BNB, Base, Polygon & more',
      icon: Icons.hexagon_outlined,
      color: AppColors.accentRed,
    ),
    _ChainOption(
      family: ChainFamily.solana,
      label: 'Solana',
      subtitle: 'SOL and SPL tokens',
      icon: Icons.blur_circular_rounded,
      color: AppColors.primaryAccent,
    ),
    _ChainOption(
      family: ChainFamily.tron,
      label: 'Tron',
      subtitle: 'TRX and TRC-20 tokens',
      icon: Icons.change_history_rounded,
      color: AppColors.primaryAccent,
    ),
  ];

  void _toggle(ChainFamily family) {
    setState(() {
      if (_enabled.contains(family)) {
        if (_enabled.length == 1) return; // keep at least one
        _enabled.remove(family);
        _selectionOrder.remove(family);
      } else {
        _enabled.add(family);
        _selectionOrder.add(family);
      }
    });
  }

  String _defaultNetworkKey() {
    final first = _selectionOrder.first;
    return switch (first) {
      ChainFamily.solana => NetworkKey.solana('mainnet-beta'),
      ChainFamily.tron => NetworkKey.tron('mainnet'),
      ChainFamily.evm => NetworkKey.evm(1),
    };
  }

  Future<void> _continue() async {
    final blockchain = context.read<BlockchainService>();
    await blockchain.setEnabledFamilies(Set.of(_enabled));
    blockchain.setActiveNetworkKey(_defaultNetworkKey());
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/shell', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                'Choose Your\nBlockchains',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select the networks you want to use.\nYou can change this anytime in Settings.',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              ...(_chains.map(
                (opt) => _ChainToggleTile(
                  option: opt,
                  enabled: _enabled.contains(opt.family),
                  onToggle: () => _toggle(opt.family),
                  isDefault:
                      _selectionOrder.isNotEmpty &&
                      _selectionOrder.first == opt.family,
                ),
              )),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _ContinueButton(onPressed: _continue),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChainOption {
  final ChainFamily family;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ChainOption({
    required this.family,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _ChainToggleTile extends StatelessWidget {
  final _ChainOption option;
  final bool enabled;
  final bool isDefault;
  final VoidCallback onToggle;

  const _ChainToggleTile({
    required this.option,
    required this.enabled,
    required this.isDefault,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: enabled
              ? option.color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? option.color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon, color: option.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        option.label,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (isDefault && enabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: option.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: option.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (_) => onToggle(),
              activeThumbColor: option.color,
              activeTrackColor: option.color.withValues(alpha: 0.3),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ContinueButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC03F2E), Color(0xFF640C0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC03F2E).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Center(
            child: Text(
              'Continue',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
