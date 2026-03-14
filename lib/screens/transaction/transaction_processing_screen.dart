import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

enum TransactionProgressStage {
  preparing,
  approvalPending,
  swapSubmitting,
  swapPending,
  gaslessPending,
  success,
  error,
}

class TransactionProgressState {
  const TransactionProgressState({
    required this.stage,
    this.message,
    this.reference,
    this.detailsUrl,
  });

  factory TransactionProgressState.initial() {
    return const TransactionProgressState(
      stage: TransactionProgressStage.preparing,
    );
  }

  final TransactionProgressStage stage;
  final String? message;
  final String? reference;
  final String? detailsUrl;

  bool get isTerminal =>
      stage == TransactionProgressStage.success ||
      stage == TransactionProgressStage.error;

  bool get hasProcessingState =>
      stage != TransactionProgressStage.success &&
      stage != TransactionProgressStage.error;
}

class TransactionProgressController extends ChangeNotifier {
  TransactionProgressController({TransactionProgressState? initialState})
    : _state = initialState ?? TransactionProgressState.initial();

  TransactionProgressState _state;
  bool _disposed = false;

  TransactionProgressState get state => _state;

  void setPreparing() {
    _update(
      const TransactionProgressState(stage: TransactionProgressStage.preparing),
    );
  }

  void setApprovalPending({String? reference, String? detailsUrl}) {
    _update(
      TransactionProgressState(
        stage: TransactionProgressStage.approvalPending,
        reference: reference,
        detailsUrl: detailsUrl,
      ),
    );
  }

  void setSwapSubmitting({bool gasless = false}) {
    _update(
      TransactionProgressState(
        stage: gasless
            ? TransactionProgressStage.gaslessPending
            : TransactionProgressStage.swapSubmitting,
      ),
    );
  }

  void setSwapPending({String? reference, String? detailsUrl}) {
    _update(
      TransactionProgressState(
        stage: TransactionProgressStage.swapPending,
        reference: reference,
        detailsUrl: detailsUrl,
      ),
    );
  }

  void setGaslessPending({String? reference, String? detailsUrl}) {
    _update(
      TransactionProgressState(
        stage: TransactionProgressStage.gaslessPending,
        reference: reference,
        detailsUrl: detailsUrl,
      ),
    );
  }

  void setSuccess({String? reference, String? detailsUrl}) {
    _update(
      TransactionProgressState(
        stage: TransactionProgressStage.success,
        reference: reference,
        detailsUrl: detailsUrl,
      ),
    );
  }

  void setError(String message, {String? reference, String? detailsUrl}) {
    _update(
      TransactionProgressState(
        stage: TransactionProgressStage.error,
        message: message,
        reference: reference,
        detailsUrl: detailsUrl,
      ),
    );
  }

  void _update(TransactionProgressState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class TransactionProcessingArguments {
  const TransactionProcessingArguments({required this.controller});

  final TransactionProgressController controller;
}

class TransactionProcessingScreen extends StatelessWidget {
  const TransactionProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments
            as TransactionProcessingArguments?;
    final controller = args?.controller;
    if (controller == null) {
      return _ProcessingScaffold(state: TransactionProgressState.initial());
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ProcessingScaffold(state: controller.state),
    );
  }
}

class _ProcessingScaffold extends StatelessWidget {
  const _ProcessingScaffold({required this.state});

  final TransactionProgressState state;

  IconData get _icon {
    switch (state.stage) {
      case TransactionProgressStage.error:
        return Icons.close_rounded;
      case TransactionProgressStage.preparing:
      case TransactionProgressStage.approvalPending:
      case TransactionProgressStage.swapSubmitting:
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
      case TransactionProgressStage.success:
        return Icons.check_rounded;
    }
  }

  Color get _iconColor {
    if (state.stage == TransactionProgressStage.error) {
      return Colors.white;
    }
    return AppColors.accentRed;
  }

  Color get _orbColor {
    if (state.stage == TransactionProgressStage.error) {
      return AppColors.error;
    }
    return AppColors.accentRed;
  }

  String _title(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.swapPreparingTitle;
      case TransactionProgressStage.approvalPending:
        return l.swapApprovalProcessingTitle;
      case TransactionProgressStage.swapSubmitting:
        return l.swapSubmittingTitle;
      case TransactionProgressStage.swapPending:
        return l.swapProcessingTitle;
      case TransactionProgressStage.gaslessPending:
        return state.reference == null
            ? l.swapGaslessSubmittingTitle
            : l.swapProcessingTitle;
      case TransactionProgressStage.success:
        return l.swapCompletedTitle;
      case TransactionProgressStage.error:
        return l.swapFailedTitle;
    }
  }

  String _subtitle(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.swapPreparingSubtitle;
      case TransactionProgressStage.approvalPending:
        return l.swapApprovalProcessingSubtitle;
      case TransactionProgressStage.swapSubmitting:
        return l.swapSubmittingSubtitle;
      case TransactionProgressStage.swapPending:
        return l.swapProcessingSubtitle;
      case TransactionProgressStage.gaslessPending:
        return state.reference == null
            ? l.swapGaslessSubmittingSubtitle
            : l.swapGaslessProcessingSubtitle;
      case TransactionProgressStage.success:
        return l.swapCompletedSubtitle;
      case TransactionProgressStage.error:
        return state.message ?? l.tryAgain;
    }
  }

  Future<void> _openDetails(BuildContext context) async {
    final detailsUrl = state.detailsUrl;
    if (detailsUrl != null && detailsUrl.isNotEmpty) {
      final uri = Uri.tryParse(detailsUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (!context.mounted) {
      return;
    }
    if (state.isTerminal) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushNamed(context, '/transactions');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasDetailsUrl =
        state.detailsUrl != null && state.detailsUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.cardDark,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _orbColor.withValues(alpha: 0.35),
                    _orbColor.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
              ),
              child: Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _orbColor.withValues(alpha: 0.2),
                  ),
                  child: Icon(_icon, color: _iconColor, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _title(l),
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                _subtitle(l),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (state.reference != null && state.reference!.isNotEmpty) ...[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  state.reference!,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (state.hasProcessingState) ...[
              const SizedBox(height: 18),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentRed,
                  ),
                ),
              ),
            ],
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GestureDetector(
                onTap: () => _openDetails(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      hasDetailsUrl
                          ? l.transactionDetails
                          : (state.isTerminal
                                ? l.closeLabel
                                : l.transactionDetails),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
