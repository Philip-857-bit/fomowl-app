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
import 'widgets/admin_health_section.dart';
import 'widgets/admin_stats_section.dart';
import 'widgets/admin_ops_section.dart';
import 'widgets/admin_feedback_section.dart';
import 'widgets/admin_actions_section.dart';
import 'widgets/admin_push_section.dart';
import 'widgets/admin_maintainers_section.dart';
import 'widgets/admin_registry_section.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String adminSecret;

  const AdminDashboardScreen({super.key, required this.adminSecret});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  int _selectedTabIndex = 0;
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
              child: _buildTabContent(l),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        backgroundColor: AppColors.cardDark,
        selectedItemColor: AppColors.accentRed,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.shifting,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: 'Overview',
            backgroundColor: AppColors.cardDark,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.assessment),
            label: 'Stats',
            backgroundColor: AppColors.cardDark,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.speed),
            label: 'Ops',
            backgroundColor: AppColors.cardDark,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.feedback),
            label: 'Feedback',
            backgroundColor: AppColors.cardDark,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.admin_panel_settings),
            label: 'Actions',
            backgroundColor: AppColors.cardDark,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.notifications),
            label: 'Push',
            backgroundColor: AppColors.cardDark,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.group),
            label: 'Maintainers',
            backgroundColor: AppColors.cardDark,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_offer),
            label: 'Registry',
            backgroundColor: AppColors.cardDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(AppLocalizations l) {
    switch (_selectedTabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminHealthSection(
              stats: _stats,
              activeChainId: _activeChainId,
              adminWalletAddress: _adminWalletAddress,
              backendBaseUrl: _backendBaseUrl,
              lastError: _lastAdminError,
            ),
          ],
        );
      case 1:
        return AdminStatsSection(stats: _stats, ops: _ops);
      case 2:
        return AdminOpsSection(ops: _ops);
      case 3:
        return AdminFeedbackSection(
          feedbackItems: _feedbackItems,
          onFilterChanged: (value) => _feedbackWalletFilter = value,
          onSearch: _fetchFeedback,
        );
      case 4:
        return AdminActionsSection(
          onSendTestPush: _sendTestPush,
          walletController: _testPushWalletController,
          titleController: _testPushTitleController,
          messageController: _testPushMessageController,
          isLoading: _loading,
        );
      case 5:
        return AdminPushSection(
          onSendBroadcast: _sendBroadcast,
          titleController: _pushTitleController,
          messageController: _pushMessageController,
          isLoading: _loading,
        );
      case 6:
        return AdminMaintainersSection(
          maintainers: _maintainers,
          onAddMaintainer: _addMaintainer,
          onDeactivateMaintainer: _deactivateMaintainer,
          addressController: _maintainerAddressController,
          nameController: _maintainerNameController,
          isLoading: _loading,
        );
      case 7:
        return AdminRegistrySection(
          registryTokens: _registryTokens,
          onToggleVerification: _toggleVerification,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
