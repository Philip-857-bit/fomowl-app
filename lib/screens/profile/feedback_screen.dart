import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../constants/app_colors.dart';
import '../../services/feedback_service.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/bottom_navigation.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final FeedbackService _feedbackService = FeedbackService();
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _submitting = false;
  String _category = 'general';

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ToastUtils.showError('Please enter your feedback message');
      return;
    }

    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      ToastUtils.showError('No active wallet found');
      return;
    }

    setState(() => _submitting = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final languageCode = await _storage.getLanguage();
      await _feedbackService.submitFeedback(
        walletAddress: walletAddress,
        category: _category,
        subject: _subjectController.text.trim().isEmpty
            ? null
            : _subjectController.text.trim(),
        message: message,
        contactEmail: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        appVersion: info.version,
        languageCode: languageCode,
      );
      if (!mounted) return;
      ToastUtils.showSuccess('Feedback submitted. Thank you.');
      Navigator.pop(context);
    } catch (e) {
      ToastUtils.showError('Unable to submit feedback: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  ),
                  Text(
                    'Feedback',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Help us improve Owllet by sharing your thoughts.',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 18),
              _buildLabel('Category'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                dropdownColor: AppColors.cardDark,
                decoration: _inputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'bug', child: Text('Bug Report')),
                  DropdownMenuItem(value: 'feature', child: Text('Feature Request')),
                  DropdownMenuItem(value: 'design', child: Text('Design Feedback')),
                ],
                onChanged: (value) => setState(() => _category = value ?? 'general'),
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              const SizedBox(height: 14),
              _buildLabel('Subject (Optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: _inputDecoration(hint: 'Short summary'),
              ),
              const SizedBox(height: 14),
              _buildLabel('Message'),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                style: GoogleFonts.outfit(color: Colors.white),
                minLines: 5,
                maxLines: 8,
                decoration: _inputDecoration(hint: 'Tell us what happened or what you need'),
              ),
              const SizedBox(height: 14),
              _buildLabel('Contact Email (Optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: GoogleFonts.outfit(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(hint: 'you@example.com'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.accentRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Submit Feedback',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: Colors.white38),
      filled: true,
      fillColor: AppColors.cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentRed),
      ),
    );
  }
}
