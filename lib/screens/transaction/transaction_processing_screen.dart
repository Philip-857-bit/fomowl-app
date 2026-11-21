import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/rate_us_prompt_service.dart';
import '../../services/runtime_config_service.dart';
import '../../theme/app_chain_theme.dart';
import '../../utils/in_app_link_router.dart';
import '../../widgets/entrance_motion.dart';

BoxDecoration _adaptivePrimaryButtonDecoration(
  AppChainTheme chainTheme, {
  double borderRadius = 12,
  double blurRadius = 12,
  Offset shadowOffset = const Offset(0, 4),
}) => BoxDecoration(
  gradient: chainTheme.buttonGradient,
  borderRadius: BorderRadius.circular(borderRadius),
  boxShadow: [
    BoxShadow(
      color: chainTheme.accentColor.withValues(alpha: 0.35),
      offset: shadowOffset,
      blurRadius: blurRadius,
    ),
  ],
);

Color _adaptivePrimaryButtonTextColor(LinearGradient gradient) {
  if (gradient.colors.isEmpty) return Colors.white;
  final averageLuminance =
      gradient.colors.map((c) => c.computeLuminance()).reduce((a, b) => a + b) /
      gradient.colors.length;
  return averageLuminance > 0.415 ? Colors.black : Colors.white;
}

enum TransactionProgressFlow { generic, swap, transfer }

enum TransactionProgressStage {
  preparing,
  approvalPending,
  swapSubmitting,
  swapPending,
  gaslessPending,
  submitted,
  submissionUnknown,
  confirmed,
  success,
  error,
}

class TransactionProgressState {
  const TransactionProgressState({
    required this.stage,
    this.flow = TransactionProgressFlow.generic,
    this.message,
    this.reference,
    this.detailsUrl,
  });

  factory TransactionProgressState.initial({
    TransactionProgressFlow flow = TransactionProgressFlow.generic,
  }) {
    return TransactionProgressState(
      stage: TransactionProgressStage.preparing,
      flow: flow,
    );
  }

  final TransactionProgressStage stage;
  final TransactionProgressFlow flow;
  final String? message;
  final String? reference;
  final String? detailsUrl;

  bool get isConfirmed => stage == TransactionProgressStage.confirmed;
  bool get isSuccessful =>
      isConfirmed || stage == TransactionProgressStage.success;
  bool get isTerminal =>
      isSuccessful || stage == TransactionProgressStage.error;
  bool get hasSubmissionResult =>
      stage == TransactionProgressStage.submitted ||
      stage == TransactionProgressStage.submissionUnknown;

  bool get hasProcessingState => !isTerminal && !hasSubmissionResult;

  TransactionProgressState copyWith({
    TransactionProgressStage? stage,
    TransactionProgressFlow? flow,
    String? message,
    bool clearMessage = false,
    String? reference,
    bool clearReference = false,
    String? detailsUrl,
    bool clearDetailsUrl = false,
  }) {
    return TransactionProgressState(
      stage: stage ?? this.stage,
      flow: flow ?? this.flow,
      message: clearMessage ? null : (message ?? this.message),
      reference: clearReference ? null : (reference ?? this.reference),
      detailsUrl: clearDetailsUrl ? null : (detailsUrl ?? this.detailsUrl),
    );
  }
}

class TransactionProgressController extends ChangeNotifier {
  TransactionProgressController({
    TransactionProgressFlow flow = TransactionProgressFlow.generic,
    TransactionProgressState? initialState,
  }) : _state = initialState ?? TransactionProgressState.initial(flow: flow);

  TransactionProgressState _state;
  bool _disposed = false;

  TransactionProgressState get state => _state;

  void setPreparing() {
    _update(
      _state.copyWith(
        stage: TransactionProgressStage.preparing,
        clearMessage: true,
        clearReference: true,
        clearDetailsUrl: true,
      ),
    );
  }

  void setApprovalPending({String? reference, String? detailsUrl}) {
    _update(
      _state.copyWith(
        stage: TransactionProgressStage.approvalPending,
        reference: reference,
        detailsUrl: detailsUrl,
        clearMessage: true,
      ),
    );
  }

  void setSwapSubmitting({bool gasless = false}) {
    _update(
      _state.copyWith(
        stage: gasless
            ? TransactionProgressStage.gaslessPending
            : TransactionProgressStage.swapSubmitting,
        clearMessage: true,
        clearReference: true,
        clearDetailsUrl: true,
      ),
    );
  }

  void setSwapPending({
    String? reference,
    String? detailsUrl,
    String? message,
  }) {
    _update(
      _state.copyWith(
        stage: TransactionProgressStage.swapPending,
        reference: reference,
        detailsUrl: detailsUrl,
        message: message,
        clearMessage: message == null,
      ),
    );
  }

