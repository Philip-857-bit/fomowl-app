import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/referral_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/bottom_navigation.dart';
import 'widgets/settings_group_card.dart';
import 'widgets/settings_item_tile.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  final WalletService _walletService = WalletService();
  final ReferralService _referralService = ReferralService();
  final TextEditingController _referralInput = TextEditingController();

  ReferralProfile? _profile;
  String? _walletAddress;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _referralInput.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final l = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final walletAddress = await _walletService.getCurrentWalletAddress();
      if (walletAddress == null || walletAddress.isEmpty) {
        throw Exception('Wallet not connected');
      }
      final profile = await _referralService.getProfile(walletAddress);
      if (!mounted) return;
      setState(() {
        _walletAddress = walletAddress;
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Unable to load referrals: $e');
      ToastUtils.showError(l.unableToLoadReferrals);
    }
  }

  Future<void> _bindReferral() async {
    final l = AppLocalizations.of(context);
    final walletAddress = _walletAddress;
    final code = _referralInput.text.trim().toUpperCase();
    if (walletAddress == null || walletAddress.isEmpty) return;
    if (code.isEmpty) {
      ToastUtils.showInfo(l.enterReferralCodePrompt);
      return;
    }
    if (_profile != null && _profile!.referralCode == code) {
      ToastUtils.showError(l.ownReferralCodeError);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _referralService.bindReferralCode(
        walletAddress: walletAddress,
        referralCode: code,
      );
      ToastUtils.showSuccess(l.referralAdded);
      _referralInput.clear();
      if (mounted) {
        setState(() => _submitting = false);
      }
      await _loadProfile();
    } catch (e) {
      debugPrint('Unable to add referral: $e');
      ToastUtils.showError(l.unableToAddReferral);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _copyMyCode() async {
    final l = AppLocalizations.of(context);
    final code = _profile?.referralCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    ToastUtils.showSuccess(l.referralCodeCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                padding: const EdgeInsets.only(bottom: 28),
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
                            l.referrals,
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              l.referralsHeadline,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l.referralsSubtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.accentRed.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.yourReferralCode,
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              letterSpacing: 1.5,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _profile?.referralCode ?? '------',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 54,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _copyMyCode,
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.accentRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.numbers_outlined,
                          title: l.myCode,
                          subtitle: _profile?.referralCode ?? '--',
                          onTap: _copyMyCode,
                        ),
                        SettingsItemTile(
                          icon: Icons.person_add_alt_1_outlined,
                          title: l.myReferral,
                          subtitle: _profile?.referredByCode ?? l.noReferral,
                        ),
                        SettingsItemTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: l.rewardsEarned,
                          subtitle:
                              '\$${(_profile?.totalRewardsUsd ?? 0).toStringAsFixed(2)}',
                        ),
                        SettingsItemTile(
                          icon: Icons.groups_2_outlined,
                          title: l.referredUsers,
                          subtitle: l.referredUsersCount(
                            _profile?.totalReferrals ?? 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.divider.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.addReferral,
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              letterSpacing: 1.2,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _referralInput,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: l.enterReferralCode,
                              hintStyle: GoogleFonts.outfit(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.inputBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.divider.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.divider.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton(
                        onPressed: _loadProfile,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l.refresh,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _bindReferral,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: AppColors.accentRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l.addReferral,
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
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
