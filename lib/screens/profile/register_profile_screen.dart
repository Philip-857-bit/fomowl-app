import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/toast_utils.dart';

class RegisterProfileScreen extends StatefulWidget {
  const RegisterProfileScreen({super.key});

  @override
  State<RegisterProfileScreen> createState() => _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends State<RegisterProfileScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _xSecretController = TextEditingController();
  final _authService = AuthService();
  final _walletService = WalletService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureSecret = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _xSecretController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ToastUtils.showError(message);
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final xSecret = _xSecretController.text;

    if (email.isEmpty || username.isEmpty || password.isEmpty || xSecret.isEmpty) {
      _showError('All fields are required');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters');
      return;
    }

    setState(() => _isLoading = true);

    final walletAddress = await _walletService.getCurrentWalletAddress();

    final result = await _authService.register(
      email: email,
      username: username,
      password: password,
      xSecret: xSecret,
      walletAddress: walletAddress,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        // Registration success, go to profile tab root
        Navigator.pop(context, true); 
      } else {
        _showError(result['error']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Create Profile',
                      style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sync your wallet and secure your identity natively.',
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 32),
                    
                    _buildTextField('Email Address', _emailController, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    _buildTextField('Username', _usernameController),
                    const SizedBox(height: 20),
                    _buildPasswordField('Password', _passwordController, _obscurePassword, () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    }),
                    const SizedBox(height: 20),
                    _buildPasswordField('High Security X-Secret', _xSecretController, _obscureSecret, () {
                      setState(() => _obscureSecret = !_obscureSecret);
                    }, helperText: 'Used to authorize sensitive changes (like swapping linked wallets).'),
                    const SizedBox(height: 48),

                    GestureDetector(
                      onTap: _isLoading ? null : _register,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'Register',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscureText, VoidCallback onToggle, {String? helperText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.only(left: 16, right: 4),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.white.withValues(alpha: 0.5), size: 18),
                onPressed: onToggle,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.warning)),
        ]
      ],
    );
  }
}