  void setGaslessPending({String? reference, String? detailsUrl}) {
    _update(
      _state.copyWith(
        stage: TransactionProgressStage.gaslessPending,
        reference: reference,
        detailsUrl: detailsUrl,
        clearMessage: true,
      ),
    );
  }

  void setSubmitted({required String reference, required String detailsUrl}) {
    _setSubmissionStage(
      TransactionProgressStage.submitted,
      reference,
      detailsUrl,
    );
  }

  void setSubmissionUnknown({
    required String reference,
    required String detailsUrl,
  }) {
    _setSubmissionStage(
      TransactionProgressStage.submissionUnknown,
      reference,
      detailsUrl,
    );
  }

  void setConfirmed({required String reference, required String detailsUrl}) {
    _setSubmissionStage(
      TransactionProgressStage.confirmed,
      reference,
      detailsUrl,
    );
  }

  void _setSubmissionStage(
    TransactionProgressStage stage,
    String reference,
    String detailsUrl,
  ) {
    _update(
      _state.copyWith(
        stage: stage,
        reference: reference,
        detailsUrl: detailsUrl,
        clearMessage: true,
      ),
    );
  }

  void setSuccess({String? reference, String? detailsUrl}) {
    _update(
      _state.copyWith(
        stage: TransactionProgressStage.success,
        reference: reference,
        detailsUrl: detailsUrl,
        clearMessage: true,
      ),
    );
  }

  void setError(String message, {String? reference, String? detailsUrl}) {
    _update(
      _state.copyWith(
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
  const TransactionProcessingArguments({
    required this.controller,
    this.terminalRouteName,
    this.clearStackOnTerminalRoute = false,
  });

  final TransactionProgressController controller;
  final String? terminalRouteName;
  final bool clearStackOnTerminalRoute;
}

class TransactionProcessingScreen extends StatelessWidget {
  const TransactionProcessingScreen({super.key, this.festiveOverride});

  final bool? festiveOverride;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments
            as TransactionProcessingArguments?;
    final controller = args?.controller;
    return ListenableBuilder(
      listenable: RuntimeConfigService.instance,
      builder: (context, _) {
        final festiveSuccess =
            festiveOverride ??
            RuntimeConfigService
                .instance
                .snapshot
                .festiveTransactionSuccessEnabled;
        if (controller == null) {
          return _ProcessingScaffold(
            state: const TransactionProgressState(
              stage: TransactionProgressStage.preparing,
            ),
            festiveSuccess: festiveSuccess,
          );
        }

        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) => _RateUsPromptSuccessListener(
            state: controller.state,
            child: _ProcessingScaffold(
              state: controller.state,
              terminalRouteName: args?.terminalRouteName,
              clearStackOnTerminalRoute:
                  args?.clearStackOnTerminalRoute ?? false,
              festiveSuccess: festiveSuccess,
            ),
          ),
        );
      },
    );
  }
}

class _RateUsPromptSuccessListener extends StatefulWidget {
  const _RateUsPromptSuccessListener({
    required this.state,
    required this.child,
  });

  final TransactionProgressState state;
  final Widget child;

  @override
  State<_RateUsPromptSuccessListener> createState() =>
      _RateUsPromptSuccessListenerState();
}

