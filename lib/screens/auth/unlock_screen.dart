import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  static const int _minLength = 6;
  static const int _maxLength = 12;
  int? _storedPasscodeLength;
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
    // Load stored passcode length so → appears at the right digit count
    final storedLength = await _storage.getPasscodeLength();
    if (mounted) setState(() => _storedPasscodeLength = storedLength);

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

  bool get _readyToSubmit {
    final target = _storedPasscodeLength;
    return target != null
        ? _passcode.length == target
        : _passcode.length >= _minLength;
  }

  void _onNumberPressed(String number) {
    if (_isLockedOut) return;
    if (_passcode.length < _maxLength) {
      setState(() {
        _passcode += number;
        _isError = false;
      });
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 72,
                height: 72,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Owllet',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLockedOut)
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.lock_clock,
                      color: Color(0xFFEA2A33),
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.lockedOutTitle,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEA2A33),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.unlockTryAgainIn(_lockoutSecondsRemaining),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Text(
                  l.unlockEnterPasscode,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFD2D0D0),
                  ),
                ),
              ),
            if (_failedAttempts > 0 && !_isLockedOut)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.attemptsRemaining(
                      StorageService.maxFailedAttempts - _failedAttempts,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFEA2A33),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Enter Pin',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFA3A3A3),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                height: 47,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1B1B),
                  border: Border.all(
                    color: _isError
                        ? const Color(0xFFEA2A33)
                        : const Color(0xFF222121),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  '●' * _passcode.length,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _isError ? const Color(0xFFEA2A33) : Colors.white,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Opacity(
                opacity: _isLockedOut ? 0.3 : 1.0,
                child: AbsorbPointer(
                  absorbing: _isLockedOut,
                  child: _buildNumberPad(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        _buildRow(['4', '5', '6']),
        _buildRow(['7', '8', '9']),
        Row(
          children: [
            Expanded(
              child: _readyToSubmit
                  ? _buildKey(
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Color(0xFFEA2A33),
                        size: 22,
                      ),
                      onTap: _verifyPasscode,
                    )
                  : (_biometricAvailable && _biometricEnabled
                        ? _buildKey(
                            child: const Icon(
                              Icons.fingerprint,
                              color: Colors.white,
                              size: 26,
                            ),
                            onTap: _authenticateWithBiometric,
                          )
                        : const SizedBox()),
            ),
            Expanded(
              child: _buildKey(label: '0', onTap: () => _onNumberPressed('0')),
            ),
            Expanded(
              child: _buildKey(
                child: const Icon(
                  Icons.backspace_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                onTap: _onBackspacePressed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      children: digits
          .map(
            (d) => Expanded(
              child: _buildKey(label: d, onTap: () => _onNumberPressed(d)),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKey({
    String? label,
    Widget? child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Center(
          child:
              child ??
              Text(
                label!,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
        ),
      ),
    );
  }
}
