import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/wallet_account.dart';
import '../../services/screen_capture_guard.dart';
import '../../services/wallet_service.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/mobile_scaffold.dart';

typedef SensitiveAuthVerifier =
    Future<bool> Function(BuildContext context, {String? reason});
typedef VerificationRandomFactory = Random Function();

class BackupSeedPhraseScreen extends StatefulWidget {
  const BackupSeedPhraseScreen({
    super.key,
    this.walletService,
    this.authVerifier,
    this.screenCaptureGuard,
    this.randomFactory,
    this.revealDuration = const Duration(seconds: 60),
  });

  final WalletService? walletService;
  final SensitiveAuthVerifier? authVerifier;
  final ScreenCaptureGuard? screenCaptureGuard;
  final VerificationRandomFactory? randomFactory;
  final Duration revealDuration;

  @override
  State<BackupSeedPhraseScreen> createState() => _BackupSeedPhraseScreenState();
}

class _BackupSeedPhraseScreenState extends State<BackupSeedPhraseScreen>
    with WidgetsBindingObserver {
  late final WalletService _walletService =
      widget.walletService ?? WalletService();
  late final SensitiveAuthVerifier _authVerifier =
      widget.authVerifier ?? SensitiveAccessGuard.verify;
  late final ScreenCaptureGuard _screenCaptureGuard =
      widget.screenCaptureGuard ?? ScreenCaptureGuard();
  late final VerificationRandomFactory _randomFactory =
      widget.randomFactory ?? Random.secure;

  Timer? _autoHideTimer;
  int _revealSession = 0;
  bool _isLoading = false;
  bool _isCheckingAvailability = true;
  bool _seedPhraseUnavailable = false;
  bool _isImportedWallet = false;
  bool _backupVerified = false;
  List<String>? _revealedWords;
  List<String>? _verificationWords;
  SeedPhraseVerificationChallenge? _verificationChallenge;

  bool get _hasRevealedPhrase => _revealedWords != null;
  bool get _isVerifyingBackup => _verificationWords != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_screenCaptureGuard.enableProtection());
    unawaited(_checkSeedPhraseAvailability());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _clearSensitiveState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearSensitiveState(updateUi: false);
    unawaited(_screenCaptureGuard.disableProtection());
    super.dispose();
  }

  void _handleExit() {
    _clearSensitiveState();
  }

  Future<void> _revealSeedPhrase() async {
    if (_isLoading) return;
    final l = AppLocalizations.of(context);
    final sessionId = ++_revealSession;
    _cancelAutoHideTimer();

    setState(() {
      _isLoading = true;
      _backupVerified = false;
      _verificationChallenge = null;
    });

    final authenticated = await _authVerifier(
      context,
      reason: l.authenticateToViewSeedPhrase,
    );
    if (!mounted || sessionId != _revealSession) return;

    if (!authenticated) {
      setState(() => _isLoading = false);
      ToastUtils.showError(l.authenticationRequiredSeedPhrase);
      return;
    }

    final confirmed = await _showRevealWarningDialog(l);
    if (!mounted || sessionId != _revealSession) return;

    if (confirmed != true) {
      setState(() => _isLoading = false);
      return;
    }

    final activeWallet = await _walletService.getActiveWalletAccount();
    final mnemonic = await _walletService.getMnemonic(activeWallet?.address);
    if (!mounted || sessionId != _revealSession) return;

    if (mnemonic == null || mnemonic.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _isCheckingAvailability = false;
        _seedPhraseUnavailable = true;
        _isImportedWallet = false; // It's missing, not necessarily imported
        _clearSensitiveState(updateUi: false);
      });
      return;
    }

    final words = List<String>.from(mnemonic.trim().split(RegExp(r'\s+')));

    setState(() {
      _isLoading = false;
      _seedPhraseUnavailable = false;
      _revealedWords = words;
      _verificationWords = null;
      _verificationChallenge = null;
    });

    _autoHideTimer = Timer(widget.revealDuration, () {
      if (!mounted || sessionId != _revealSession) return;
      _clearSensitiveState();
    });
  }

  Future<void> _checkSeedPhraseAvailability() async {
    try {
      final activeWallet = await _walletService.getActiveWalletAccount();
      final mnemonic = await _walletService.getMnemonic(activeWallet?.address);
      if (!mounted) return;

      final isImported = activeWallet?.origin == WalletOrigin.imported;
      final isMnemonicMissing = mnemonic == null || mnemonic.trim().isEmpty;

      setState(() {
        _isCheckingAvailability = false;
        _seedPhraseUnavailable = isImported || isMnemonicMissing;
        _isImportedWallet = isImported;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingAvailability = false;
      });
    }
  }

  Future<bool?> _showRevealWarningDialog(AppLocalizations l) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.securityWarning,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.seedPhraseMasterKeyWarning,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.seedPhraseSafetyBullets,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.warning,
                height: 1.55,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.cancel,
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l.iUnderstand,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _beginBackupVerification() {
    final revealedWords = _revealedWords;
    if (revealedWords == null) return;
    final challenge = SeedPhraseVerificationChallenge.generate(
      revealedWords,
      random: _randomFactory(),
    );

    _cancelAutoHideTimer();
    setState(() {
      _verificationWords = List<String>.from(revealedWords);
      _verificationChallenge = challenge;
      _wipeWords(_revealedWords);
      _revealedWords = null;
    });
  }

  void _completeBackupVerification() {
    final l = AppLocalizations.of(context);
    _clearSensitiveState(updateUi: false);
    setState(() {
      _backupVerified = true;
    });
    ToastUtils.showSuccess(l.seedPhraseBackupVerified);
  }

  void _clearSensitiveState({bool updateUi = true}) {
    _cancelAutoHideTimer();
    _revealSession++;
    _wipeWords(_revealedWords);
    _wipeWords(_verificationWords);

    if (!updateUi || !mounted) {
      _isLoading = false;
      _revealedWords = null;
      _verificationWords = null;
      _verificationChallenge = null;
      return;
    }

    setState(() {
      _isLoading = false;
      _revealedWords = null;
      _verificationWords = null;
      _verificationChallenge = null;
    });
  }

  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void _wipeWords(List<String>? words) {
    if (words == null) return;
    for (var i = 0; i < words.length; i++) {
      words[i] = '';
    }
  }

  Widget _buildSeedPhraseGrid(List<String> words) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.45,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: Colors.white.withValues(alpha: 0.02),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Text(
                '${index + 1}.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  words[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) => _handleExit(),
      child: MobileScaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            _handleExit();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      Text(
                        l.backupSeedPhraseTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.backupSeedPhraseIntro,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_isCheckingAvailability)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accentRed,
                            ),
                          ),
                        )
                      else if (_seedPhraseUnavailable)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.key_off_rounded,
                                color: AppColors.warning,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isImportedWallet
                                    ? l.noSeedPhraseAvailablePrivateKey
                                    : l.noSeedPhraseStored,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_hasRevealedPhrase)
                        _buildRevealCard(l)
                      else if (_isVerifyingBackup)
                        SeedPhraseBackupVerificationCard(
                          words: _verificationWords!,
                          challenge: _verificationChallenge!,
                          onVerified: _completeBackupVerification,
                        )
                      else
                        _buildHiddenCard(l),
                      if (_backupVerified) ...[
                        const SizedBox(height: 16),
                        _StatusCard(
                          message: l.seedPhraseBackupVerificationComplete,
                          accentColor: AppColors.success,
                          icon: Icons.verified_user_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenCard(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.visibility_off_rounded,
            color: AppColors.textSecondary,
            size: 42,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isLoading ? null : _revealSeedPhrase,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l.tapToReveal,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.seedPhraseSecureScreenNotice,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealCard(AppLocalizations l) {
    final revealedWords = _revealedWords!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          _buildSeedPhraseGrid(revealedWords),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 15,
                    color: AppColors.warning.withValues(alpha: 0.82),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.autoHidesInSeconds(widget.revealDuration.inSeconds),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.warning.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearSensitiveState,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.hide,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentRed,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _beginBackupVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l.iBackedItUp,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeedPhraseBackupVerificationCard extends StatefulWidget {
  const SeedPhraseBackupVerificationCard({
    super.key,
    required this.words,
    required this.challenge,
    required this.onVerified,
  });

  final List<String> words;
  final SeedPhraseVerificationChallenge challenge;
  final VoidCallback onVerified;

  @override
  State<SeedPhraseBackupVerificationCard> createState() =>
      _SeedPhraseBackupVerificationCardState();
}

class _SeedPhraseBackupVerificationCardState
    extends State<SeedPhraseBackupVerificationCard> {
  final Map<int, String> _selectedAnswers = {};
  bool _showError = false;

  void _verifySelections() {
    final isCorrect = widget.challenge.requestedIndices.every(
      (index) => _selectedAnswers[index] == widget.words[index],
    );
    if (isCorrect) {
      widget.onVerified();
      return;
    }

    setState(() {
      _showError = true;
      _selectedAnswers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.seedPhraseVerificationTitle,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.seedPhraseVerificationSubtitle,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (final index in widget.challenge.requestedIndices) ...[
            Text(
              l.selectSeedPhraseWord(index + 1),
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.challenge.options[index]!.map((word) {
                final isSelected = _selectedAnswers[index] == word;
                return ChoiceChip(
                  key: ValueKey('seed-word-$index-$word'),
                  label: Text(word),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _showError = false;
                      _selectedAnswers[index] = word;
                    });
                  },
                  selectedColor: AppColors.accentRed,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  labelStyle: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],
          if (_showError)
            Text(
              l.seedPhraseVerificationFailed,
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.error),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey('verify-backup-button'),
              onPressed:
                  _selectedAnswers.length ==
                      widget.challenge.requestedIndices.length
                  ? _verifySelections
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l.verifyBackup,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeedPhraseVerificationChallenge {
  const SeedPhraseVerificationChallenge({
    required this.requestedIndices,
    required this.options,
  });

  final List<int> requestedIndices;
  final Map<int, List<String>> options;

  static SeedPhraseVerificationChallenge generate(
    List<String> words, {
    required Random random,
  }) {
    final requestedCount = words.length <= 3 ? words.length : 3;
    final indices = List<int>.generate(words.length, (index) => index)
      ..shuffle(random);
    final requestedIndices = (indices.take(requestedCount).toList()..sort());

    final options = <int, List<String>>{};
    for (final index in requestedIndices) {
      options[index] = _buildOptions(
        words,
        correctIndex: index,
        random: random,
      );
    }

    return SeedPhraseVerificationChallenge(
      requestedIndices: requestedIndices,
      options: options,
    );
  }

  static List<String> _buildOptions(
    List<String> words, {
    required int correctIndex,
    required Random random,
  }) {
    final correctWord = words[correctIndex];
    final distractorPool =
        words.where((word) => word != correctWord).toSet().toList()
          ..shuffle(random);
    final optionCount = distractorPool.length >= 3
        ? 4
        : distractorPool.length + 1;
    final options = <String>[
      correctWord,
      ...distractorPool.take(optionCount - 1),
    ]..shuffle(random);
    return options;
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.message,
    this.accentColor = AppColors.textSecondary,
    this.icon = Icons.info_outline_rounded,
  });

  final String message;
  final Color accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
