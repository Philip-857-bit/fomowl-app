import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_two_factor_service.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../utils/toast_utils.dart';

class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final WalletTwoFactorService _walletTwoFactorService =
      WalletTwoFactorService();
  final StorageService _storage = StorageService();
  final TextEditingController _verificationController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _enabled = false;
  bool _hasPasscode = false;
  bool _pendingSetup = false;
  String? _secret;
  String? _otpauthUrl;
  String? _issuer;
  String? _accountName;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _verificationController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final hasPasscode = await _storage.hasPasscode();
    final cachedEnabled = await _storage.isTwoFactorEnabled();
    final status = await _walletTwoFactorService.fetchTwoFactorStatus();
    final enabled = status['success'] == true
        ? status['enabled'] == true
        : cachedEnabled;
    final pendingSetup =
        status['success'] == true && status['pending_setup'] == true;
    await _storage.setTwoFactorEnabled(enabled);
    if (!mounted) {
      return;
    }
    setState(() {
      _hasPasscode = hasPasscode;
      _enabled = enabled;
      _pendingSetup = pendingSetup;
      _loading = false;
      if (!pendingSetup) {
        _secret = null;
        _otpauthUrl = null;
        _issuer = null;
        _accountName = null;
      }
    });
  }

  Future<void> _startSetup() async {
    if (_submitting) {
      return;
    }
    if (!_hasPasscode) {
      ToastUtils.showError(
        'Set a wallet passcode before enabling authenticator-based 2FA.',
      );
      return;
    }

    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: 'Confirm to start Owllet authenticator setup',
    );
    if (!mounted || !authenticated) {
      return;
    }

    setState(() => _submitting = true);
    final result = await _walletTwoFactorService.beginTwoFactorSetup();
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (result['success'] != true) {
      ToastUtils.showError(
        result['error']?.toString() ?? 'Unable to start 2FA setup.',
      );
      return;
    }

    setState(() {
      _pendingSetup = true;
      _secret = result['secret']?.toString();
      _otpauthUrl = result['otpauth_url']?.toString();
      _issuer = result['issuer']?.toString();
      _accountName = result['account_name']?.toString();
    });
  }

  Future<void> _verifySetup() async {
    if (_submitting) {
      return;
    }
    final code = _verificationController.text.trim();
    if (code.length != 6) {
      ToastUtils.showError(
        'Enter the 6-digit code from your authenticator app.',
      );
      return;
    }

    setState(() => _submitting = true);
    final result = await _walletTwoFactorService.verifyTwoFactorSetup(
      code: code,
    );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (result['success'] != true) {
      ToastUtils.showError(
        result['error']?.toString() ?? 'Unable to activate 2FA.',
      );
      return;
    }

    await _storage.setTwoFactorEnabled(true);
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = true;
      _pendingSetup = false;
      _verificationController.clear();
    });
    ToastUtils.showSuccess('Authenticator-based 2FA is now active.');
  }

  Future<void> _disableTwoFactor() async {
    if (_submitting) {
      return;
    }

    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: 'Confirm to disable Owllet authenticator 2FA',
    );
    if (!mounted || !authenticated) {
      return;
    }

    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          'Disable authenticator 2FA',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            counterText: '',
            hintText: '123456',
            hintStyle: GoogleFonts.outfit(color: Colors.white38),
          ),
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(
              'Disable',
              style: GoogleFonts.outfit(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (code == null || code.length != 6) {
      return;
    }

    setState(() => _submitting = true);
    final result = await _walletTwoFactorService.disableTwoFactor(code: code);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (result['success'] != true) {
      ToastUtils.showError(
        result['error']?.toString() ?? 'Unable to disable 2FA.',
      );
      return;
    }

    await _storage.setTwoFactorEnabled(false);
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = false;
      _pendingSetup = false;
      _secret = null;
      _otpauthUrl = null;
      _issuer = null;
      _accountName = null;
      _verificationController.clear();
    });
    ToastUtils.showSuccess('Authenticator-based 2FA has been disabled.');
  }

  Future<void> _copySecret() async {
    final secret = _secret;
    if (secret == null || secret.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: secret));
    ToastUtils.showSuccess('Secret copied.');
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
          'Owllet Authenticator',
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
                  _buildProtectionCard(),
                  const SizedBox(height: 16),
                  if (_enabled) ...[
                    _buildEnabledCard(),
                    const SizedBox(height: 18),
                    _PrimaryActionButton(
                      label: 'Disable authenticator 2FA',
                      loading: _submitting,
                      onPressed: _disableTwoFactor,
                    ),
                  ] else ...[
                    if (_otpauthUrl == null || _secret == null) ...[
                      _buildSetupIntroCard(),
                      const SizedBox(height: 18),
                      _PrimaryActionButton(
                        label: _pendingSetup
                            ? 'Generate a new authenticator secret'
                            : 'Start authenticator setup',
                        loading: _submitting,
                        onPressed: _startSetup,
                      ),
                    ] else ...[
                      _buildSetupCard(),
                      const SizedBox(height: 18),
                      _PrimaryActionButton(
                        label: 'Verify and enable',
                        loading: _submitting,
                        onPressed: _verifySetup,
                      ),
                    ],
                  ],
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
          Text(
            _enabled
                ? 'Authenticator protection is active'
                : 'Protect sensitive wallet actions with TOTP codes',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Owllet uses authenticator-based TOTP codes for 2FA. You will still unlock with biometrics or passcode first, then confirm protected actions with a 6-digit code from your authenticator app.',
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

  Widget _buildProtectionCard() {
    return _InfoCard(
      title: 'What this protects',
      bullets: const [
        'Seed phrase and private key reveal flows',
        'Critical wallet security changes',
        'Other protected wallet actions routed through the guard',
      ],
    );
  }

  Widget _buildSetupIntroCard() {
    return _InfoCard(
      title: 'Before you begin',
      bullets: [
        _hasPasscode
            ? 'Wallet passcode found. You can enable authenticator 2FA now.'
            : 'A wallet passcode is required before authenticator 2FA can be enabled.',
        'Use Google Authenticator, Microsoft Authenticator, Authy, or another TOTP app.',
        'Save your recovery material securely before changing devices.',
      ],
    );
  }

  Widget _buildEnabledCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_user, color: AppColors.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Authenticator 2FA enabled',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Protected wallet actions now require a valid TOTP code.',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
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

  Widget _buildSetupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan the QR code',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add this account to your authenticator app, then enter the current 6-digit code below.',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: _otpauthUrl ?? '',
                size: 190,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SecretRow(
            label: 'Manual secret',
            value: _secret ?? '',
            secondary:
                '${_issuer ?? 'Owllet'}${_accountName == null ? '' : ' • ${_accountName!}'}',
            onCopy: _copySecret,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _verificationController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              counterText: '',
              labelText: '6-digit code',
              hintText: '123456',
              labelStyle: GoogleFonts.outfit(color: Colors.white70),
              hintStyle: GoogleFonts.outfit(color: Colors.white38),
            ),
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
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
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.accentRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bullet,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
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

class _SecretRow extends StatelessWidget {
  const _SecretRow({
    required this.label,
    required this.value,
    required this.secondary,
    required this.onCopy,
  });

  final String label;
  final String value;
  final String secondary;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentRed,
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              secondary,
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
            ),
          ],
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
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accentRed.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
