import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/bottom_navigation.dart';

/// Payments Screen — "Payment" tab
/// Two tabs: Pay Bills (service providers grid) and Transactions (recent payments)
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Provider categories for Pay Bills tab
  final List<_BillProvider> _airtimeProviders = [
    _BillProvider(
      name: 'MTN',
      color: const Color(0xFFFFCC00),
      textColor: Colors.black,
    ),
    _BillProvider(
      name: '9mobile',
      color: const Color(0xFF006B3F),
      textColor: Colors.white,
    ),
    _BillProvider(
      name: 'Airtel',
      color: const Color(0xFFED1C24),
      textColor: Colors.white,
    ),
    _BillProvider(
      name: 'Glo',
      color: const Color(0xFF50B848),
      textColor: Colors.white,
    ),
  ];

  final List<_BillProvider> _tvProviders = [
    _BillProvider(name: 'GOtv', color: Colors.white, textColor: Colors.black),
    _BillProvider(
      name: 'DStv',
      color: const Color(0xFF003087),
      textColor: Colors.white,
    ),
    _BillProvider(
      name: 'StarTimes',
      color: const Color(0xFFFF6600),
      textColor: Colors.white,
    ),
  ];

  final List<_BillProvider> _electricityProviders = [
    _BillProvider(name: 'Kaduna', color: Colors.white, textColor: Colors.black),
    _BillProvider(
      name: 'IKEDC',
      color: const Color(0xFF00529F),
      textColor: Colors.white,
    ),
    _BillProvider(
      name: 'Eko',
      color: const Color(0xFF009639),
      textColor: Colors.white,
    ),
  ];

  // Mock recent payment transactions
  final List<_PaymentTransaction> _recentPayments = [
    _PaymentTransaction(
      providerName: 'Airtel',
      description: 'Data top -up',
      time: '2 hours ago',
      amount: 40,
      providerColor: const Color(0xFFED1C24),
    ),
    _PaymentTransaction(
      providerName: 'GOtv',
      description: 'Gotv subscription',
      time: '5 hours ago',
      amount: 50,
      providerColor: Colors.white,
      providerTextColor: Colors.black,
    ),
    _PaymentTransaction(
      providerName: 'MTN',
      description: 'Airtime top -up',
      time: '2 hours ago',
      amount: 30,
      providerColor: const Color(0xFFFFCC00),
      providerTextColor: Colors.black,
    ),
    _PaymentTransaction(
      providerName: 'Kaduna',
      description: 'Electricity Bill',
      time: '2 hours ago',
      amount: 30,
      providerColor: Colors.white,
      providerTextColor: Colors.black,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const BottomNavBar(currentTab: null),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Center(
                child: Text(
                  'Payments',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accentRed,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
              labelStyle: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(text: 'Pay Bills'),
                Tab(text: 'Transactions'),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildPayBillsTab(), _buildTransactionsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PAY BILLS TAB ─────────────────────────────
  Widget _buildPayBillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySection('Airtime & Data', _airtimeProviders, 'airtime'),
          const SizedBox(height: 28),
          _buildCategorySection('TV Subscription', _tvProviders, 'tv'),
          const SizedBox(height: 28),
          _buildCategorySection(
            'Electricity',
            _electricityProviders,
            'electricity',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    List<_BillProvider> providers,
    String category,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: providers.map((provider) {
            return GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/bill-payment',
                  arguments: {
                    'providerName': provider.name,
                    'category': category,
                    'providerColor': provider.color,
                    'providerTextColor': provider.textColor,
                  },
                );
              },
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: provider.color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        provider.name.length > 4
                            ? provider.name.substring(0, 3)
                            : provider.name,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: provider.textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.name,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── TRANSACTIONS TAB ──────────────────────────
  Widget _buildTransactionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'Recent Payments',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            separatorBuilder: (_, a) =>
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            itemCount: _recentPayments.length,
            itemBuilder: (context, index) {
              return _buildPaymentItem(_recentPayments[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentItem(_PaymentTransaction tx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Provider icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tx.providerColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                tx.providerName.length > 4
                    ? tx.providerName.substring(0, 3)
                    : tx.providerName,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tx.providerTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Description + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tx.time,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '- \$${tx.amount.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.accentRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillProvider {
  final String name;
  final Color color;
  final Color textColor;

  const _BillProvider({
    required this.name,
    required this.color,
    required this.textColor,
  });
}

class _PaymentTransaction {
  final String providerName;
  final String description;
  final String time;
  final double amount;
  final Color providerColor;
  final Color providerTextColor;

  const _PaymentTransaction({
    required this.providerName,
    required this.description,
    required this.time,
    required this.amount,
    required this.providerColor,
    this.providerTextColor = Colors.white,
  });
}
