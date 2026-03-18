import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../constants/app_colors.dart';
import '../../../services/blockchain_service.dart';
import '../../../config/app_environment.dart';
import '../widgets/admin_maintainers_section.dart';

class AdminMaintainersScreen extends StatefulWidget {
  final String adminSecret;

  const AdminMaintainersScreen({super.key, required this.adminSecret});

  @override
  State<AdminMaintainersScreen> createState() => _AdminMaintainersScreenState();
}

class _AdminMaintainersScreenState extends State<AdminMaintainersScreen> {
  bool _loading = true;
  List<dynamic> _maintainers = [];
  final TextEditingController _maintainerAddressController =
      TextEditingController();
  final TextEditingController _maintainerNameController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _maintainerAddressController.dispose();
    _maintainerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _fetchMaintainers();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchMaintainers() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/maintainers',
      );
      final response = await http.get(url, headers: _adminHeaders());

      if (response.statusCode == 200 && mounted) {
        setState(() => _maintainers = jsonDecode(response.body) ?? []);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _addMaintainer() async {
    final address = _maintainerAddressController.text.trim().toLowerCase();
    final name = _maintainerNameController.text.trim();

    if (address.isEmpty || name.isEmpty) return;

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/maintainers',
      );
      final response = await http.post(
        url,
        headers: _adminHeaders(json: true),
        body: jsonEncode({'address': address, 'name': name}),
      );

      if (response.statusCode == 200 && mounted) {
        _maintainerAddressController.clear();
        _maintainerNameController.clear();
        await _fetchMaintainers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintainer added successfully')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding maintainer: $e')));
    }
  }

  Future<void> _deactivateMaintainer(String address) async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/maintainers/$address',
      );
      final response = await http.delete(url, headers: _adminHeaders());

      if (response.statusCode == 200 && mounted) {
        await _fetchMaintainers();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Maintainer deactivated')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deactivating maintainer: $e')),
      );
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
          'Maintainers',
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
              child: AdminMaintainersSection(
                maintainers: _maintainers,
                onAddMaintainer: _addMaintainer,
                onDeactivateMaintainer: _deactivateMaintainer,
                addressController: _maintainerAddressController,
                nameController: _maintainerNameController,
                isLoading: _loading,
              ),
            ),
    );
  }
}
