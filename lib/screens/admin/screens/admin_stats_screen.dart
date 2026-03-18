import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../constants/app_colors.dart';
import '../../../services/blockchain_service.dart';
import '../../../config/app_environment.dart';
import '../widgets/admin_stats_section.dart';

class AdminStatsScreen extends StatefulWidget {
  final String adminSecret;

  const AdminStatsScreen({super.key, required this.adminSecret});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _ops;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchStats(), _fetchOps()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchStats() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/stats',
      );
      final response = await http.get(url, headers: _adminHeaders());

      if (response.statusCode == 200 && mounted) {
        setState(() => _stats = jsonDecode(response.body));
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _fetchOps() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/ops',
      );
      final response = await http.get(url, headers: _adminHeaders());

      if (response.statusCode == 200 && mounted) {
        setState(() => _ops = jsonDecode(response.body));
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Map<String, String> _adminHeaders() {
    return {'X-Admin-Secret': widget.adminSecret};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Statistics',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentRed),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AdminStatsSection(stats: _stats, ops: _ops),
            ),
    );
  }
}
