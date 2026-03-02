import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
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
  final int _passcodeLength = 6;

  void _onNumberPressed(String number) {
    if (_passcode.length < _passcodeLength) {
      setState(() {
        _passcode += number;
      });

      // Auto-navigate when passcode is complete
      if (_passcode.length == _passcodeLength) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pushNamed(
              context,
              '/confirm-passcode',
              arguments: _passcode,
            );
          }
        });
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

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
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

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Create Passcode',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 30),

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
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),

                  // Instruction text
                  Text(
                    'Enter a 6 digit code that only you can\nremember',
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

                  const SizedBox(height: 20),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
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
                onPressed: _passcode.length == _passcodeLength
                    ? () => Navigator.pushNamed(
                        context,
                        '/confirm-passcode',
                        arguments: _passcode,
                      )
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
