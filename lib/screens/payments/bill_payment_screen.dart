import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../utils/toast_utils.dart';

/// Bill Payment Screen — reusable form for Airtime, TV, Electricity
/// Receives provider details via route arguments
class BillPaymentScreen extends StatefulWidget {
  const BillPaymentScreen({super.key});

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedBillType = '';
  Map<String, dynamic>? _args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args ??= ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (_selectedBillType.isEmpty) {
      _selectedBillType = _billTypes.isNotEmpty ? _billTypes.first : '';
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String get _providerName => _args?['providerName'] as String? ?? 'Provider';
  String get _category => _args?['category'] as String? ?? 'airtime';
  Color get _providerColor => _args?['providerColor'] as Color? ?? AppColors.accentRed;
  Color get _providerTextColor => _args?['providerTextColor'] as Color? ?? Colors.white;

  // Dynamic labels & options based on category
  String get _numberLabel {
    switch (_category) {
      case 'tv':
        return 'Decoder IUC Number';
      case 'electricity':
        return 'Meter Number';
      default:
        return 'Phone number';
    }
  }

  String get _numberHint {
    switch (_category) {
      case 'tv':
        return '22565564';
      case 'electricity':
        return '22565564';
      default:
        return '09056543234';
    }
  }

  String get _amountHint {
    switch (_category) {
      case 'airtime':
        return 'NGN100';
      default:
        return 'Amt';
    }
  }

  List<String> get _billTypes {
    switch (_category) {
      case 'tv':
        return ['Select Plan', 'GOtv Max', 'GOtv Jolli', 'GOtv Jinja', 'GOtv Smallie'];
      case 'electricity':
        return ['Pre-paid', 'Post-paid'];
      default:
        return ['Airtime Recharge', 'Data Bundle', 'Special Data'];
    }
  }

  void _onContinue() {
    if (_numberController.text.trim().isEmpty) {
      _showError('Please enter ${_numberLabel.toLowerCase()}');
      return;
    }
    if (_amountController.text.trim().isEmpty && _category != 'tv') {
      _showError('Please enter an amount');
      return;
    }

    // Show processing screen
    Navigator.pushNamed(context, '/transaction-processing');
  }

  void _showError(String message) {
    ToastUtils.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Provider icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _providerColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _providerName.length > 4
                              ? _providerName.substring(0, 3)
                              : _providerName,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _providerTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Provider name
                    Text(
                      _providerName,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Number field
                    Text(
                      _numberLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _numberController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: _numberHint,
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Bill Type dropdown
                    Text(
                      'Bill Type',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        final selected = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => _SelectBillTypeBottomSheet(
                            billTypes: _billTypes,
                          ),
                        );
                        if (selected != null) {
                          setState(() => _selectedBillType = selected);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedBillType.isNotEmpty ? _selectedBillType : 'Select Bill Type',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Amount field
                    Text(
                      'Amount',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: _amountHint,
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: _onContinue,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Continue',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
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

class _SelectBillTypeBottomSheet extends StatelessWidget {
  final List<String> billTypes;

  const _SelectBillTypeBottomSheet({required this.billTypes});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // Balance spacing
                Text(
                  'Select Bill Type',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Options List
          ...billTypes.map((type) {
            return InkWell(
              onTap: () => Navigator.pop(context, type),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 40), // Bottom Padding
        ],
      ),
    );
  }
}
