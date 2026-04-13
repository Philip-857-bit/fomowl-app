import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/toast_utils.dart';

class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _enabled = false;
  String? _secret;
  String? _otpauthUrl;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final status = await _authService.fetchTwoFactorStatus();
    if (!mounted) return;

    if (status['success'] != true) {
      setState(() => _loading = false);
      ToastUtils.showError(
        status['error']?.toString() ?? 'Unable to load your 2FA status.',
      );
      return;
    }

    final enabled = status['enabled'] == true;
    if (enabled) {
      setState(() {
        _enabled = true;
        _loading = false;
      });
      return;
    }

    final setup = await _authService.beginTwoFactorSetup();
    if (!mounted) return;

    final setupSucceeded = setup['success'] == true;
    final setupSecret =
        setup['secret']?.toString() ?? setup['base32Secret']?.toString();
    final setupOtpAuthUrl =
        setup['otpauth_url']?.toString() ??
        setup['otpauthUrl']?.toString() ??
        setup['otpAuthUrl']?.toString();

    setState(() {
      _enabled = false;
      _loading = false;
      if (setupSucceeded) {
        _secret = setupSecret;
        _otpauthUrl = setupOtpAuthUrl;
      }
    });

    if (!setupSucceeded) {
      ToastUtils.showError(
        setup['error']?.toString() ??
            'Unable to start Owllet Shield 2FA right now.',
      );
      return;
    }

    if ((_secret ?? '').isEmpty || (_otpauthUrl ?? '').isEmpty) {
      ToastUtils.showError(
        'Unable to start Owllet Shield 2FA right now. Please try again.',
      );
    }
  }

  Future<void> _copySecret() async {
    final secret = _secret;
    if (secret == null || secret.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: secret));
    ToastUtils.showSuccess('Authenticator secret copied.');
  }

  Future<void> _activate() async {
    if ((_secret ?? '').isEmpty || (_otpauthUrl ?? '').isEmpty) {
      ToastUtils.showError(
        '2FA setup is incomplete. Re-open this screen and scan again.',
      );
      return;
    }

    final code = _codeController.text.trim();
    if (code.length < 6) {
      ToastUtils.showError('Enter the 6-digit code from your authenticator.');
      return;
    }

    setState(() => _submitting = true);
    final result = await _authService.verifyTwoFactorSetup(code: code);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      setState(() => _enabled = true);
      ToastUtils.showSuccess('Owllet Shield 2FA is now active.');
      return;
    }

    ToastUtils.showError(
      result['error']?.toString() ?? 'Unable to activate 2FA right now.',
    );
  }

  Future<void> _disable() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          'Disable Owllet Shield 2FA',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: GoogleFonts.outfit(color: AppColors.textPrimary),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter current 6-digit code',
            hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accentRed),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(
              'Disable',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (code == null || code.isEmpty) return;

    setState(() => _submitting = true);
    final result = await _authService.disableTwoFactor(code: code);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      _codeController.clear();
      ToastUtils.showSuccess('Two-factor authentication has been disabled.');
      await _bootstrap();
      return;
    }

    ToastUtils.showError(
      result['error']?.toString() ?? 'Unable to disable 2FA right now.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Owllet Shield 2FA',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentRed),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B0A0D),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/splash_logo.png',
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _enabled
                              ? 'Owllet Shield 2FA is enabled'
                              : 'Protect your sign-in with Owllet Shield 2FA',
                          style: GoogleFonts.outfit(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _enabled
                              ? 'Every sign-in will now require a 6-digit authenticator code in addition to your password.'
                              : 'Scan the QR code with Google Authenticator, Microsoft Authenticator, Authy, or any TOTP-compatible app, then enter the 6-digit code to activate it.',
                          style: GoogleFonts.outfit(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_enabled) _buildEnabledState() else _buildSetupState(),
                ],
              ),
            ),
    );
  }

  Widget _buildSetupState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              if (_otpauthUrl != null && _otpauthUrl!.isNotEmpty)
                QrImageView(
                  data: _otpauthUrl!,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  size: 192,
                ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _secret ?? '--',
                        style: GoogleFonts.robotoMono(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _copySecret,
                      icon: const Icon(
                        Icons.copy_outlined,
                        color: AppColors.accentRed,
                        size: 18,
                      ),
                      label: Text(
                        'Copy',
                        style: GoogleFonts.outfit(
                          color: AppColors.accentRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 22,
                    letterSpacing: 4,
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.accentRed),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _PrimaryActionButton(
                label: 'Verify & Activate',
                loading: _submitting,
                onPressed: _activate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Text(
            'Use an authenticator app you trust. Keep your recovery options in a safe place. If you lose access to 2FA and your device, account recovery may take longer.',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnabledState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A0D12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.accentRed,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authenticator App Active',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your Owllet account requires a 6-digit authenticator code when signing in.',
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryActionButton(
          label: 'Disable 2FA',
          loading: _submitting,
          onPressed: _disable,
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
