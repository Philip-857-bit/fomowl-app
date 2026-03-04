import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
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
  final StorageService _storage = StorageService();

  bool _biometricEnabled = false;
  bool _twoFactorEnabled = false;
  int _autoLockMinutes = 1;
  bool _loading = true;
  bool _preferencesLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() {
      _loading = true;
      _preferencesLoadFailed = false;
    });
    try {
      final biometric = await _storage.isBiometricEnabled();
      final twoFactor = await _storage.isTwoFactorEnabled();
      final autoLock = await _storage.getAutoLockMinutes();
      if (!mounted) return;
      setState(() {
        _biometricEnabled = biometric;
        _twoFactorEnabled = twoFactor;
        _autoLockMinutes = autoLock;
        _preferencesLoadFailed = false;
      });
    } catch (e) {
      debugPrint('Failed to load security preferences: $e');
      if (mounted) {
        setState(() => _preferencesLoadFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load security preferences'),
            action: SnackBarAction(label: 'Retry', onPressed: _loadState),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update biometric setting')),
        );
      }
    }
  }

  Future<void> _setTwoFactor(bool enabled) async {
    final previous = _twoFactorEnabled;
    setState(() => _twoFactorEnabled = enabled);
    try {
      await _storage.setTwoFactorEnabled(enabled);
    } catch (e) {
      if (mounted) {
        setState(() => _twoFactorEnabled = previous);
      }
      debugPrint('Failed to persist 2FA setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update 2FA setting')),
        );
      }
    }
  }

  Future<void> _showAutoLockPicker() async {
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
              'Auto-Lock Timer',
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
                  '$minutes minute${minutes > 1 ? 's' : ''}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update auto-lock setting')),
        );
      }
      debugPrint('Failed to persist auto-lock setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 4,
        onTap: (index) => BottomNavBar.handleNavigation(context, index, 4),
      ),
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
                            'Password & Security',
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
                    const SettingsSectionHeader(title: 'Access Control'),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'Change Password',
                          subtitle: 'Passcode unlock',
                          onTap: () =>
                              Navigator.pushNamed(context, '/create-passcode'),
                        ),
                        SettingsItemTile(
                          icon: Icons.fingerprint_rounded,
                          title: 'Biometrics / Face ID',
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SettingsSectionHeader(title: 'Advanced Security'),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.verified_user_outlined,
                          title: 'Two-Factor Authentication (2FA)',
                          subtitle: _twoFactorEnabled ? 'On' : 'Off',
                          trailing: Switch(
                            value: _twoFactorEnabled,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.accentRed,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.divider,
                            onChanged: _preferencesLoadFailed
                                ? null
                                : _setTwoFactor,
                          ),
                        ),
                        SettingsItemTile(
                          icon: Icons.timer_outlined,
                          title: 'Auto-Lock Timer',
                          subtitle:
                              '$_autoLockMinutes minute${_autoLockMinutes > 1 ? 's' : ''}',
                          onTap: _showAutoLockPicker,
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
                        'Enable additional security measures to protect your digital assets from unauthorized access.',
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
