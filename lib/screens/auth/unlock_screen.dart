import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../utils/toast_utils.dart';
import '../../l10n/app_localizations.dart';

/// Unlock Screen
/// Shows when app is reopened - requires passcode or biometric to unlock
/// Includes brute-force protection: locks out after 5 failed attempts for 30s
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final StorageService _storage = StorageService();
  final BiometricService _biometric = BiometricService();

  String _passcode = '';
  final int _passcodeLength = 6;
  bool _isError = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  // Brute-force protection
  bool _isLockedOut = false;
  int _failedAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;
  bool _navigated = false;
  bool _returnToPrevious = false;

  @override
  void initState() {
    super.initState();
    _checkLockoutAndBiometric();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _returnToPrevious = args?['returnToPrevious'] == true;
  }

  Future<void> _checkLockoutAndBiometric() async {
    // Check lockout status first
    final lockoutTime = await _storage.getLockoutUntil();
    final failedAttempts = await _storage.getFailedAttempts();

    if (lockoutTime != null) {
      _startLockoutCountdown(lockoutTime);
    }

    setState(() {
      _failedAttempts = failedAttempts;
    });

    // Check biometric
    final available = await _biometric.canCheckBiometrics();
    final enabled = await _storage.isBiometricEnabled();

    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });

    // Auto-trigger biometric if available, enabled, and not locked out
    if (_biometricAvailable && _biometricEnabled && !_isLockedOut) {
      _authenticateWithBiometric();
    }
  }

  void _startLockoutCountdown(DateTime lockoutUntil) {
    setState(() {
      _isLockedOut = true;
      _lockoutSecondsRemaining = lockoutUntil
          .difference(DateTime.now())
          .inSeconds;
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutSecondsRemaining--;
      });
      if (_lockoutSecondsRemaining <= 0) {
        timer.cancel();
        setState(() {
          _isLockedOut = false;
          _failedAttempts = 0;
        });
        _storage.resetFailedAttempts();
      }
    });
  }

  Future<void> _authenticateWithBiometric() async {
    final l = AppLocalizations.of(context);
    try {
      final authenticated = await _biometric.authenticate(
        localizedReason: l.unlockWalletReason,
      );

      if (authenticated && mounted && !_navigated) {
        _navigated = true;
        await _storage.resetFailedAttempts();
        if (mounted) {
          if (_returnToPrevious) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushReplacementNamed(context, '/shell');
          }
        }
      }
    } catch (e) {
      // Biometric failed, user can enter passcode
    }
  }

  void _onNumberPressed(String number) {
    if (_isLockedOut) return;

    if (_passcode.length < _passcodeLength) {
      setState(() {
        _passcode += number;
        _isError = false;
      });

      if (_passcode.length == _passcodeLength) {
        _verifyPasscode();
      }
    }
  }

  void _onBackspacePressed() {
    if (_passcode.isNotEmpty) {
      setState(() {
        _passcode = _passcode.substring(0, _passcode.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPasscode() async {
    final l = AppLocalizations.of(context);
    final isValid = await _storage.verifyPasscode(_passcode);

    if (isValid && mounted && !_navigated) {
      // Correct passcode — reset attempts and navigate
      _navigated = true;
      await _storage.resetFailedAttempts();
      if (mounted) {
        if (_returnToPrevious) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacementNamed(context, '/shell');
        }
      }
    } else if (mounted) {
      // Wrong passcode
      await _storage.incrementFailedAttempts();
      final attempts = await _storage.getFailedAttempts();

      setState(() {
        _isError = true;
        _passcode = '';
        _failedAttempts = attempts;
      });

      if (attempts >= StorageService.maxFailedAttempts) {
        // Lock out the user
        await _storage.setLockout();
        final lockoutUntil = await _storage.getLockoutUntil();
        if (lockoutUntil != null) {
          _startLockoutCountdown(lockoutUntil);
        }

        if (mounted) {
          ToastUtils.showError(
            l.tooManyAttemptsLocked(StorageService.lockoutDurationSeconds),
          );
        }
      } else {
        final remaining = StorageService.maxFailedAttempts - attempts;
        if (mounted) {
          ToastUtils.showError(l.incorrectPasscodeRemaining(remaining));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // Logo
            Image.asset('assets/images/logo.png', width: 80, height: 80),

            const SizedBox(height: 20),

            // Title
            Text(
              'Owllet',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 40),

            // Instruction or lockout message
            // Show remaining attempts if failed but not locked
            if (_failedAttempts > 0 && !_isLockedOut)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.attemptsRemaining(
                    StorageService.maxFailedAttempts - _failedAttempts,
                  ),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.warning,
                  ),
                ),
              ),
            if (_isLockedOut)
              Column(
                children: [
                  const Icon(
                    Icons.lock_clock,
                    color: AppColors.error,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.lockedOutTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.unlockTryAgainIn(_lockoutSecondsRemaining),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              )
            else
              Text(
                l.unlockEnterPasscode,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),

            const SizedBox(height: 30),

            // Passcode dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _passcodeLength,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _passcode.length
                        ? (_isError ? AppColors.error : AppColors.primaryAccent)
                        : Colors.white.withValues(alpha: 0.3),
                    border: Border.all(
                      color: _isError
                          ? AppColors.error
                          : (index < _passcode.length
                                ? AppColors.primaryAccent
                                : Colors.white.withValues(alpha: 0.5)),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Number pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Opacity(
                opacity: _isLockedOut ? 0.3 : 1.0,
                child: AbsorbPointer(
                  absorbing: _isLockedOut,
                  child: Column(
                    children: [
                      // Row 1: 1, 2, 3
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberButton('1'),
                          _buildNumberButton('2'),
                          _buildNumberButton('3'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Row 2: 4, 5, 6
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberButton('4'),
                          _buildNumberButton('5'),
                          _buildNumberButton('6'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Row 3: 7, 8, 9
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberButton('7'),
                          _buildNumberButton('8'),
                          _buildNumberButton('9'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Row 4: Biometric, 0, Backspace
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Biometric button
                          _biometricAvailable && _biometricEnabled
                              ? _buildIconButton(
                                  Icons.fingerprint,
                                  _authenticateWithBiometric,
                                )
                              : const SizedBox(width: 70, height: 70),

                          // 0
                          _buildNumberButton('0'),

                          // Backspace
                          _buildIconButton(
                            Icons.backspace_outlined,
                            _onBackspacePressed,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Center(
          child: Text(
            number,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 28)),
      ),
    );
  }
}
