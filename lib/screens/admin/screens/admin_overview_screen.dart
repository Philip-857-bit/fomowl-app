import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../constants/app_colors.dart';
import '../../../services/blockchain_service.dart';
import '../../../config/app_environment.dart';
import '../widgets/admin_health_section.dart';

class AdminOverviewScreen extends StatefulWidget {
  final String adminSecret;

  const AdminOverviewScreen({super.key, required this.adminSecret});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  bool _loading = true;
  Map<String, dynamic>? _stats;
  final String _backendBaseUrl = AppEnvironment.backendBaseUrl;
  int? _activeChainId;
  String? _adminWalletAddress;
  String? _lastAdminError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadAdminContext();
    await _fetchStats();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAdminContext() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    _activeChainId = blockchain.activeChain.chainId;
  }

  Future<void> _fetchStats() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/stats',
      );
      final response = await http.get(url, headers: _adminHeaders());

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() => _stats = jsonDecode(response.body));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastAdminError = e.toString());
    }
  }

  Map<String, String> _adminHeaders({bool json = false}) {
    return {
      'X-Admin-Secret': widget.adminSecret,
      if (json) 'Content-Type': 'application/json',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Overview',
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
              child: AdminHealthSection(
                stats: _stats,
                activeChainId: _activeChainId,
                adminWalletAddress: _adminWalletAddress,
                backendBaseUrl: _backendBaseUrl,
                lastError: _lastAdminError,
              ),
            ),
    );
  }
}
