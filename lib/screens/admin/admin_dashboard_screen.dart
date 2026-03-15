import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../constants/app_colors.dart';
import '../../services/blockchain_service.dart';
import '../../config/app_environment.dart';
import '../../widgets/token_icon.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String adminSecret;

  const AdminDashboardScreen({super.key, required this.adminSecret});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _registryTokens = [];
  String _searchQuery = '';
  final TextEditingController _pushTitleController = TextEditingController();
  final TextEditingController _pushMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchStats(), _fetchRegistry()]);
    setState(() => _loading = false);
  }

  Future<void> _fetchStats() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = Uri.parse(
        '${AppEnvironment.blockchain('')}/${blockchain.activeChain.chainId}/admin/stats',
      );
      final response = await http.get(
        url,
        headers: {'X-Owllet-Admin-Key': widget.adminSecret},
      );
      if (response.statusCode == 200) {
        setState(() => _stats = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Failed to fetch admin stats: $e');
    }
  }

  Future<void> _fetchRegistry() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      // Re-use token-search with an empty query to get common tokens,
      // or we could add a dedicated /admin/registry/list endpoint.
      // For now, let's use the public search but we'll filter certified status.
      final url = Uri.parse(
        '${AppEnvironment.blockchain('')}/${blockchain.activeChain.chainId}/token-search?q=$_searchQuery&limit=50',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _registryTokens = data['tokens'] ?? []);
      }
    } catch (e) {
      debugPrint('Failed to fetch registry: $e');
    }
  }

  Future<void> _toggleVerification(dynamic token, bool verify) async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = Uri.parse(
        '${AppEnvironment.blockchain('')}/${blockchain.activeChain.chainId}/admin/registry/batch',
      );
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Owllet-Admin-Key': widget.adminSecret,
        },
        body: jsonEncode({
          'updates': [
            {
              'chainId': blockchain.activeChain.chainId,
              'contractAddress': token['contractAddress'],
              'isCertified': verify,
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _fetchRegistry();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verify ? 'Token Verified' : 'Token Unverified'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update registry')),
      );
    }
  }

  Future<void> _sendBroadcast() async {
    if (_pushTitleController.text.isEmpty ||
        _pushMessageController.text.isEmpty)
      return;

    setState(() => _loading = true);
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = Uri.parse(
        '${AppEnvironment.blockchain('')}/${blockchain.activeChain.chainId}/admin/broadcast',
      );
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Owllet-Admin-Key': widget.adminSecret,
        },
        body: jsonEncode({
          'title': _pushTitleController.text,
          'message': _pushMessageController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        final data = jsonDecode(response.body);
        _pushTitleController.clear();
        _pushMessageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Broadcast sent to ~${data['estimatedRecipients']} devices',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Broadcast failed')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Owllet Control Center',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentRed),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHealthSection(),
                  const SizedBox(height: 24),
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  _buildPushSection(),
                  const SizedBox(height: 24),
                  _buildRegistrySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHealthSection() {
    final health = _stats?['health'] ?? {};
    final isHealthy = health['status'] == 'healthy';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.warning,
            color: isHealthy ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Status: ${health['status']?.toUpperCase() ?? 'UNKNOWN'}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Backend Latency: ${health['latencyMs'] ?? '??'}ms',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final s = _stats?['stats'] ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Performance',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard('DAU', s['dau']?.toString() ?? '0', Icons.people),
            const SizedBox(width: 12),
            _buildStatCard(
              'Total Users',
              s['totalUsers']?.toString() ?? '0',
              Icons.person_add,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Transactions',
          s['totalTransactions']?.toString() ?? '0',
          Icons.swap_horiz,
          wide: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, {
    bool wide = false,
  }) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accentRed, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPushSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Broadcast',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pushTitleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Notification Title',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pushMessageController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Message Body',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sendBroadcast,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
              ),
              child: const Text('Send to All Users'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Token Registry',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (val) {
            _searchQuery = val;
            _fetchRegistry();
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search Registry...',
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _registryTokens.length,
          itemBuilder: (context, index) {
            final t = _registryTokens[index];
            final isCertified = t['isCertified'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: TokenIcon(
                  tokenSymbol: t['symbol'] ?? '?',
                  tokenImageUrl: t['imageUrl'],
                  tokenAddress: t['contractAddress'],
                  size: 32,
                  isCertified: isCertified,
                ),
                title: Text(
                  t['name'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  t['symbol'] ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: Switch(
                  value: isCertified,
                  activeThumbColor: Colors.green,
                  onChanged: (val) => _toggleVerification(t, val),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
