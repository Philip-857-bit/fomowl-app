import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../widgets/bottom_navigation.dart';
import '../profile/coming_soon_overlay.dart';

class EarnComingSoonScreen extends StatelessWidget {
  const EarnComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ComingSoonOverlay(
      title: 'Earn',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: const SizedBox.expand(),
        bottomNavigationBar: const BottomNavBar(currentTab: null),
      ),
    );
  }
}
