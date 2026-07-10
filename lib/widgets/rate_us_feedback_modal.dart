import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _ratePromptRed = Color(0xFFE53935);

class RateUsFeedbackModal extends StatefulWidget {
  const RateUsFeedbackModal({
    super.key,
    required this.onRateNow,
    required this.onMaybeLater,
    required this.onClose,
    required this.onSubmitFeedback,
  });

  final Future<void> Function() onRateNow;
  final Future<void> Function() onMaybeLater;
  final Future<void> Function() onClose;
  final Future<void> Function(String message) onSubmitFeedback;

  @override
  State<RateUsFeedbackModal> createState() => _RateUsFeedbackModalState();
}

class _RateUsFeedbackModalState extends State<RateUsFeedbackModal> {
  static const Color _text = Color(0xFF171D1A);

  final TextEditingController _feedbackController = TextEditingController();
  bool _showFeedback = false;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _closeWith(Future<void> Function() action) async {
    Navigator.of(context).pop();
    await action();
  }

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Please enter your feedback message.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.onSubmitFeedback(message);
      if (!mounted) return;
      setState(() => _submitted = true);
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 850), () {
          if (mounted) Navigator.of(context).pop();
        }),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Unable to submit feedback. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 380 ? width - 48 : 342.0;
    final cardHeight = _showFeedback ? 604.0 : 468.0;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(widget.onClose());
      },
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: cardWidth,
              height: cardHeight,
              margin: const EdgeInsets.only(top: 86),
              padding: const EdgeInsets.fromLTRB(32, 112, 32, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _neoShadows,
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/splash_logo.png',
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enjoying Owllet?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      height: 28 / 22,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "We'd love to hear your feedback. If you're enjoying Owllet, please take a moment to rate your experience on the Play Store. Your support helps us improve and reach more users.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _submitted
                        ? const _SubmittedState(key: ValueKey('submitted'))
                        : _showFeedback
                        ? _FeedbackState(
                            key: const ValueKey('feedback'),
                            controller: _feedbackController,
                            error: _error,
                            isSubmitting: _isSubmitting,
                            onSubmit: _submitFeedback,
                          )
                        : _RateState(
                            key: const ValueKey('rate'),
                            onRateNow: () => _closeWith(widget.onRateNow),
                            onMaybeLater: () => _closeWith(widget.onMaybeLater),
                            onSendFeedback: () =>
                                setState(() => _showFeedback = true),
                          ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -6,
              child: Image.asset(
                'assets/images/rate_us_mascot.png',
                width: 186,
                height: 186,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              right: 12,
              top: 104,
              child: GestureDetector(
                onTap: () => _closeWith(widget.onClose),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FBF6),
                    shape: BoxShape.circle,
                    boxShadow: _neoShadows,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF404943),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<BoxShadow> get _neoShadows => const [
    BoxShadow(color: Color(0x0D000000), offset: Offset(4, 4), blurRadius: 12),
    BoxShadow(color: Color(0xCCFFFFFF), offset: Offset(-4, -4), blurRadius: 12),
  ];
}

class _RateState extends StatelessWidget {
  const _RateState({
    super.key,
    required this.onRateNow,
    required this.onMaybeLater,
    required this.onSendFeedback,
  });

  final VoidCallback onRateNow;
  final VoidCallback onMaybeLater;
  final VoidCallback onSendFeedback;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModalButton(
          label: 'Rate us Now',
          icon: Icons.star_rounded,
          onTap: onRateNow,
          filled: true,
        ),
        const SizedBox(height: 16),
        _ModalButton(label: 'Maybe Later', onTap: onMaybeLater, filled: false),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onSendFeedback,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: Color(0xFF171D1A),
                ),
                const SizedBox(width: 8),
                Text(
                  'Send Feedback',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 18 / 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackState extends StatelessWidget {
  const _FeedbackState({
    super.key,
    required this.controller,
    required this.error,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? error;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 128,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                offset: Offset(2, 2),
                blurRadius: 5,
                blurStyle: BlurStyle.inner,
              ),
              BoxShadow(
                color: Color(0xCCFFFFFF),
                offset: Offset(-2, -2),
                blurRadius: 5,
                blurStyle: BlurStyle.inner,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            enabled: !isSubmitting,
            minLines: 5,
            maxLines: 5,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 20 / 14,
              color: const Color(0xFF171D1A),
            ),
            decoration: InputDecoration(
              hintText: 'Tell us about your experience!',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0x66404943),
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ratePromptRed,
            ),
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: isSubmitting ? null : onSubmit,
          child: Opacity(
            opacity: isSubmitting ? 0.72 : 1,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: _ratePromptRed,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    offset: Offset(0, 4),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Color(0x1A000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Send',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmittedState extends StatelessWidget {
  const _SubmittedState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: _ratePromptRed,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            'Thanks for your feedback.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF171D1A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalButton extends StatelessWidget {
  const _ModalButton({
    required this.label,
    required this.onTap,
    required this.filled,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: filled ? _ratePromptRed : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: _ratePromptRed, width: 2),
          boxShadow: filled
              ? const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    offset: Offset(4, 4),
                    blurRadius: 12,
                  ),
                  BoxShadow(
                    color: Color(0xCCFFFFFF),
                    offset: Offset(-4, -4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 18 / 14,
                fontWeight: FontWeight.w800,
                color: filled ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