class _RateUsPromptSuccessListenerState
    extends State<_RateUsPromptSuccessListener> {
  bool _scheduled = false;

  @override
  void didUpdateWidget(covariant _RateUsPromptSuccessListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeSchedulePrompt();
  }

  @override
  void initState() {
    super.initState();
    _maybeSchedulePrompt();
  }

  void _maybeSchedulePrompt() {
    if (_scheduled ||
        !widget.state.isSuccessful ||
        widget.state.flow == TransactionProgressFlow.generic) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(RateUsPromptService().maybeShowAfterPositiveMoment(context));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ProcessingScaffold extends StatelessWidget {
  const _ProcessingScaffold({
    required this.state,
    this.terminalRouteName,
    this.clearStackOnTerminalRoute = false,
    this.festiveSuccess = false,
  });

  final TransactionProgressState state;
  final String? terminalRouteName;
  final bool clearStackOnTerminalRoute;
  final bool festiveSuccess;

  IconData get _icon {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return Icons.sync_rounded;
      case TransactionProgressStage.approvalPending:
        return Icons.hourglass_top_rounded;
      case TransactionProgressStage.swapSubmitting:
        return Icons.send_rounded;
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
        return Icons.schedule_rounded;
      case TransactionProgressStage.gaslessPending:
        return Icons.flash_on_rounded;
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return Icons.check_rounded;
      case TransactionProgressStage.error:
        return Icons.close_rounded;
    }
  }

  Color get _iconColor {
    switch (state.stage) {
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return Colors.white;
      case TransactionProgressStage.error:
        return Colors.white;
      case TransactionProgressStage.preparing:
      case TransactionProgressStage.approvalPending:
      case TransactionProgressStage.swapSubmitting:
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return AppColors.accentRed;
    }
  }

  Color get _orbColor {
    switch (state.stage) {
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return AppColors.success;
      case TransactionProgressStage.error:
        return AppColors.error;
      case TransactionProgressStage.preparing:
      case TransactionProgressStage.approvalPending:
      case TransactionProgressStage.swapSubmitting:
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return AppColors.accentRed;
    }
  }

  String _title(AppLocalizations l) {
    if (state.stage == TransactionProgressStage.submitted) {
      return l.transactionSubmittedTitle;
    }
    if (state.stage == TransactionProgressStage.submissionUnknown) {
      return l.transactionSubmissionUnknownTitle;
    }
    if (state.stage == TransactionProgressStage.confirmed) {
      return l.bitcoinConfirmed;
    }
    switch (state.flow) {
      case TransactionProgressFlow.swap:
        return _swapTitle(l);
      case TransactionProgressFlow.transfer:
        return _transferTitle(l);
      case TransactionProgressFlow.generic:
        return _genericTitle(l);
    }
  }

  String _subtitle(AppLocalizations l) {
    if (state.stage == TransactionProgressStage.submitted) {
      return l.transactionSubmittedSubtitle;
    }
    if (state.stage == TransactionProgressStage.submissionUnknown) {
      return l.transactionSubmissionUnknownSubtitle;
    }
    if (state.stage == TransactionProgressStage.confirmed) {
      return l.transactionConfirmedSubtitle;
    }
    switch (state.flow) {
      case TransactionProgressFlow.swap:
        return _swapSubtitle(l);
      case TransactionProgressFlow.transfer:
        return _transferSubtitle(l);
      case TransactionProgressFlow.generic:
        return _genericSubtitle(l);
    }
  }

  String _swapTitle(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.swapPreparingTitle;
      case TransactionProgressStage.approvalPending:
        return l.swapApprovalProcessingTitle;
      case TransactionProgressStage.swapSubmitting:
        return l.swapSubmittingTitle;
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
        return l.swapProcessingTitle;
      case TransactionProgressStage.gaslessPending:
        return state.reference == null
            ? l.swapGaslessSubmittingTitle
            : l.swapProcessingTitle;
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return l.swapCompletedTitle;
      case TransactionProgressStage.error:
        return l.swapFailedTitle;
    }
  }

  String _swapSubtitle(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.swapPreparingSubtitle;
      case TransactionProgressStage.approvalPending:
        return l.swapApprovalProcessingSubtitle;
      case TransactionProgressStage.swapSubmitting:
        return l.swapSubmittingSubtitle;
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
        return l.swapProcessingSubtitle;
      case TransactionProgressStage.gaslessPending:
        return state.reference == null
            ? l.swapGaslessSubmittingSubtitle
            : l.swapGaslessProcessingSubtitle;
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return l.swapCompletedSubtitle;
      case TransactionProgressStage.error:
        return state.message ?? l.tryAgain;
    }
  }

  String _transferTitle(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.transferPreparingTitle;
      case TransactionProgressStage.approvalPending:
        return l.transferApprovalPendingTitle;
      case TransactionProgressStage.swapSubmitting:
        return l.transferSubmittingTitle;
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return l.transferInProgressTitle;
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return l.transferCompletedTitle;
      case TransactionProgressStage.error:
        return l.transferFailedTitle;
    }
  }

  String _transferSubtitle(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.transferPreparingSubtitle;
      case TransactionProgressStage.approvalPending:
        return l.transferApprovalPendingSubtitle;
      case TransactionProgressStage.swapSubmitting:
        return l.transferSubmittingSubtitle;
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
        return l.transferInProgressSubtitle;
      case TransactionProgressStage.gaslessPending:
        return l.transferInProgressSubtitle;
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return l.transferCompletedSubtitle;
      case TransactionProgressStage.error:
        return state.message ?? l.tryAgain;
    }
  }

  String _genericTitle(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.genericTransactionPreparingTitle;
      case TransactionProgressStage.approvalPending:
        return l.genericTransactionApprovalPendingTitle;
      case TransactionProgressStage.swapSubmitting:
        return l.genericTransactionSubmittingTitle;
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return l.genericTransactionInProgressTitle;
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return l.genericTransactionCompletedTitle;
      case TransactionProgressStage.error:
        return l.transactionFailed;
    }
  }

  String _genericSubtitle(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.genericTransactionPreparingSubtitle;
      case TransactionProgressStage.approvalPending:
        return l.genericTransactionApprovalPendingSubtitle;
      case TransactionProgressStage.swapSubmitting:
        return l.genericTransactionSubmittingSubtitle;
      case TransactionProgressStage.submitted:
      case TransactionProgressStage.submissionUnknown:
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return l.genericTransactionInProgressSubtitle;
      case TransactionProgressStage.confirmed:
      case TransactionProgressStage.success:
        return l.genericTransactionCompletedSubtitle;
      case TransactionProgressStage.error:
        return state.message ?? l.tryAgain;
    }
  }

  Future<void> _openDetails(BuildContext context) async {
    final detailsUrl = state.detailsUrl;
    if (detailsUrl != null && detailsUrl.isNotEmpty) {
      await InAppLinkRouter.open(context, detailsUrl);
      if (context.mounted) {
        _close(context);
      }
      return;
    }

    if (!context.mounted) {
      return;
    }
    if (state.isTerminal) {
      _close(context);
      return;
    }
    Navigator.pushNamed(context, '/transactions');
  }

  void _close(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    if ((state.isTerminal || state.hasSubmissionResult) &&
        terminalRouteName != null &&
        terminalRouteName!.isNotEmpty) {
      if (clearStackOnTerminalRoute) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          terminalRouteName!,
          (route) => false,
        );
        return;
      }
      Navigator.pushReplacementNamed(context, terminalRouteName!);
      return;
    }
    Navigator.pop(context);
  }

  String _primaryActionLabel(AppLocalizations l) {
    final hasDetailsUrl =
        state.detailsUrl != null && state.detailsUrl!.trim().isNotEmpty;
    if (hasDetailsUrl) {
      return l.viewOnExplorer;
    }
    if (state.isTerminal) {
      return l.closeLabel;
    }
    return l.transactionDetails;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.isSuccessful) {
      final hasDetailsUrl =
          state.detailsUrl != null && state.detailsUrl!.trim().isNotEmpty;
      return _TransactionSuccessStageView(
        festive: festiveSuccess,
        title: _title(l),
        subtitle: _subtitle(l),
        reference: state.reference,
        primaryActionLabel: _primaryActionLabel(l),
        closeLabel: l.closeLabel,
        showSecondaryClose: hasDetailsUrl,
        onPrimaryAction: () => _openDetails(context),
        onClose: () => _close(context),
      );
    }

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
                  onTap: () => _close(context),
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
            Expanded(
              child: EntranceMotion(
                beginOffset: const Offset(0, 0.03),
                child: _ProcessingStageView(
                  state: state,
                  title: _title(l),
                  subtitle: _subtitle(l),
                  icon: _icon,
                  iconColor: _iconColor,
                  orbColor: _orbColor,
                  primaryActionLabel: _primaryActionLabel(l),
                  onOpenDetails: () => _openDetails(context),
                  onClose: () => _close(context),
                  closeLabel: state.hasSubmissionResult
                      ? l.doneLabel
                      : l.closeLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingStageView extends StatelessWidget {
  const _ProcessingStageView({
    required this.state,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.orbColor,
    required this.primaryActionLabel,
    required this.onOpenDetails,
    required this.onClose,
    required this.closeLabel,
  });

  final TransactionProgressState state;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color orbColor;
  final String primaryActionLabel;
  final VoidCallback onOpenDetails;
  final VoidCallback onClose;
  final String closeLabel;

  bool get _hasDetailsUrl =>
      state.detailsUrl != null && state.detailsUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final chainTheme = context.chainTheme;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    ...previousChildren,
                    ...?(currentChild == null ? null : [currentChild]),
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: _ProcessingStatusContent(
                key: ValueKey<String>(
                  '${state.flow.name}:${state.stage.name}:${state.reference ?? ''}:${state.message ?? ''}',
                ),
                state: state,
                title: title,
                subtitle: subtitle,
                icon: icon,
                iconColor: iconColor,
                orbColor: orbColor,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              GestureDetector(
                onTap: onOpenDetails,
                child: Container(
                  key: const Key('transaction-processing-primary-button'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: _adaptivePrimaryButtonDecoration(
                    chainTheme,
                    borderRadius: 16,
                  ),
                  child: Center(
                    child: Text(
                      primaryActionLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _adaptivePrimaryButtonTextColor(
                          chainTheme.buttonGradient,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if ((state.isTerminal || state.hasSubmissionResult) &&
                  _hasDetailsUrl) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onClose,
                  child: Text(
                    closeLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProcessingStatusContent extends StatefulWidget {
  const _ProcessingStatusContent({
    super.key,
    required this.state,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.orbColor,
  });

  final TransactionProgressState state;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color orbColor;

  @override
  State<_ProcessingStatusContent> createState() =>
      _ProcessingStatusContentState();
}

class _ProcessingStatusContentState extends State<_ProcessingStatusContent>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _pulseController;
  late final AnimationController _successController;

  @override
  void initState() {
    super.initState();

    // Continuous spinner for the orbiting ring
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Subtle breathing / pulsing glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    if (widget.state.hasSubmissionResult ||
        widget.state.stage == TransactionProgressStage.confirmed) {
      _spinController.stop();
      _pulseController.stop();
    }
    // One-shot scale-up for the success tick
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    if (widget.state.isSuccessful) {
      _successController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _ProcessingStatusContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isSuccessful && !oldWidget.state.isSuccessful) {
      _successController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = widget.state.hasProcessingState;
    final isSuccess = widget.state.isSuccessful;
    final isError = widget.state.stage == TransactionProgressStage.error;
    final isSubmitted = widget.state.hasSubmissionResult;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Central visual ---
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing glow backdrop (only while processing)
                if (isProcessing)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final t = _pulseController.value;
                      final glowRadius = 60.0 + t * 16;
                      final glowOpacity = 0.12 + t * 0.10;
                      return Container(
                        width: glowRadius * 2,
                        height: glowRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentRed.withValues(
                                alpha: glowOpacity,
                              ),
                              blurRadius: 50,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Orbiting thin progress ring (only while processing)
                if (isProcessing)
                  AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _spinController.value * 2 * 3.14159265,
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: 130,
                      height: 130,
                      child: CustomPaint(
                        painter: _ArcRingPainter(
                          color: AppColors.accentRed,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),

                // Logo container (processing) or success/error icon
                if (isProcessing)
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cardDark,
                      border: Border.all(
                        color: AppColors.accentRed.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                if (isSubmitted)
                  Container(
                    key: const Key('transaction-submission-result'),
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentRed.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                // Success checkmark with pop animation
                if (isSuccess)
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _successController,
                      curve: Curves.elasticOut,
                    ),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.success.withValues(alpha: 0.30),
                            AppColors.success.withValues(alpha: 0.06),
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
                            color: AppColors.success.withValues(alpha: 0.2),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Error icon
                if (isError)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.94, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.error.withValues(alpha: 0.35),
                            AppColors.error.withValues(alpha: 0.08),
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
                            color: AppColors.error.withValues(alpha: 0.2),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Title — only show for terminal states
          if (isSuccess || isError || isSubmitted)
            Text(
              widget.title,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),

          // Processing: single subtle line
          if (isProcessing)
            Text(
              'Processing your transaction…',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.50),
              ),
            ),

          const SizedBox(height: 14),

          // Subtitle — only for terminal states
          if (isSuccess || isError || isSubmitted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                widget.subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Reference hash
          if (widget.state.reference != null &&
              widget.state.reference!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                widget.state.reference!,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints a partial arc ring (about 100°) for the loading spinner.
class _ArcRingPainter extends CustomPainter {
  _ArcRingPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw a background faint ring
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      0,
      2 * 3.14159265,
      false,
      paint..color = color.withValues(alpha: 0.08),
    );

    // Draw the active arc (~100 degrees = ~1.75 radians)
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -1.5708, // start at top (-90°)
      1.7453, // sweep ~100°
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcRingPainter oldDelegate) => false;
}

class _TransactionSuccessStageView extends StatelessWidget {
  const _TransactionSuccessStageView({
    required this.festive,
    required this.title,
    required this.subtitle,
    required this.reference,
    required this.primaryActionLabel,
    required this.closeLabel,
    required this.showSecondaryClose,
    required this.onPrimaryAction,
    required this.onClose,
  });

  final bool festive;
  final String title;
  final String subtitle;
  final String? reference;
  final String primaryActionLabel;
  final String closeLabel;
  final bool showSecondaryClose;
  final VoidCallback onPrimaryAction;
  final VoidCallback onClose;

  static const _badgeAsset =
      'assets/images/transaction_success/success_checkmark.svg';
  static const _underlineAsset =
      'assets/images/transaction_success/signature_underline.svg';

  @override
  Widget build(BuildContext context) {
    final backgroundColor = festive ? const Color(0xFF070103) : Colors.black;
    final chainTheme = context.chainTheme;

    return Scaffold(
      key: ValueKey<String>(
        'transaction-success-${festive ? 'festive' : 'standard'}',
      ),
      backgroundColor: backgroundColor,
      body: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: festive
                    ? const _FestiveSuccessBackdrop()
                    : const _StandardSuccessBackdrop(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                      child: GestureDetector(
                        onTap: onClose,
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
                  Expanded(
                    child: EntranceMotion(
                      beginOffset: const Offset(0, 0.03),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: math.max(
                                  0,
                                  constraints.maxHeight - 32,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildStatusCard(),
                                    if (festive) ...[
                                      const SizedBox(height: 36),
                                      _buildSeasonsGreetings(),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 342),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: onPrimaryAction,
                              child: Container(
                                key: const Key(
                                  'transaction-success-primary-button',
                                ),
                                width: double.infinity,
                                height: 48,
                                decoration: _adaptivePrimaryButtonDecoration(
                                  chainTheme,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  primaryActionLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _adaptivePrimaryButtonTextColor(
                                      chainTheme.buttonGradient,
                                    ),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            if (showSecondaryClose) ...[
                              const SizedBox(height: 12),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onClose,
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    closeLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final trimmedReference = reference?.trim();
    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.625,
            height: 37.5 / 25,
          ),
        ),
        const SizedBox(height: 8),
        _buildSignatureTagline(),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFB2B7C2),
              height: 24.38 / 15,
            ),
          ),
        ),
        if (trimmedReference != null && trimmedReference.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            trimmedReference,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB5BAC7),
              letterSpacing: 0.4,
              height: 1.5,
            ),
          ),
        ],
      ],
    );

    final Widget cardBody = festive
        ? Container(
            margin: const EdgeInsets.only(top: 43),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: CustomPaint(
                  foregroundPainter: const _FestiveGlassBorderPainter(
                    borderRadius: 34,
                  ),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 319),
                    padding: const EdgeInsets.fromLTRB(28, 65, 28, 28),
                    color: const Color(0x52080204),
                    child: cardContent,
                  ),
                ),
              ),
            ),
          )
        : Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 43),
            constraints: const BoxConstraints(minHeight: 319),
            padding: const EdgeInsets.fromLTRB(28, 65, 28, 28),
            decoration: BoxDecoration(
              color: const Color(0xF00A0A0A),
              borderRadius: BorderRadius.circular(34),
            ),
            child: cardContent,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 342),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          cardBody,
          Positioned(
            top: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.72, end: 1.0),
              duration: const Duration(milliseconds: 520),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                key: const Key('transaction-success-checkmark-badge'),
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  color: Color(0xFF4DCE9E),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  _badgeAsset,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureTagline() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Just Like ',
                    style: GoogleFonts.inter(
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      letterSpacing: -0.775,
                      height: 1.25,
                    ),
                  ),
                  TextSpan(
                    text: 'That',
                    style: GoogleFonts.inter(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFFF1A2B),
                      letterSpacing: -0.775,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: -6,
              child: SvgPicture.asset(
                _underlineAsset,
                width: 210,
                height: 10,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonsGreetings() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎄', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Text(
          "SEASON'S GREETINGS",
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xE6FCD34D),
            letterSpacing: 1.1,
            height: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        const Text('🎄', style: TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _FestiveGlassBorderPainter extends CustomPainter {
  const _FestiveGlassBorderPainter({required this.borderRadius});

  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(borderRadius - 0.5),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x88FFFFFF),
          Color(0x16FFFFFF),
          Color(0x10FFFFFF),
          Color(0x78FFFFFF),
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _FestiveGlassBorderPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius;
}

class _StandardSuccessBackdrop extends StatelessWidget {
  const _StandardSuccessBackdrop();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: CustomPaint(painter: _StandardSuccessRingsPainter()),
    );
  }
}

/// Paints the rotated curved neon rings with stroke-only outer glow.
///
/// Using CustomPainter with PaintingStyle.stroke avoids Flutter's BoxDecoration
/// BoxShadow behavior on transparent containers, which fills the box interior.
class _StandardSuccessRingsPainter extends CustomPainter {
  const _StandardSuccessRingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintRing(
      canvas: canvas,
      center: const Offset(90.0, 200.0),
      angleRadians: -18 * math.pi / 180,
      width: 420,
      height: 520,
      cornerRadius: 235,
      glowColor: const Color(0x3334D399),
      glowSigma: 14,
    );
    _paintRing(
      canvas: canvas,
      center: Offset(size.width - 130.0, size.height - 300.0),
      angleRadians: 25 * math.pi / 180,
      width: 520,
      height: 560,
      cornerRadius: 270,
      glowColor: const Color(0x3822C55E),
      glowSigma: 16,
    );
  }

  void _paintRing({
    required Canvas canvas,
    required Offset center,
    required double angleRadians,
    required double width,
    required double height,
    required double cornerRadius,
    required Color glowColor,
    required double glowSigma,
  }) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Radius.circular(cornerRadius),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleRadians);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = glowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0x80DC0000),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StandardSuccessRingsPainter oldDelegate) =>
      false;
}

class _FestiveSuccessBackdrop extends StatelessWidget {
  const _FestiveSuccessBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 341,
          child: Opacity(opacity: 0.23, child: _FestiveBottomScene()),
        ),
        const Positioned.fill(
          child: CustomPaint(painter: _FestiveAmbientArcPainter()),
        ),
        const Positioned.fill(
          child: CustomPaint(painter: _FestiveBokehPainter()),
        ),
        const Positioned(
          left: 97.5,
          top: 48,
          child: _SnowParticle(size: 6, opacity: 0.8),
        ),
        const Positioned(
          left: 192,
          top: 112,
          child: _SnowParticle(size: 8, opacity: 0.9),
        ),
        const Positioned(
          right: 97.5,
          top: 176,
          child: _SnowParticle(size: 4, opacity: 0.7),
        ),
        const Positioned(
          left: 40,
          top: 240,
          child: _SnowParticle(size: 10, opacity: 0.6),
        ),
        const Positioned(
          right: 32,
          top: 420,
          child: _SnowParticle(size: 6, opacity: 0.75),
        ),
        const Positioned(
          left: 56,
          top: 500,
          child: _SnowParticle(size: 8, opacity: 0.8),
        ),
        const Positioned(
          right: 96,
          top: 560,
          child: _SnowParticle(size: 4, opacity: 0.7),
        ),
        const Positioned(
          left: 112,
          bottom: 288,
          child: _SnowParticle(size: 10, opacity: 0.85),
        ),
        const Positioned(
          right: 144,
          bottom: 192,
          child: _SnowParticle(size: 6, opacity: 0.9),
        ),
        const Positioned(
          right: 56,
          bottom: 240,
          child: _SnowParticle(size: 8, opacity: 0.8),
        ),
        const Positioned(
          right: 46,
          top: 88,
          child: _GlowingSnowflake(
            asset:
                'assets/images/transaction_success/festive_snowflake_top_right.svg',
            size: 44,
            opacity: 0.9,
          ),
        ),
        const Positioned(
          left: 32,
          top: 572,
          child: _GlowingSnowflake(
            asset:
                'assets/images/transaction_success/festive_snowflake_mid_left.svg',
            size: 38,
            opacity: 0.8,
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final garlandHeight = constraints.maxWidth * (140 / 390);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -12,
                    height: garlandHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CustomPaint(
                          painter: _FestiveGarlandGlowPainter(),
                        ),
                        SvgPicture.asset(
                          'assets/images/transaction_success/festive_top_garland.svg',
                          fit: BoxFit.fill,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FestiveAmbientArcPainter extends CustomPainter {
  const _FestiveAmbientArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width - 90, 190);
    const radius = 220.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0x2EFF283C)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0x59FF2D41),
    );
  }

  @override
  bool shouldRepaint(covariant _FestiveAmbientArcPainter oldDelegate) => false;
}

class _FestiveBokehPainter extends CustomPainter {
  const _FestiveBokehPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final orbs = [
      (Offset(size.width - 80, 160), 48.0, const Color(0x59DC2626)),
      (const Offset(64, 104), 40.0, const Color(0x4DB91C1C)),
      (const Offset(8, 453.8), 56.0, const Color(0x66DC2626)),
      (Offset(104, size.height - 296), 40.0, const Color(0x66B91C1C)),
      (
        Offset(size.width - 112, size.height - 256),
        64.0,
        const Color(0x40D97706),
      ),
      (Offset(24, size.height - 176), 48.0, const Color(0x59DC2626)),
    ];
    for (final (center, radius, color) in orbs) {
      paint.color = color;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FestiveBokehPainter oldDelegate) => false;
}

class _GlowingSnowflake extends StatelessWidget {
  const _GlowingSnowflake({
    required this.asset,
    required this.size,
    required this.opacity,
  });

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
              child: SvgPicture.asset(
                asset,
                width: size,
                height: size,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  Color(0xD9FFFFFF),
                  BlendMode.srcIn,
                ),
              ),
            ),
            SvgPicture.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compensates for flutter_svg ignoring SVG `<filter>` glows on garland lights.
