import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/electricity_modals.dart';

class ElectricitySuppliersScreen extends StatelessWidget {
  const ElectricitySuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock list of suppliers matching the mockup
    final List<Map<String, dynamic>> suppliers = [
      {
        'name': 'Kaduna Supplier',
        'color': Colors.white,
        'textColor': Colors.black,
        'short': 'ke',
      },
      {
        'name': 'Ibadan Supplier',
        'color': const Color(0xFF00529F),
        'textColor': Colors.white,
        'short': 'IBEDC',
      },
      {
        'name': 'Eko Supplier',
        'color': Colors.white,
        'textColor': const Color(0xFF003087),
        'short': 'EKEDC',
      },
      {
        'name': 'Jos Supplier',
        'color': Colors.white,
        'textColor': Colors.orange,
        'short': 'JOS',
      },
      {
        'name': 'Port harcourt Supplier',
        'color': Colors.white,
        'textColor': Colors.green,
        'short': 'PHED',
      },
      {
        'name': 'Abuja Supplier',
        'color': Colors.white,
        'textColor': const Color(0xFF003087),
        'short': 'AEDC',
      },
      {
        'name': 'Ikeja Supplier',
        'color': Colors.white,
        'textColor': Colors.red,
        'short': 'IE',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Electricity Suppliers',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance centering
                ],
              ),
            ),

            // List of suppliers
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: suppliers.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.white.withValues(alpha: 0.05),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return InkWell(
                    onTap: () async {
                      final type = await showDialog<String>(
                        context: context,
                        builder: (context) => const ElectricityTypeDialog(),
                      );
                      
                      if (type != null && context.mounted) {
                        Navigator.pushNamed(
                          context,
                          '/bill-payment',
                          arguments: {
                            'providerName': supplier['name'],
                            'category': 'electricity',
                            'providerColor': supplier['color'],
                            'providerTextColor': supplier['textColor'],
                            'electricityType': type,
                          },
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: supplier['color'],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                supplier['short'],
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: supplier['textColor'],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            supplier['name'],
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
