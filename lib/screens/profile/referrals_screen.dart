import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
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
      ToastUtils.showError('Unable to load referrals: $e');
    }
  }

  Future<void> _bindReferral() async {
    final walletAddress = _walletAddress;
    final code = _referralInput.text.trim().toUpperCase();
    if (walletAddress == null || walletAddress.isEmpty) return;
    if (code.isEmpty) {
      ToastUtils.showInfo('Enter a referral code');
      return;
    }
    if (_profile != null && _profile!.referralCode == code) {
      ToastUtils.showError('You cannot use your own referral code');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _referralService.bindReferralCode(
        walletAddress: walletAddress,
        referralCode: code,
      );
      ToastUtils.showSuccess('Referral added');
      _referralInput.clear();
      await _loadProfile();
    } catch (e) {
      ToastUtils.showError('Unable to add referral: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _copyMyCode() async {
    final code = _profile?.referralCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    ToastUtils.showSuccess('Referral code copied');
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
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentRed))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          ),
                          Text(
                            'Referrals',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Invite Friends and Earn\nRewards Together',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Earn up to \$0.5 for every user you refer using your referral code.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF9AA7C0),
                                fontSize: 14,
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
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR REFERRAL CODE',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF8794AF),
                              letterSpacing: 1.5,
                              fontSize: 13,
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
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _copyMyCode,
                                icon: const Icon(Icons.copy_rounded, color: AppColors.accentRed),
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
                          icon: Icons.badge_outlined,
                          title: 'My Code',
                          subtitle: _profile?.referralCode ?? '--',
                          onTap: _copyMyCode,
                        ),
                        SettingsItemTile(
                          icon: Icons.group_outlined,
                          title: 'My Referrals',
                          subtitle: '${_profile?.totalReferrals ?? 0} users',
                        ),
                        SettingsItemTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Rewards Earned',
                          subtitle: '\$${(_profile?.totalRewardsUsd ?? 0).toStringAsFixed(2)}',
                        ),
                        SettingsItemTile(
                          icon: Icons.link_outlined,
                          title: 'My Referral',
                          subtitle: _profile?.referredByCode ?? 'No referral',
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
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Referral',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF8794AF),
                              letterSpacing: 1.2,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _referralInput,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter referral code',
                              hintStyle: GoogleFonts.outfit(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.03),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'View Referral Stats',
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Add Referral',
                                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600),
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