class _FestiveGarlandGlowPainter extends CustomPainter {
  const _FestiveGarlandGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xE6FACC15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    const points = [
      Offset(25.4 / 390, 26.5 / 140),
      Offset(52.6 / 390, 47.3 / 140),
      Offset(92.5 / 390, 53.7 / 140),
      Offset(149.7 / 390, 42.8 / 140),
      Offset(36.3 / 390, 83.6 / 140),
    ];
    for (final p in points) {
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        8,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FestiveGarlandGlowPainter oldDelegate) => false;
}

class _FestiveBottomScene extends StatelessWidget {
  const _FestiveBottomScene();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -16,
          bottom: 64,
          child: SvgPicture.asset(
            'assets/images/transaction_success/festive_pine_spray_left.svg',
            width: 144,
            height: 112,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          right: 8,
          bottom: 24,
          width: 208,
          height: 288,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _FestiveTreeGlowPainter()),
              ),
              SvgPicture.asset(
                'assets/images/transaction_success/festive_christmas_tree.svg',
                width: 208,
                height: 288,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
        const Positioned(
          left: 8,
          bottom: 16,
          child: _FestiveGiftBoxesCluster(),
        ),
        Positioned(
          right: 4,
          bottom: -8,
          child: SvgPicture.asset(
            'assets/images/transaction_success/festive_snowman.svg',
            width: 176,
            height: 224,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          child: SvgPicture.asset(
            'assets/images/transaction_success/festive_snow_drifts.svg',
            fit: BoxFit.fill,
          ),
        ),
      ],
    );
  }
}

