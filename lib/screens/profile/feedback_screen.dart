import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/feedback_service.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/toast_utils.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    this.initialCategory = 'general',
    this.initialSubject,
    this.initialMessage,
  });

  final String initialCategory;
  final String? initialSubject;
  final String? initialMessage;

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
    final l = AppLocalizations.of(context);
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ToastUtils.showError(l.enterFeedbackMessage);
      return;
    }

    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) {
      ToastUtils.showError(l.noActiveWalletFound);
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
      ToastUtils.showSuccess(l.feedbackSubmitted);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Unable to submit feedback: $e');
      ToastUtils.showError(l.feedbackSubmitFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _subjectController.text = widget.initialSubject?.trim() ?? '';
    _messageController.text = widget.initialMessage?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
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
                    l.feedbackTitle,
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l.feedbackSubtitle,
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              _buildLabel(l.feedbackCategory),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                dropdownColor: AppColors.cardDark,
                decoration: _inputDecoration(),
                items: [
                  DropdownMenuItem(
                    value: 'general',
                    child: Text(l.feedbackCategoryGeneral),
                  ),
                  DropdownMenuItem(
                    value: 'bug',
                    child: Text(l.feedbackCategoryBug),
                  ),
                  DropdownMenuItem(
                    value: 'feature',
                    child: Text(l.feedbackCategoryFeature),
                  ),
                  DropdownMenuItem(
                    value: 'design',
                    child: Text(l.feedbackCategoryDesign),
                  ),
                  DropdownMenuItem(
                    value: 'dapp_request',
                    child: Text(l.feedbackCategoryDappRequest),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? 'general'),
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              const SizedBox(height: 14),
              _buildLabel(l.feedbackSubjectOptional),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: _inputDecoration(hint: l.feedbackSubjectHint),
              ),
              const SizedBox(height: 14),
              _buildLabel(l.feedbackMessage),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                style: GoogleFonts.outfit(color: Colors.white),
                minLines: 5,
                maxLines: 8,
                decoration: _inputDecoration(hint: l.feedbackMessageHint),
              ),
              const SizedBox(height: 14),
              _buildLabel(l.feedbackContactEmailOptional),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: GoogleFonts.outfit(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(hint: l.feedbackEmailHint),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.accentRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l.submitFeedback,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
        color: AppColors.textPrimary,
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
