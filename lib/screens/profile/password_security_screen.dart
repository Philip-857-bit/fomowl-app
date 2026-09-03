import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_two_factor_service.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../widgets/bottom_navigation.dart';
import 'widgets/settings_group_card.dart';
import 'widgets/settings_item_tile.dart';
import 'widgets/settings_section_header.dart';

class PasswordSecurityScreen extends StatefulWidget {
  const PasswordSecurityScreen({super.key});

  @override
  State<PasswordSecurityScreen> createState() => _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState extends State<PasswordSecurityScreen> {
  final WalletTwoFactorService _walletTwoFactorService =
      WalletTwoFactorService();
  final StorageService _storage = StorageService();

  bool _biometricEnabled = false;
  bool _twoFactorEnabled = false;
  int _autoLockMinutes = 1;
  bool _lockOnBackground = true;
  bool _loading = true;
  bool _preferencesLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _preferencesLoadFailed = false;
    });
    try {
      final biometric = await _storage.isBiometricEnabled();
      final autoLock = await _storage.getAutoLockMinutes();
      final lockOnBackground = await _storage.isLockOnBackgroundEnabled();
      final cachedTwoFactorEnabled = await _storage.isTwoFactorEnabled();
      final twoFactorStatus = await _walletTwoFactorService
          .fetchTwoFactorStatus();
      final walletTwoFactorEnabled = twoFactorStatus['success'] == true
          ? twoFactorStatus['enabled'] == true
          : cachedTwoFactorEnabled;
      await _storage.setTwoFactorEnabled(walletTwoFactorEnabled);
      if (!mounted) return;
      setState(() {
        _biometricEnabled = biometric;
        _twoFactorEnabled = walletTwoFactorEnabled;
        _autoLockMinutes = autoLock;
        _lockOnBackground = lockOnBackground;
        _preferencesLoadFailed = false;
      });
    } catch (e) {
      debugPrint('Failed to load security preferences: $e');
      if (mounted) {
        setState(() => _preferencesLoadFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.securityPreferencesLoadFailed),
            action: SnackBarAction(label: l.retry, onPressed: _loadState),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    final l = AppLocalizations.of(context);
    final previous = _biometricEnabled;
    setState(() => _biometricEnabled = enabled);
    try {
      await _storage.setBiometricEnabled(enabled);
    } catch (e) {
      if (mounted) {
        setState(() => _biometricEnabled = previous);
      }
      debugPrint('Failed to persist biometric setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.unableToUpdateBiometric)));
      }
    }
  }

  Future<void> _showAutoLockPicker() async {
    final l = AppLocalizations.of(context);
    if (_preferencesLoadFailed) return;
    final options = <int>[1, 2, 5, 10, 30];
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.autoLockTimer,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final minutes in options)
              ListTile(
                title: Text(
                  l.autoLockMinutesLabel(minutes),
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
                trailing: _autoLockMinutes == minutes
                    ? const Icon(Icons.check_circle, color: AppColors.accentRed)
                    : null,
                onTap: () => Navigator.pop(ctx, minutes),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (selected == null || selected == _autoLockMinutes) return;

    final previous = _autoLockMinutes;
    setState(() => _autoLockMinutes = selected);
    try {
      await _storage.setAutoLockMinutes(selected);
    } catch (e) {
      if (mounted) {
        setState(() => _autoLockMinutes = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.unableToUpdateAutoLock)));
      }
      debugPrint('Failed to persist auto-lock setting: $e');
    }
  }

  Future<void> _setLockOnBackground(bool enabled) async {
    final l = AppLocalizations.of(context);
    final previous = _lockOnBackground;
    setState(() => _lockOnBackground = enabled);
    try {
      await _storage.setLockOnBackground(enabled);
    } catch (e) {
      if (mounted) {
        setState(() => _lockOnBackground = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.unableToUpdateBackgroundLock)));
      }
      debugPrint('Failed to persist background lock setting: $e');
    }
  }

  Future<void> _startChangePasswordFlow() async {
    final l = AppLocalizations.of(context);
    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: l.unlockWalletReason,
    );
    if (!authenticated || !mounted) return;
    await Navigator.pushNamed(
      context,
      '/create-passcode',
      arguments: {'mode': 'change'},
    );
  }

  Future<void> _openTwoFactorSetup() async {
    await Navigator.pushNamed(context, '/two-factor-setup');
    if (!mounted) return;
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const BottomNavBar(currentTab: null),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentRed),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            l.passwordSecurityTitle,
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettingsSectionHeader(title: l.accessControl),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.lock_outline_rounded,
                          title: l.changePassword,
                          subtitle: l.passcodeUnlock,
                          onTap: _startChangePasswordFlow,
                        ),
                        SettingsItemTile(
                          icon: Icons.fingerprint_rounded,
                          title: l.biometricsFaceId,
                          trailing: Switch(
                            value: _biometricEnabled,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.accentRed,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.divider,
                            onChanged: _preferencesLoadFailed
                                ? null
                                : _setBiometric,
                          ),
                        ),
                        SettingsItemTile(
                          icon: Icons.shield_outlined,
                          title: l.twoFactorAuth,
                          subtitle: _twoFactorEnabled
                              ? 'Authenticator codes now protect sensitive wallet actions'
                              : 'Enable authenticator-based 2FA for sensitive wallet actions',
                          onTap: _openTwoFactorSetup,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SettingsSectionHeader(title: l.advancedSecurity),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.timer_outlined,
                          title: l.foregroundAutoLockTimer,
                          subtitle: l.autoLockMinutesLabel(_autoLockMinutes),
                          onTap: _showAutoLockPicker,
                        ),
                        SettingsItemTile(
                          icon: Icons.lock_clock_outlined,
                          title: l.lockOnBackground,
                          subtitle: _lockOnBackground
                              ? l.immediateWhenAppIsHidden
                              : l.offLabel,
                          trailing: Switch(
                            value: _lockOnBackground,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.accentRed,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.divider,
                            onChanged: _preferencesLoadFailed
                                ? null
                                : _setLockOnBackground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.cardBackground,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        l.securitySummary,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
