import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../utils/toast_utils.dart';

class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final StorageService _storage = StorageService();

  bool _loading = true;
  bool _submitting = false;
  bool _enabled = false;
  bool _hasPasscode = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final enabled = await _storage.isTwoFactorEnabled();
    final hasPasscode = await _storage.hasPasscode();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hasPasscode = hasPasscode;
      _loading = false;
    });
  }

  Future<void> _setWalletShield2fa(bool enabled) async {
    if (_submitting) {
      return;
    }

    final hasPasscode = await _storage.hasPasscode();
    if (!hasPasscode) {
      ToastUtils.showError(
        'Set a wallet passcode first before enabling Wallet Shield 2FA.',
      );
      return;
    }

    setState(() => _submitting = true);
    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: enabled
          ? 'Confirm to enable Wallet Shield 2FA'
          : 'Confirm to disable Wallet Shield 2FA',
    );

    if (!mounted) return;

    if (!authenticated) {
      setState(() => _submitting = false);
      return;
    }

    await _storage.setTwoFactorEnabled(enabled);
    setState(() {
      _enabled = enabled;
      _submitting = false;
    });

    ToastUtils.showSuccess(
      enabled
          ? 'Wallet Shield 2FA is now enabled.'
          : 'Wallet Shield 2FA has been disabled.',
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
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildWhatIsProtectedCard(),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  const SizedBox(height: 18),
                  _PrimaryActionButton(
                    label: _enabled
                        ? 'Disable Wallet Shield 2FA'
                        : 'Enable Wallet Shield 2FA',
                    loading: _submitting,
                    onPressed: () => _setWalletShield2fa(!_enabled),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/launcher_icon.png',
                width: 46,
                height: 46,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _enabled
                ? 'Wallet Shield 2FA is enabled'
                : 'Protect critical wallet actions with Wallet Shield 2FA',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Wallet Shield 2FA adds an extra security confirmation for sensitive wallet actions. This is wallet protection, not website sign-in protection.',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIsProtectedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Protected actions',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _bullet('Reset app and wallet removal actions'),
          _bullet('Change password and security settings'),
          _bullet('View seed phrase and private keys'),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final canEnable = _hasPasscode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _enabled
                  ? AppColors.accentRed.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _enabled ? Icons.verified_user_rounded : Icons.security_rounded,
              color: _enabled ? AppColors.accentRed : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _enabled ? 'Enabled' : 'Not enabled',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canEnable
                      ? 'Passcode found. Wallet Shield 2FA can be used.'
                      : 'Set a wallet passcode first to use Wallet Shield 2FA.',
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: AppColors.accentRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
