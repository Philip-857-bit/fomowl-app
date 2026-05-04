import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/biometric_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';

/// Fingerprint Check Screen – active scan step (Figma 41:631)
class FingerprintCheckScreen extends StatefulWidget {
  const FingerprintCheckScreen({super.key});

  @override
  State<FingerprintCheckScreen> createState() => _FingerprintCheckScreenState();
}

class _FingerprintCheckScreenState extends State<FingerprintCheckScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    if (_isVerifying) return;
    final l = AppLocalizations.of(context);
    setState(() => _isVerifying = true);
    try {
      final ok = await _biometricService.authenticate(
        localizedReason: l.fingerprintVerifyReason,
      );
      if (mounted) {
        if (ok) {
          Navigator.pushReplacementNamed(context, '/biometric-success');
        } else {
          ToastUtils.showError(l.fingerprintVerificationFailed);
          setState(() => _isVerifying = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(l.biometricUnavailable);
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFFEA2A33),
                  size: 20,
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFEA2A33,
                            ).withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      Container(
                        width: 211,
                        height: 211,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFEA2A33,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      Container(
                        width: 192,
                        height: 192,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E0E0E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFF5D3F3D,
                            ).withValues(alpha: 0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFEA2A33,
                              ).withValues(alpha: 0.4),
                              blurRadius: 7.5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/fingerprint_red.png',
                            width: 74,
                            height: 82,
                            fit: BoxFit.contain,
                            errorBuilder: (e, s, t) => const Icon(
                              Icons.fingerprint,
                              color: Color(0xFFEA2A33),
                              size: 80,
                            ),
                          ),
                        ),
                      ),
                      if (_isVerifying)
                        SizedBox(
                          width: 192,
                          height: 192,
                          child: CircularProgressIndicator(
                            color: const Color(
                              0xFFEA2A33,
                            ).withValues(alpha: 0.6),
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Security Check',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE2E2E2),
                      letterSpacing: -0.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Place your finger to verify',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFFC8C6C5),
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isVerifying ? null : _verify,
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA2A33),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFEA2A33,
                            ).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isVerifying)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          else ...[
                            Text(
                              'Verify',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.security,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFB7B5B4),
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
