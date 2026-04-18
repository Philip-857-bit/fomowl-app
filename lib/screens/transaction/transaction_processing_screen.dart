import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/in_app_link_router.dart';
import '../../widgets/entrance_motion.dart';

enum TransactionProgressFlow { generic, swap, transfer }

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

  bool get isTerminal =>
      stage == TransactionProgressStage.success ||
      stage == TransactionProgressStage.error;

  bool get hasProcessingState =>
      stage != TransactionProgressStage.success &&
      stage != TransactionProgressStage.error;

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

  void setSwapPending({String? reference, String? detailsUrl}) {
    _update(
      _state.copyWith(
        stage: TransactionProgressStage.swapPending,
        reference: reference,
        detailsUrl: detailsUrl,
        clearMessage: true,
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
  const TransactionProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments
            as TransactionProcessingArguments?;
    final controller = args?.controller;
    if (controller == null) {
      return const _ProcessingScaffold(
        state: TransactionProgressState(
          stage: TransactionProgressStage.preparing,
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ProcessingScaffold(
        state: controller.state,
        terminalRouteName: args?.terminalRouteName,
        clearStackOnTerminalRoute: args?.clearStackOnTerminalRoute ?? false,
      ),
    );
  }
}

class _ProcessingScaffold extends StatelessWidget {
  const _ProcessingScaffold({
    required this.state,
    this.terminalRouteName,
    this.clearStackOnTerminalRoute = false,
  });

  final TransactionProgressState state;
  final String? terminalRouteName;
  final bool clearStackOnTerminalRoute;

  IconData get _icon {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return Icons.sync_rounded;
      case TransactionProgressStage.approvalPending:
        return Icons.hourglass_top_rounded;
      case TransactionProgressStage.swapSubmitting:
        return Icons.send_rounded;
      case TransactionProgressStage.swapPending:
        return Icons.schedule_rounded;
      case TransactionProgressStage.gaslessPending:
        return Icons.flash_on_rounded;
      case TransactionProgressStage.success:
        return Icons.check_rounded;
      case TransactionProgressStage.error:
        return Icons.close_rounded;
    }
  }

  Color get _iconColor {
    switch (state.stage) {
      case TransactionProgressStage.success:
        return Colors.white;
      case TransactionProgressStage.error:
        return Colors.white;
      case TransactionProgressStage.preparing:
      case TransactionProgressStage.approvalPending:
      case TransactionProgressStage.swapSubmitting:
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return AppColors.accentRed;
    }
  }

  Color get _orbColor {
    switch (state.stage) {
      case TransactionProgressStage.success:
        return AppColors.success;
      case TransactionProgressStage.error:
        return AppColors.error;
      case TransactionProgressStage.preparing:
      case TransactionProgressStage.approvalPending:
      case TransactionProgressStage.swapSubmitting:
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return AppColors.accentRed;
    }
  }

  String _title(AppLocalizations l) {
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

  String _swapSubtitle(AppLocalizations l) {
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

  String _transferTitle(AppLocalizations l) {
    switch (state.stage) {
      case TransactionProgressStage.preparing:
        return l.transferPreparingTitle;
      case TransactionProgressStage.approvalPending:
        return l.transferApprovalPendingTitle;
      case TransactionProgressStage.swapSubmitting:
        return l.transferSubmittingTitle;
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return l.transferInProgressTitle;
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
      case TransactionProgressStage.swapPending:
        return l.transferInProgressSubtitle;
      case TransactionProgressStage.gaslessPending:
        return l.transferInProgressSubtitle;
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
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return l.genericTransactionInProgressTitle;
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
      case TransactionProgressStage.swapPending:
      case TransactionProgressStage.gaslessPending:
        return l.genericTransactionInProgressSubtitle;
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
    if (state.isTerminal &&
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
                  closeLabel: l.closeLabel,
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
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      primaryActionLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              if (state.isTerminal && _hasDetailsUrl) ...[
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

class _ProcessingStatusContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.94, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    orbColor.withValues(alpha: 0.35),
                    orbColor.withValues(alpha: 0.08),
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
                    color: orbColor.withValues(alpha: 0.2),
                  ),
                  child: Icon(icon, color: iconColor, size: 40),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
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
              subtitle,
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
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentRed,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
