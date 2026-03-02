import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'withdrawal_preview_screen.dart';

class WithdrawToBankScreen extends StatefulWidget {
  const WithdrawToBankScreen({super.key});

  @override
  State<WithdrawToBankScreen> createState() => _WithdrawToBankScreenState();
}

class _WithdrawToBankScreenState extends State<WithdrawToBankScreen> {
  final TextEditingController _tokenAmountController = TextEditingController();
  final TextEditingController _fiatAmountController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();

  final String _selectedToken = 'USDT (USDC)';
  final String _selectedFiat = 'NGN (NAIRA)';
  String? _selectedBank;

  final double _exchangeRate = 1500.0;

  @override
  void dispose() {
    _tokenAmountController.dispose();
    _fiatAmountController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _onTokenAmountChanged(String value) {
    if (value.isEmpty) {
      _fiatAmountController.text = '';
      return;
    }
    final amount = double.tryParse(value);
    if (amount != null) {
      final fiatAmount = amount * _exchangeRate;
      _fiatAmountController.text = fiatAmount.toStringAsFixed(0);
    }
  }

  void _onFiatAmountChanged(String value) {
    if (value.isEmpty) {
      _tokenAmountController.text = '';
      return;
    }
    final amount = double.tryParse(value.replaceAll(',', ''));
    if (amount != null) {
      final tokenAmount = amount / _exchangeRate;
      _tokenAmountController.text = tokenAmount.toStringAsFixed(2);
    }
  }

  Future<void> _showSelectBankBottomSheet() async {
    final selectedBank = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SelectBankBottomSheet(),
    );

    if (selectedBank != null) {
      setState(() => _selectedBank = selectedBank);
    }
  }

  void _onWithdraw() {
    if (_tokenAmountController.text.trim().isEmpty) return;
    if (_selectedBank == null) return;
    if (_accountNumberController.text.trim().isEmpty) return;

    // Show preview modal
    showDialog(
      context: context,
      builder: (context) => WithdrawalPreviewDialog(
        bankName: _selectedBank!,
        accountNumber: _accountNumberController.text,
        accountName: 'Ben Obiora Chika', // Mock fetched name
        token: _selectedFiat,
        amount: _fiatAmountController.text,
        fee: '20.00',
        estimatedTime: '~1min',
      ),
    );
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
                  Expanded(
                    child: Text(
                      'Withdraw to Bank',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: Text(
                'Withdraw your token converted to naira directly to your local bank account',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Select Token Section
                    Text(
                      'Select Token',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Conversion Cards Box
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Column(
                          children: [
                            // Top Card (Token)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _selectedToken,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: Colors.white54,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Balance: \$1,401.77',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Amount Input
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _tokenAmountController,
                                      onChanged: _onTokenAmountChanged,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: '0',
                                        hintStyle: GoogleFonts.outfit(
                                          fontSize: 18,
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    margin: const EdgeInsets.only(left: 4),
                                  ),
                                ],
                              ),
                            ),

                            // Bottom Card (Fiat)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(14),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _selectedFiat,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: Colors.white54,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Balance: \$2,102,655',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Amount Input
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _fiatAmountController,
                                      onChanged: _onFiatAmountChanged,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: '0',
                                        hintStyle: GoogleFonts.outfit(
                                          fontSize: 18,
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    margin: const EdgeInsets.only(left: 4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Switch indicator & Exchange rate pill
                        Positioned(
                          left: 16,
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.swap_vert,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 40),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentRed.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '\$1 = 1,500',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accentRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Bank Name
                    Text(
                      'Bank Name',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _showSelectBankBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedBank ?? 'Select Bank',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedBank != null
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Bank Account No.
                    Text(
                      'Bank Account No.',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Withdraw Button
                    GestureDetector(
                      onTap: _onWithdraw,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Withdraw funds',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper Bottom Sheet for Selecting Bank
class _SelectBankBottomSheet extends StatefulWidget {
  const _SelectBankBottomSheet();

  @override
  State<_SelectBankBottomSheet> createState() => _SelectBankBottomSheetState();
}

class _SelectBankBottomSheetState extends State<_SelectBankBottomSheet> {
  final List<String> _banks = [
    'First Bank of Nigeria',
    'United Bank of Africa',
    'Zenith Bank',
    'Guaranty Trust Bank',
    'Access Bank',
  ];
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredBanks = _banks
        .where((b) => b.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Close Icon
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search bank name',
                        hintStyle: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              'Select Bank',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    itemCount: filteredBanks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 32),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () =>
                            Navigator.pop(context, filteredBanks[index]),
                        child: Text(
                          filteredBanks[index],
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                // Indicator line
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.white.withValues(alpha: 0.5),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
