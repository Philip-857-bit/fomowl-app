import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../services/referral_service.dart';
import '../../services/wallet_service.dart';
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

  final TextEditingController _referralController = TextEditingController();
  final WalletService _walletService = WalletService();
  final ReferralService _referralService = ReferralService();

  static const _chains = [
    _ChainOption(
      family: ChainFamily.evm,
      label: 'EVM Ecosystem',
      subtitle: 'Ethereum, L2s, and Sidechains',
      iconBgColor: Color(0xFF627EEA),
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
      logoSize: 34,
    ),
    _ChainOption(
      family: ChainFamily.solana,
      label: 'Solana',
      subtitle: 'High-speed monolithic chain',
      iconBgColor: Colors.black,
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/info/logo.png',
      logoSize: 28,
    ),
    _ChainOption(
      family: ChainFamily.tron,
      label: 'Tron',
      subtitle: 'Global payment infrastructure',
      iconBgColor: Color(0xFF1B1B1B),
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/tron/info/logo.png',
      logoSize: 28,
    ),
  ];

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

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

    final code = _referralController.text.trim().toUpperCase();
    if (code.isNotEmpty) {
      try {
        final walletAddress = await _walletService.getCurrentWalletAddress();
        if (walletAddress != null && walletAddress.isNotEmpty) {
          await _referralService.bindReferralCode(
            walletAddress: walletAddress,
            referralCode: code,
          );
        }
      } catch (e) {
        debugPrint(
          '[BlockchainSelection] Referral bind failed (non-blocking): $e',
        );
      }
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/shell', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Bottom red glow
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 384,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x0DEA2A33)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFFEA2A33),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        Image.asset(
                          'assets/images/logo.png',
                          width: 58,
                          height: 71,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select Your Blockchain',
                          style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE2E2E2),
                            letterSpacing: -0.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose the ecosystems you wish to connect to\nyour vault. You can change these later in settings.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFC8C6C5),
                            height: 1.67,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'SELECT YOUR BLOCKCHAINS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFFC8C6C5),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._chains.map(
                          (opt) => _ChainToggleTile(
                            option: opt,
                            enabled: _enabled.contains(opt.family),
                            onToggle: () => _toggle(opt.family),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'OPTIONAL',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFFC8C6C5),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ReferralCodeField(controller: _referralController),
                        const SizedBox(height: 20),
                        const _MultichainInfoCard(),
                        const SizedBox(height: 28),
                        _ContinueButton(onPressed: _continue),
                        const SizedBox(height: 24),
                      ],
                    ),
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

class _ChainOption {
  final ChainFamily family;
  final String label;
  final String subtitle;
  final Color iconBgColor;
  final String logoUrl;
  final double logoSize;

  const _ChainOption({
    required this.family,
    required this.label,
    required this.subtitle,
    required this.iconBgColor,
    required this.logoUrl,
    required this.logoSize,
  });
}

class _ChainToggleTile extends StatelessWidget {
  final _ChainOption option;
  final bool enabled;
  final VoidCallback onToggle;

  const _ChainToggleTile({
    required this.option,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: option.iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: Image.network(
                  option.logoUrl,
                  width: option.logoSize,
                  height: option.logoSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(
                    option.label[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFFE2E2E2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFC8C6C5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ToggleSwitch(value: enabled),
          ],
        ),
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  final bool value;

  const _ToggleSwitch({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 24,
      decoration: BoxDecoration(
        color: value ? const Color(0xFFEA2A33) : const Color(0xFF353535),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: value
                ? null
                : Border.all(color: const Color(0xFFD1D5DB), width: 1),
          ),
        ),
      ),
    );
  }
}

class _ReferralCodeField extends StatelessWidget {
  final TextEditingController controller;

  const _ReferralCodeField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        border: Border.all(color: const Color(0x265D3F3D)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            Icons.confirmation_number_outlined,
            color: Color(0xFF474746),
            size: 20,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Referral Code',
                hintStyle: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF474746),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 17),
        ],
      ),
    );
  }
}

class _MultichainInfoCard extends StatelessWidget {
  const _MultichainInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0x1A349DB7),
        border: Border.all(color: const Color(0x33349DB7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF349DB7), size: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MULTICHAIN ENABLED',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFE2E2E2),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your wallet will automatically generate addresses for all selected networks using a single master seed phrase.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFC8C6C5),
                    height: 1.625,
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

class _ContinueButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ContinueButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4DEA2A33),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEA2A33),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: onPressed,
        child: Text(
          'CONTINUE',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}
