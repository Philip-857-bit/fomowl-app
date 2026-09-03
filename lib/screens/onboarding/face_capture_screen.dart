import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/mobile_scaffold.dart';
import '../../services/biometric_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';

/// Face Capture Screen – active scan step (Figma 41:703)
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_isCapturing) return;
    final l = AppLocalizations.of(context);
    setState(() => _isCapturing = true);
    try {
      final ok = await _biometricService.authenticate(
        localizedReason: l.faceVerifyReason,
      );
      if (mounted) {
        if (ok) {
          Navigator.pushReplacementNamed(context, '/biometric-success');
        } else {
          ToastUtils.showError(l.faceVerificationFailed);
          setState(() => _isCapturing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(l.biometricUnavailable);
        setState(() => _isCapturing = false);
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEA2A33)
                              .withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 240,
                              height: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFEA2A33)
                                      .withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            Container(
                              width: 211,
                              height: 211,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFEA2A33)
                                      .withValues(alpha: 0.2),
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
                                  color: const Color(0xFF5D3F3D)
                                      .withValues(alpha: 0.15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEA2A33)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 7.5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/face_recognition_red.png',
                                  width: 83,
                                  height: 83,
                                  fit: BoxFit.contain,
                                  errorBuilder: (e, s, t) => const Icon(
                                    Icons.face,
                                    color: Color(0xFFEA2A33),
                                    size: 80,
                                  ),
                                ),
                              ),
                            ),
                            if (_isCapturing)
                              SizedBox(
                                width: 192,
                                height: 192,
                                child: CircularProgressIndicator(
                                  color: const Color(0xFFEA2A33)
                                      .withValues(alpha: 0.6),
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
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
                        'Make sure your face is fully visible',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xFFC8C6C5),
                          letterSpacing: 0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isCapturing ? null : _capture,
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA2A33),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA2A33)
                                .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isCapturing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Capture',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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
