import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../constants/app_colors.dart';
import '../../../services/blockchain_service.dart';
import '../../../config/app_environment.dart';
import '../widgets/admin_registry_section.dart';

class AdminRegistryScreen extends StatefulWidget {
  final String adminSecret;

  const AdminRegistryScreen({super.key, required this.adminSecret});

  @override
  State<AdminRegistryScreen> createState() => _AdminRegistryScreenState();
}

class _AdminRegistryScreenState extends State<AdminRegistryScreen> {
  bool _loading = true;
  List<dynamic> _registryTokens = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _fetchRegistry();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchRegistry() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/registry',
      );
      final response = await http.get(url, headers: _adminHeaders());

      if (response.statusCode == 200 && mounted) {
        setState(() => _registryTokens = jsonDecode(response.body) ?? []);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _toggleVerification(dynamic token, bool verify) async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final tokenSymbol = token is String ? token : token['symbol'];
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/registry/$tokenSymbol',
      );
      final response = await http.patch(
        url,
        headers: _adminHeaders(json: true),
        body: jsonEncode({'verified': verify}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _fetchRegistry();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              verify ? '$tokenSymbol verified' : '$tokenSymbol unverified',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating registry: $e')));
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
          'Token Registry',
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
              child: AdminRegistrySection(
                registryTokens: _registryTokens,
                onToggleVerification: _toggleVerification,
              ),
            ),
    );
  }
}
