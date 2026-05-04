import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/mobile_scaffold.dart';

/// Create Passcode Screen
/// User creates a 6-digit PIN for wallet security
class CreatePasscodeScreen extends StatefulWidget {
  const CreatePasscodeScreen({super.key});

  @override
  State<CreatePasscodeScreen> createState() => _CreatePasscodeScreenState();
}

class _CreatePasscodeScreenState extends State<CreatePasscodeScreen> {
  String _passcode = '';
  static const int _minLength = 6;
  static const int _maxLength = 12;
  String? _mode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _mode ??= args['mode']?.toString();
    }
  }

  void _onNumberPressed(String number) {
    if (_passcode.length < _maxLength) {
      setState(() => _passcode += number);
    }
  }

  void _onDonePressed() {
    if (_passcode.length >= _minLength) {
      Navigator.pushNamed(
        context,
        '/confirm-passcode',
        arguments: {'passcode': _passcode, 'mode': _mode},
      );
    }
  }

  void _onDeletePressed() {
    if (_passcode.isNotEmpty) {
      setState(() => _passcode = _passcode.substring(0, _passcode.length - 1));
    }
  }

  int _strengthBars() {
    final len = _passcode.length;
    if (len == 0) return 0;
    if (len <= 2) return 1;
    if (len <= 3) return 2;
    if (len <= 5) return 3;
    return 4;
  }

  String _strengthLabel() {
    switch (_strengthBars()) {
      case 1:
        return 'WEAK';
      case 2:
        return 'FAIR';
      case 3:
        return 'GOOD';
      default:
        return 'STRONG';
    }
  }

  Color _strengthColor() {
    switch (_strengthBars()) {
      case 1:
        return const Color(0xFFEA2A33);
      case 2:
        return const Color(0xFFFF8C00);
      case 3:
        return const Color(0xFFFFD600);
      default:
        return const Color(0xFFEA2A33);
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
                l.createPasscodeTitle,
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
                  l.createPasscodeDescription,
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _passcode.isNotEmpty
                  ? _buildStrengthBar()
                  : const SizedBox(height: 20),
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

  Widget _buildStrengthBar() {
    final bars = _strengthBars();
    final color = _strengthColor();
    return Column(
      children: [
        Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < bars
                      ? color
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Strength',
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 1,
              ),
            ),
            Text(
              _strengthLabel(),
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
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
              child: _passcode.length >= _minLength
                  ? _buildKey(
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Color(0xFFEA2A33),
                        size: 22,
                      ),
                      onTap: _onDonePressed,
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
