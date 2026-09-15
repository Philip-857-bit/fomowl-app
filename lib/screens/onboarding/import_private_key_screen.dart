import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/chain.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/wallet_service.dart';
import '../../services/storage_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/screen_capture_guard.dart';
import 'package:provider/provider.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/toast_utils.dart';
import '../../l10n/app_localizations.dart';

/// Import Private Key Screen
/// Allows users to import wallet using private key
class ImportPrivateKeyScreen extends StatefulWidget {
  const ImportPrivateKeyScreen({super.key});

  @override
  State<ImportPrivateKeyScreen> createState() => _ImportPrivateKeyScreenState();
}

class _ImportPrivateKeyScreenState extends State<ImportPrivateKeyScreen> {
  final TextEditingController _walletNameController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  bool _obscurePrivateKey = true;
  final WalletService _walletService = WalletService();
  final ScreenCaptureGuard _screenCaptureGuard = ScreenCaptureGuard();
  bool _isLoading = false;
  ChainFamily _selectedChain = ChainFamily.evm;

  @override
  void initState() {
    super.initState();
    unawaited(_screenCaptureGuard.enableProtection());
  }

  @override
  void dispose() {
    _walletNameController.text = '';
    _privateKeyController.text = '';
    _walletNameController.dispose();
    _privateKeyController.dispose();
    unawaited(_screenCaptureGuard.disableProtection());
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _privateKeyController.text = clipboardData.text!;
      });
    }
  }

  Future<void> _importWallet() async {
    final l = AppLocalizations.of(context);
    final privateKey = _privateKeyController.text.trim();
    final walletName = _walletNameController.text.trim();

    if (privateKey.isEmpty) {
      _showError(l.enterPrivateKeyPrompt);
      return;
    }

    if (walletName.isEmpty) {
      _showError(l.enterWalletNamePrompt);
      return;
    }

    // EVM: strict 64-hex-char check (0x prefix optional).
    // Solana / Tron: accept any non-empty string; the wallet service validates.
    if (_selectedChain == ChainFamily.evm) {
      String cleanKey = privateKey;
      if (cleanKey.startsWith('0x')) {
        cleanKey = cleanKey.substring(2);
      }
      if (cleanKey.length != 64) {
        _showError(l.invalidPrivateKeyLength);
        return;
      }
      final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
      if (!hexRegex.hasMatch(cleanKey)) {
        _showError(l.invalidPrivateKeyCharacters);
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Import wallet using the selected chain family
      switch (_selectedChain) {
        case ChainFamily.solana:
          await _walletService.importWalletFromSolanaKey(
            privateKey,
            walletName: walletName,
          );
        case ChainFamily.tron:
          await _walletService.importWalletFromTronKey(
            privateKey,
            walletName: walletName,
          );
        case ChainFamily.evm:
          await _walletService.importWalletFromPrivateKey(
            privateKey,
            walletName: walletName,
          );
      }

      // Refresh blockchain service to clear any cached data from previous wallet
      if (mounted) {
        Provider.of<BlockchainService>(context, listen: false).refresh();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show success message
        ToastUtils.showSuccess(l.walletImportedSuccessfully);

        final storage = StorageService();
        if (await storage.hasPasscode()) {
          if (mounted) Navigator.pop(context, true);
        } else {
          if (mounted) Navigator.pushNamed(context, '/create-passcode');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError(
          AppErrorUtils.userMessage(
            e,
            fallback: l.importWalletFailed('Please try again.'),
          ),
        );
      }
    }
  }

  Widget _chainChip(String label, ChainFamily family, {String? assetPath}) {
    final selected = _selectedChain == family;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedChain = family),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryAccent.withValues(alpha: 0.18)
                : const Color(0xFF2C2B2B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primaryAccent
                  : Colors.white.withValues(alpha: 0.1),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChainLogo(
                label: label,
                family: family,
                assetPath: assetPath,
                selected: selected,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.primaryAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ToastUtils.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),

                const SizedBox(height: 20),

                // Chain selector
                Text(
                  'Blockchain',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    _chainChip(
                      'EVM',
                      ChainFamily.evm,
                      assetPath: 'assets/images/tokens/eth.png',
                    ),
                    const SizedBox(width: 10),
                    _chainChip('Solana', ChainFamily.solana),
                    const SizedBox(width: 10),
                    _chainChip('Tron', ChainFamily.tron),
                  ],
                ),

                const SizedBox(height: 24),

                // Wallet name label
                Text(
                  l.walletNameLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                // Wallet name input
                TextField(
                  controller: _walletNameController,
                  style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF2C2B2B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    hintText: l.enterWalletNameHint,
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Private key label
                Text(
                  l.privateKey,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                // Private key input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2B2B),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Stack(
                    children: [
                      TextField(
                        controller: _privateKeyController,
                        maxLines: _obscurePrivateKey ? 1 : 4,
                        obscureText: _obscurePrivateKey,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(20),
                          hintText: l.enterPrivateKeyHint,
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePrivateKey
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePrivateKey = !_obscurePrivateKey;
                              });
                            },
                          ),
                        ),
                      ),
                      // Paste button
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: TextButton(
                          onPressed: _pasteFromClipboard,
                          child: Text(
                            l.paste,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFEB3F3F),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Import wallet button
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _importWallet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFFC03F2E), Color(0xFF640C0B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isLoading ? Colors.grey : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l.importWallet,
                                style: GoogleFonts.outfit(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChainLogo extends StatelessWidget {
  const _ChainLogo({
    required this.label,
    required this.family,
    required this.selected,
    this.assetPath,
  });

  final String label;
  final ChainFamily family;
  final String? assetPath;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? AppColors.primaryAccent.withValues(alpha: 0.18)
              : Colors.white10,
        ),
        child: Text(
          label.isEmpty ? '?' : label.substring(0, 1),
          style: GoogleFonts.outfit(
            color: selected ? AppColors.primaryAccent : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final localPath = assetPath;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.asset(
        localPath,
        width: 24,
        height: 24,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return switch (family) {
      ChainFamily.solana => const SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(painter: _SolanaLogoPainter()),
      ),
      ChainFamily.tron => const SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(painter: _TronLogoPainter()),
      ),
      ChainFamily.evm => fallback(),
    };
  }
}

class _SolanaLogoPainter extends CustomPainter {
  const _SolanaLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height * 0.09);
    final barHeight = size.height * 0.18;
    final gap = size.height * 0.12;
    final leftInset = size.width * 0.12;
    final rightInset = size.width * 0.08;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF14F195), Color(0xFF9945FF)],
      ).createShader(Offset.zero & size);

    for (var i = 0; i < 3; i++) {
      final y = size.height * 0.22 + i * (barHeight + gap);
      final shift = i.isEven ? 0.0 : size.width * 0.08;
      final rect = Rect.fromLTWH(
        leftInset + shift,
        y,
        size.width - leftInset - rightInset,
        barHeight,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SolanaLogoPainter oldDelegate) => false;
}

class _TronLogoPainter extends CustomPainter {
  const _TronLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = const Color(0xFFFF0013)
      ..style = PaintingStyle.fill;

    final a = Offset(size.width * 0.18, size.height * 0.14);
    final b = Offset(size.width * 0.84, size.height * 0.32);
    final c = Offset(size.width * 0.42, size.height * 0.86);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    canvas.drawLine(a, c, stroke);
    canvas.drawLine(a, Offset(size.width * 0.58, size.height * 0.42), stroke);
    canvas.drawLine(b, Offset(size.width * 0.58, size.height * 0.42), stroke);
    canvas.drawLine(c, Offset(size.width * 0.58, size.height * 0.42), stroke);
  }

  @override
  bool shouldRepaint(covariant _TronLogoPainter oldDelegate) => false;
}
