import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/mobile_scaffold.dart';

/// Wallet Imported Success Screen (Figma 41-2)
class WalletImportedScreen extends StatefulWidget {
  const WalletImportedScreen({super.key});

  @override
  State<WalletImportedScreen> createState() => _WalletImportedScreenState();
}

class _WalletImportedScreenState extends State<WalletImportedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  bool? _hasPasscode;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasPasscode == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _hasPasscode = args?['hasPasscode'] == true;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_hasPasscode == true) {
      Navigator.pushNamedAndRemoveUntil(context, '/shell', (route) => false);
    } else {
      Navigator.pushReplacementNamed(context, '/create-passcode');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Glowing circle with checkmark
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outermost ring (rgba 234,42,51,0.1) — pulsing
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, _) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 252,
                          height: 252,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0x1AEA2A33),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Middle ring (rgba 234,42,51,0.2) — pulsing slightly offset
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, _) => Transform.scale(
                        scale: _pulseAnim.value * 0.92,
                        child: Container(
                          width: 228,
                          height: 228,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0x33EA2A33),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Inner circle — dark bg + red glow shadow
                    Container(
                      width: 192,
                      height: 192,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E0E0E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x265D3F3D),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66EA2A33),
                            blurRadius: 15,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check,
                          size: 72,
                          color: Color(0xFFEA2A33),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Title
            Text(
              'Wallet Imported',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'You have successfully imported your existing wallet.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFD2D0D0),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(),

            // Continue button
            Padding(
              padding: const EdgeInsets.fromLTRB(49, 0, 49, 32),
              child: Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4DEA2A33),
                      blurRadius: 12,
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
                  ),
                  onPressed: _onContinue,
                  child: Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
