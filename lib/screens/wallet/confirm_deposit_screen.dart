import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/deposit_modals.dart';

class ThirdPartyDepositScreen extends StatefulWidget {
  const ThirdPartyDepositScreen({super.key});

  @override
  State<ThirdPartyDepositScreen> createState() => _ThirdPartyDepositScreenState();
}

class _ThirdPartyDepositScreenState extends State<ThirdPartyDepositScreen> {
  final TextEditingController _payController = TextEditingController(text: '5,000');
  final TextEditingController _receiveController = TextEditingController(text: '3.5');
  
  String _selectedPayCurrency = 'NGN';
  String _selectedReceiveCurrency = 'USDT';
  String _selectedProvider = 'Alchemy Pay';
  String _providerRate = '1507.39 NGN / USDT';

  void _showCurrencySheet(bool isPay) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CurrencyBottomSheet(),
    );

    if (result != null && mounted) {
      setState(() {
        if (isPay) {
          _selectedPayCurrency = result;
        } else {
          _selectedReceiveCurrency = result;
        }
      });
    }
  }

  void _showServiceProviderSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ServiceProviderBottomSheet(),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedProvider = result;
        // Mock rate updates based on provider
        if (result == 'Binance Pay') {
          _providerRate = '1505.20 NGN / USDT';
        } else if (result == 'Google Pay') {
          _providerRate = '1510.50 NGN / USDT';
        } else {
          _providerRate = '1507.39 NGN / USDT';
        }
      });
    }
  }

  @override
  void dispose() {
    _payController.dispose();
    _receiveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Third party deposit',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Pay Section
              Text(
                'Pay',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _buildInputBox(
                controller: _payController,
                currencyCode: _selectedPayCurrency,
                isFiat: true,
                onCurrencyTap: () => _showCurrencySheet(true),
              ),
              
              const SizedBox(height: 24),

              // Receive Section
              Text(
                'Receive',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _buildInputBox(
                controller: _receiveController,
                currencyCode: _selectedReceiveCurrency,
                isFiat: false,
                onCurrencyTap: () => _showCurrencySheet(false),
              ),

              const SizedBox(height: 32),

              // Choose Provider
              Text(
                'Choose a service provider',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showServiceProviderSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getProviderIcon(_selectedProvider), 
                          color: AppColors.background, 
                          size: 18
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedProvider,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _providerRate,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Deposit Button
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/transaction-processing');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Deposit',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox({
    required TextEditingController controller,
    required String currencyCode,
    required bool isFiat,
    required VoidCallback onCurrencyTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white54,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCurrencyTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.transparent, // expand tap area
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFiat ? Colors.green : Colors.teal,
                    ),
                    child: isFiat 
                        ? null 
                        : const Icon(Icons.currency_bitcoin, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currencyCode,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(String provider) {
    if (provider.contains('Binance')) return Icons.currency_bitcoin;
    if (provider.contains('Google')) return Icons.g_mobiledata;
    return Icons.rocket_launch; // Alchemy fallback
  }
}
