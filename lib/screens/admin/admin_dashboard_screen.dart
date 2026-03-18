import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'screens/admin_overview_screen.dart';
import 'screens/admin_stats_screen.dart';
import 'screens/admin_ops_screen.dart';
import 'screens/admin_feedback_screen.dart';
import 'screens/admin_actions_screen.dart';
import 'screens/admin_push_screen.dart';
import 'screens/admin_maintainers_screen.dart';
import 'screens/admin_registry_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String adminSecret;

  const AdminDashboardScreen({super.key, required this.adminSecret});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedTabIndex = 0;

  final List<AdminScreenItem> _screens = [
    AdminScreenItem(label: 'Overview', icon: Icons.dashboard),
    AdminScreenItem(label: 'Stats', icon: Icons.assessment),
    AdminScreenItem(label: 'Ops', icon: Icons.speed),
    AdminScreenItem(label: 'Feedback', icon: Icons.feedback),
    AdminScreenItem(label: 'Actions', icon: Icons.admin_panel_settings),
    AdminScreenItem(label: 'Push', icon: Icons.notifications),
    AdminScreenItem(label: 'Maintainers', icon: Icons.group),
    AdminScreenItem(label: 'Registry', icon: Icons.local_offer),
  ];

  Widget _buildScreen() {
    final screens = [
      AdminOverviewScreen(adminSecret: widget.adminSecret),
      AdminStatsScreen(adminSecret: widget.adminSecret),
      AdminOpsScreen(adminSecret: widget.adminSecret),
      AdminFeedbackScreen(adminSecret: widget.adminSecret),
      AdminActionsScreen(adminSecret: widget.adminSecret),
      AdminPushScreen(adminSecret: widget.adminSecret),
      AdminMaintainersScreen(adminSecret: widget.adminSecret),
      AdminRegistryScreen(adminSecret: widget.adminSecret),
    ];
    return screens[_selectedTabIndex];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${l.adminControlCenter} • ${_screens[_selectedTabIndex].label}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        backgroundColor: AppColors.cardDark,
        selectedItemColor: AppColors.accentRed,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.shifting,
        items: _screens
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
                backgroundColor: AppColors.cardDark,
              ),
            )
            .toList(),
      ),
    );
  }
}

class AdminScreenItem {
  final String label;
  final IconData icon;

  AdminScreenItem({required this.label, required this.icon});
}
