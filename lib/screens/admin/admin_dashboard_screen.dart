import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../constants/app_colors.dart';
import '../../services/blockchain_service.dart';
import '../../services/wallet_service.dart';
import '../../config/app_environment.dart';
import '../../l10n/app_localizations.dart';
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
  Map<String, dynamic>? _ops;
  List<dynamic> _registryTokens = [];
  List<dynamic> _maintainers = [];
  List<dynamic> _feedbackItems = [];
  final WalletService _walletService = WalletService();
  String _backendBaseUrl = AppEnvironment.backendBaseUrl;
  int? _activeChainId;
  String? _adminWalletAddress;
  String? _lastAdminError;
  String _feedbackWalletFilter = '';
  String _searchQuery = '';
  final TextEditingController _pushTitleController = TextEditingController();
  final TextEditingController _pushMessageController = TextEditingController();
  final TextEditingController _maintainerAddressController =
      TextEditingController();
  final TextEditingController _maintainerNameController =
      TextEditingController();
  final TextEditingController _testPushWalletController =
      TextEditingController();
  final TextEditingController _testPushTitleController = TextEditingController(
    text: 'Owllet Admin Test Notification',
  );
  final TextEditingController _testPushMessageController =
      TextEditingController(text: 'This is a test push from admin dashboard.');

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _pushTitleController.dispose();
    _pushMessageController.dispose();
    _maintainerAddressController.dispose();
    _maintainerNameController.dispose();
    _testPushWalletController.dispose();
    _testPushTitleController.dispose();
    _testPushMessageController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await _loadAdminContext();
    await Future.wait([
      _fetchStats(),
      _fetchOps(),
      _fetchRegistry(),
      _fetchMaintainers(),
      _fetchFeedback(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadAdminContext() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (!mounted) return;
    setState(() {
      _backendBaseUrl = AppEnvironment.backendBaseUrl;
      _activeChainId = blockchain.activeChain.chainId;
      _adminWalletAddress = walletAddress;
    });
  }

  Map<String, String> _adminHeaders({bool json = false}) {
    final headers = <String, String>{'X-Owllet-Admin-Key': widget.adminSecret};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  String _extractBackendError(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final message = (data['message'] ?? data['error'] ?? data['details'])
            ?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return fallback;
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
        setState(() {
          _stats = jsonDecode(response.body);
          _lastAdminError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _lastAdminError = _extractBackendError(
            response,
            'Failed to fetch admin stats (HTTP ${response.statusCode})',
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch admin stats: $e');
      if (!mounted) return;
      setState(() => _lastAdminError = 'Failed to fetch admin stats: $e');
    }
  }

  Future<void> _fetchOps() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/ops',
      );
      final response = await http.get(url, headers: _adminHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() => _ops = data);
      }
    } catch (e) {
      debugPrint('Failed to fetch admin ops overview: $e');
    }
  }

  Future<void> _fetchFeedback() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final query = <String, String>{'limit': '50'};
      if (_feedbackWalletFilter.trim().isNotEmpty) {
        query['walletAddress'] = _feedbackWalletFilter.trim();
      }
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/feedback',
        query,
      );
      final response = await http.get(url, headers: _adminHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(
          () => _feedbackItems = data['feedback'] as List<dynamic>? ?? [],
        );
      }
    } catch (e) {
      debugPrint('Failed to fetch admin feedback feed: $e');
    }
  }

  Future<void> _fetchRegistry() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/token-search',
        {'q': _searchQuery, 'limit': '50'},
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() => _registryTokens = data['tokens'] ?? []);
      }
    } catch (e) {
      debugPrint('Failed to fetch registry: $e');
    }
  }

  Future<void> _fetchMaintainers() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/maintainers',
      );
      final response = await http.get(url, headers: _adminHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() => _maintainers = data['maintainers'] ?? []);
      }
    } catch (e) {
      debugPrint('Failed to fetch maintainers: $e');
    }
  }

  Future<void> _addMaintainer() async {
    final l = AppLocalizations.of(context);
    final address = _maintainerAddressController.text.trim();
    final name = _maintainerNameController.text.trim();
    if (address.isEmpty) return;

    setState(() => _loading = true);
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/maintainers',
      );
      final response = await http.post(
        url,
        headers: _adminHeaders(json: true),
        body: jsonEncode({
          'walletAddress': address,
          'name': name.isEmpty ? null : name,
        }),
      );

      if (response.statusCode == 200) {
        _maintainerAddressController.clear();
        _maintainerNameController.clear();
        await _fetchMaintainers();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.adminMaintainerAdded)));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.adminMaintainerAddFailed)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.adminMaintainerAddFailed)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deactivateMaintainer(String walletAddress) async {
    if (walletAddress.trim().isEmpty) return;
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/maintainers/$walletAddress',
      );
      final response = await http.delete(url, headers: _adminHeaders());
      if (response.statusCode == 200) {
        await _fetchMaintainers();
      }
    } catch (e) {
      debugPrint('Failed to deactivate maintainer: $e');
    }
  }

  Future<void> _toggleVerification(dynamic token, bool verify) async {
    final l = AppLocalizations.of(context);
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/registry/batch',
      );
      final response = await http.post(
        url,
        headers: _adminHeaders(json: true),
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
            content: Text(
              verify ? l.adminTokenVerified : l.adminTokenUnverified,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.adminRegistryUpdateFailed)));
    }
  }

  Future<void> _sendBroadcast() async {
    final l = AppLocalizations.of(context);
    if (_pushTitleController.text.isEmpty ||
        _pushMessageController.text.isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/broadcast',
      );
      final response = await http.post(
        url,
        headers: _adminHeaders(json: true),
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
              data['estimatedRecipients'] != null
                  ? l.adminBroadcastSentToDevices(
                      data['estimatedRecipients'].toString(),
                    )
                  : l.adminBroadcastSent,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.adminBroadcastFailed)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendTestPush() async {
    final walletAddress = _testPushWalletController.text.trim().toLowerCase();
    final title = _testPushTitleController.text.trim();
    final message = _testPushMessageController.text.trim();

    if (walletAddress.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet address is required.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = AppEnvironment.blockchain(
        '/${blockchain.activeChain.chainId}/admin/actions/test-push',
      );
      final response = await http.post(
        url,
        headers: _adminHeaders(json: true),
        body: jsonEncode({
          'walletAddress': walletAddress,
          'title': title,
          'message': message,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sent = data['pushSent']?.toString() ?? '0';
        final failed = data['pushFailed']?.toString() ?? '0';
        final devices = data['deviceTokens']?.toString() ?? '0';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test push queued. devices=$devices sent=$sent failed=$failed',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_extractBackendError(response, 'Test push failed.')),
          ),
        );
      }

      await _fetchOps();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Test push failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
          l.adminControlCenter,
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
                  _buildOpsSection(),
                  const SizedBox(height: 24),
                  _buildFeedbackSection(),
                  const SizedBox(height: 24),
                  _buildMaintainersSection(),
                  const SizedBox(height: 24),
                  _buildAdminActionsSection(),
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
    final l = AppLocalizations.of(context);
    final status = (_stats?['health'] ?? _stats?['status'] ?? 'unknown')
        .toString();
    final latency = (_stats?['latencyMs'] ?? _stats?['latency_ms'] ?? '??')
        .toString();
    final isHealthy = status.toLowerCase() == 'healthy';

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
                  '${l.adminSystemStatus}: ${status.toUpperCase()}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${l.adminBackendLatency}: ${latency}ms',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chain: ${_activeChainId ?? '--'} | Wallet: ${_adminWalletAddress ?? '--'}',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Backend: $_backendBaseUrl',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                if (_lastAdminError != null && _lastAdminError!.isNotEmpty)
                  Text(
                    _lastAdminError!,
                    style: GoogleFonts.outfit(
                      color: Colors.orange,
                      fontSize: 12,
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
    final l = AppLocalizations.of(context);
    final s = _stats ?? const <String, dynamic>{};
    final activity =
        (_ops?['activity'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.adminAppPerformance,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              l.adminRegistryTokens,
              (s['token_registry_size'])?.toString() ?? '0',
              Icons.local_offer_outlined,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              l.adminTotalUsers,
              (s['totalUsers'] ?? s['users_count'])?.toString() ?? '0',
              Icons.person_add,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              l.adminTransactions,
              (s['totalTransactions'] ?? s['transactions_24h'])?.toString() ??
                  '0',
              Icons.swap_horiz,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              l.adminMaintainers,
              (s['maintainers_count'])?.toString() ?? '0',
              Icons.verified_user,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              'RPS (est)',
              ((activity['estimatedEventsPerSecond'] ?? 0.0) as num)
                  .toStringAsFixed(2),
              Icons.speed,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'RPM (est)',
              (activity['estimatedEventsPerMinute'] ?? 0).toString(),
              Icons.timer,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpsSection() {
    final activity =
        (_ops?['activity'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final errorSignals =
        (_ops?['errorSignals'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final limits =
        (_ops?['rateLimits'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final push =
        (_ops?['push'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

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
            'Ops, Errors & Throughput',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Events: ${activity['estimatedEventsPerSecond'] ?? 0} / sec, ${activity['estimatedEventsPerMinute'] ?? 0} / min',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
          Text(
            'Feedback/min: ${activity['feedbackLastMinute'] ?? 0} | Notifications/min: ${activity['notificationsLastMinute'] ?? 0} | Tx/min: ${activity['transactionsLastMinute'] ?? 0}',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
          Text(
            'Configured limit: ${limits['configuredRequestsPerSecond'] ?? 0} rps (burst ${limits['configuredBurstSize'] ?? 0})',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Error signals (feedback, 24h): ${errorSignals['feedbackErrorSignals24h'] ?? 0}',
            style: GoogleFonts.outfit(color: Colors.orange, fontSize: 13),
          ),
          Text(
            'FCM: enabled=${push['fcmEnabled'] ?? false}, configured=${push['fcmConfigured'] ?? false}, devices=${push['registeredDevices'] ?? 0}',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
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
            'Feedback Queue',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => _feedbackWalletFilter = value,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Filter by wallet (optional)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              suffixIcon: IconButton(
                onPressed: _fetchFeedback,
                icon: const Icon(Icons.search, color: Colors.white70),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_feedbackItems.isEmpty)
            Text(
              'No feedback found.',
              style: GoogleFonts.outfit(color: Colors.white54),
            )
          else
            ..._feedbackItems.take(10).map((item) {
              final wallet = item['walletAddress']?.toString() ?? '--';
              final category = item['category']?.toString() ?? 'general';
              final message = item['message']?.toString() ?? '';
              final createdAt = item['createdAt']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$category | $wallet',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt,
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminActionsSection() {
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
            'Administrative Actions',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testPushWalletController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Wallet for test push',
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
            controller: _testPushTitleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Push title',
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
            controller: _testPushMessageController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Push message',
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
            child: ElevatedButton.icon(
              onPressed: _sendTestPush,
              icon: const Icon(Icons.send),
              label: const Text('Send Test Push'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, {
    bool wide = false,
    bool useExpanded = true,
  }) {
    final card = Container(
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
    );
    if (!useExpanded) return card;
    return Expanded(flex: wide ? 2 : 1, child: card);
  }

  Widget _buildPushSection() {
    final l = AppLocalizations.of(context);
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
            l.adminGlobalBroadcast,
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
              hintText: l.adminNotificationTitleHint,
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
              hintText: l.adminMessageBodyHint,
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
              child: Text(l.adminSendToAllUsers),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintainersSection() {
    final l = AppLocalizations.of(context);
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
            l.adminMaintainers,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maintainerAddressController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l.adminWalletAddressHint,
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
            controller: _maintainerNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l.adminNameOptionalHint,
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
              onPressed: _addMaintainer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
              ),
              child: Text(l.adminAddMaintainer),
            ),
          ),
          if (_maintainers.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._maintainers.map((maintainer) {
              final walletAddress =
                  maintainer['walletAddress']?.toString() ?? '--';
              final name = maintainer['name']?.toString();
              final isActive = maintainer['isActive'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isActive ? Icons.verified_user : Icons.block,
                  color: isActive ? Colors.green : Colors.orange,
                ),
                title: Text(
                  name == null || name.isEmpty ? walletAddress : name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  walletAddress,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: isActive
                    ? IconButton(
                        onPressed: () => _deactivateMaintainer(walletAddress),
                        icon: const Icon(
                          Icons.person_off,
                          color: Colors.orange,
                        ),
                      )
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildRegistrySection() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.adminTokenRegistry,
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
            hintText: l.adminSearchRegistryHint,
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
                  chainId: Provider.of<BlockchainService>(
                    context,
                    listen: false,
                  ).activeChain.chainId,
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
