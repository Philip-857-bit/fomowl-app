import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/storage_service.dart';
import '../../utils/toast_utils.dart';
import '../../l10n/app_localizations.dart';

/// Confirm Passcode Screen
/// User re-enters the 6-digit PIN to confirm
class ConfirmPasscodeScreen extends StatefulWidget {
  const ConfirmPasscodeScreen({super.key});

  @override
  State<ConfirmPasscodeScreen> createState() => _ConfirmPasscodeScreenState();
}

class _ConfirmPasscodeScreenState extends State<ConfirmPasscodeScreen> {
  String _passcode = '';
  String? _originalPasscode;
  String? _mode;
  final int _passcodeLength = 6;
  final StorageService _storage = StorageService();
  bool _isVerifying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _originalPasscode ??= args['passcode'] as String?;
      _mode ??= args['mode']?.toString();
    } else if (args is String) {
      _originalPasscode ??= args;
    }
  }

  void _onNumberPressed(String number) {
    if (_passcode.length < _passcodeLength) {
      setState(() {
        _passcode += number;
      });

      // Auto-verify when passcode is complete
      if (_passcode.length == _passcodeLength && !_isVerifying) {
        _verifyPasscode();
      }
    }
  }

  void _onDeletePressed() {
    if (_passcode.isNotEmpty) {
      setState(() {
        _passcode = _passcode.substring(0, _passcode.length - 1);
      });
    }
  }

  Future<void> _verifyPasscode() async {
    if (_isVerifying) return;
    final l = AppLocalizations.of(context);
    setState(() => _isVerifying = true);
    try {
      if (_passcode == _originalPasscode) {
        await _storage.savePasscode(_passcode);
        if (mounted) {
          if (_mode == 'change') {
            Navigator.popUntil(
              context,
              (route) =>
                  route.isFirst ||
                  route.settings.name == '/password-security' ||
                  route.settings.name == '/profile' ||
                  route.settings.name == '/home' ||
                  route.settings.name == '/shell',
            );
          } else {
            Navigator.pushNamed(context, '/biometric-setup');
          }
        }
        return;
      }

      ToastUtils.showError(l.passcodesDoNotMatch);
      if (mounted) {
        setState(() {
          _passcode = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(l.failedToSavePasscode);
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
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
            // Back button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),

            const SizedBox(height: 40),

            // Title
            Text(
              l.confirmPasscodeTitle,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 40),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_passcodeLength, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: index < _passcode.length
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                  child: Center(
                    child: index < _passcode.length
                        ? const Text(
                            '●',
                            style: TextStyle(fontSize: 22, color: Colors.white),
                          )
                        : null,
                  ),
                );
              }),
            ),

            const SizedBox(height: 30),

            // Instruction text
            Text(
              l.confirmPasscodeDescription,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            // Number pad
            _buildNumberPad(),

            const SizedBox(height: 40),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Row 1: 1, 2, 3
          _buildNumberRow(['1', '2', '3']),
          const SizedBox(height: 20),
          // Row 2: 4, 5, 6
          _buildNumberRow(['4', '5', '6']),
          const SizedBox(height: 20),
          // Row 3: 7, 8, 9
          _buildNumberRow(['7', '8', '9']),
          const SizedBox(height: 20),
          // Row 4: X, 0, >
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberButton(
                child: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: _onDeletePressed,
              ),
              _buildNumberButton(
                child: Text(
                  '0',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                onPressed: () => _onNumberPressed('0'),
              ),
              _buildNumberButton(
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _passcode.length == _passcodeLength && !_isVerifying
                    ? _verifyPasscode
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) {
        return _buildNumberButton(
          child: Text(
            number,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          onPressed: () => _onNumberPressed(number),
        );
      }).toList(),
    );
  }

  Widget _buildNumberButton({
    required Widget child,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 80,
      height: 80,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      ),
    );
  }
}
