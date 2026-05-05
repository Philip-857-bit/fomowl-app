import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  static const int _minLength = 6;
  static const int _maxLength = 12;
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
    if (_passcode.length < _maxLength) {
      setState(() => _passcode += number);
    }
  }

  bool get _canConfirm {
    final original = _originalPasscode;
    if (original != null) return _passcode.length == original.length;
    return _passcode.length >= _minLength;
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFFEA2A33),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                l.confirmPasscodeTitle,
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  l.confirmPasscodeDescription,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFD2D0D0),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Confirm Pin',
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
                  border: Border.all(color: const Color(0xFF222121)),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  '●' * _passcode.length,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _buildNumberPad(),
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
              child: _canConfirm
                  ? _buildKey(
                      child: _isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFEA2A33),
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward,
                              color: Color(0xFFEA2A33),
                              size: 22,
                            ),
                      onTap: _isVerifying ? () {} : _verifyPasscode,
                    )
                  : const SizedBox(),
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
                onTap: _onDeletePressed,
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