/// Compensates for flutter_svg ignoring SVG `<filter>` glows on the tree star
/// and fairy lights.
class _FestiveTreeGlowPainter extends CustomPainter {
  const _FestiveTreeGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      const Offset(109.5, 36.7),
      18,
      Paint()
        ..color = const Color(0xD9FACC15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    final lightPaint = Paint()
      ..color = const Color(0x99FACC15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    const lights = [
      Offset(104.0, 61.9),
      Offset(85.4, 98.0),
      Offset(129.2, 105.7),
      Offset(65.7, 149.5),
      Offset(107.3, 144.0),
      Offset(147.8, 160.4),
      Offset(52.5, 207.5),
      Offset(100.7, 198.7),
      Offset(142.3, 215.2),
      Offset(175.2, 226.1),
    ];
    for (final light in lights) {
      canvas.drawCircle(light, 5, lightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FestiveTreeGlowPainter oldDelegate) => false;
}

class _GiftVectorLayer {
  const _GiftVectorLayer(
    this.asset,
    this.top,
    this.right,
    this.bottom,
    this.left,
  );

  final String asset;
  final double top;
  final double right;
  final double bottom;
  final double left;
}

class _FestiveGiftBoxesCluster extends StatelessWidget {
  const _FestiveGiftBoxesCluster();

  static const double _width = 195;
  static const double _height = 135;

  static const List<_GiftVectorLayer> _layers = [
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_0.svg',
      0.40,
      0.3764,
      0.0643,
      0.0549,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_1.svg',
      0.3429,
      0.3615,
      0.55,
      0.0401,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_2.svg',
      0.3429,
      0.6286,
      0.0643,
      0.2824,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_3.svg',
      0.6143,
      0.3764,
      0.2714,
      0.0549,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_4.svg',
      0.2707,
      0.7225,
      0.6571,
      0.1838,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_5.svg',
      0.2707,
      0.53,
      0.6571,
      0.3764,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_6.svg',
      0.30,
      0.6434,
      0.6143,
      0.2973,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_7.svg',
      0.5857,
      0.3121,
      0.0429,
      0.3121,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_8.svg',
      0.55,
      0.3022,
      0.3714,
      0.3022,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_9.svg',
      0.55,
      0.4753,
      0.0429,
      0.4604,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_10.svg',
      0.7286,
      0.3121,
      0.1857,
      0.3121,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_11.svg',
      0.5117,
      0.5297,
      0.45,
      0.4142,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_12.svg',
      0.5117,
      0.424,
      0.45,
      0.5198,
    ),
    _GiftVectorLayer(
      'assets/images/transaction_success/gift_vector_13.svg',
      0.5179,
      0.4827,
      0.4179,
      0.4728,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final layer in _layers)
            Positioned(
              left: layer.left * _width,
              top: layer.top * _height,
              width: (1 - layer.left - layer.right) * _width,
              height: (1 - layer.top - layer.bottom) * _height,
              child: SvgPicture.asset(layer.asset, fit: BoxFit.contain),
            ),
        ],
      ),
    );
  }
}

class _SnowParticle extends StatelessWidget {
  const _SnowParticle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: opacity * 0.6),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}
