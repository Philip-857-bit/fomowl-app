import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_chain_theme.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/bottom_navigation.dart';
import 'coming_soon_overlay.dart';

/// My Profile Screen — "Me" tab
/// Avatar, KYC badge, Account/Preferences/Support sections
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storage = StorageService();
  final AuthService _authService = AuthService();
  String _walletName = 'User';
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await _storage.getWalletName();
    final loggedIn = await _authService.isLoggedIn();

    if (mounted) {
      setState(() {
        _walletName = name ?? 'User';
        _isLoggedIn = loggedIn;
      });
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    _loadProfile();
  }

  void _navigateComingSoon(String feature) {
    ComingSoonOverlay.show(context, title: feature);
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Center(
                  child: Text(
                    'My Profile',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Auth Area or Avatar
              if (!_isLoggedIn)
                _buildUnauthenticatedView()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarHeader(),
                    const SizedBox(height: 32),

                    // Account section
                    _buildSectionHeader('Account'),
                    _buildMenuItem(Icons.badge_outlined, 'Identity status', () {
                      Navigator.pushNamed(context, '/kyc-success');
                    }),
                    _buildMenuItem(
                      Icons.lock_outline,
                      'Password & Security',
                      () {
                        Navigator.pushNamed(context, '/unlock');
                      },
                    ),
                    _buildMenuItem(
                      Icons.language,
                      'Language',
                      () => _navigateComingSoon('Language'),
                    ),
                    _buildMenuItem(
                      Icons.public,
                      'Join our communities',
                      () => _navigateComingSoon('Communities'),
                    ),
                    _buildMenuItem(Icons.people_outline, 'Referrals', () {
                      Navigator.pushNamed(context, '/referrals');
                    }),
                    const SizedBox(height: 16),

                    // Preferences section
                    _buildSectionHeader('Preferences'),
                    _buildMenuItem(
                      Icons.info_outline,
                      'About us',
                      () => _navigateComingSoon('About us'),
                    ),
                    _buildMenuItem(
                      Icons.settings_outlined,
                      'Networks',
                      () => _navigateComingSoon('Networks'),
                    ),
                    const SizedBox(height: 16),

                    // Support section
                    _buildSectionHeader('Support'),
                    _buildMenuItem(
                      Icons.help_outline,
                      'Help Center',
                      () => _navigateComingSoon('Help Center'),
                    ),
                    _buildMenuItem(Icons.build_outlined, 'Version', () {
                      ToastUtils.showInfo('Owllet Wallet v1.0.0');
                    }),
                    const SizedBox(height: 16),
                    _buildMenuItem(Icons.logout, 'Log Out', _logout),
                  ],
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedView() {
    final theme = context.chainTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(Icons.shield_outlined, size: 56, color: theme.accentColor),
            const SizedBox(height: 16),
            Text(
              'Sync Identity',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log in or register to secure your account and unlock KYC limits without exposing keys.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/profile-login',
                      );
                      if (result == true) _loadProfile();
                    },
                    child: Text(
                      'Log In',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: theme.buttonGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/profile-register',
                        );
                        if (result == true) _loadProfile();
                      },
                      child: Text(
                        'Register',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarHeader() {
    final theme = context.chainTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Icon(Icons.person, color: theme.accentColor, size: 34),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _walletName,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'KYC Verified',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.7),
                size: 17,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
