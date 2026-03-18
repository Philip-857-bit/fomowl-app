import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../constants/app_colors.dart';
import '../../../services/blockchain_service.dart';
import '../../../config/app_environment.dart';
import '../widgets/admin_ops_section.dart';

class AdminOpsScreen extends StatefulWidget {
  final String adminSecret;

  const AdminOpsScreen({super.key, required this.adminSecret});

  @override
  State<AdminOpsScreen> createState() => _AdminOpsScreenState();
}

class _AdminOpsScreenState extends State<AdminOpsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _ops;
  List<dynamic> _errorLogs = [];
  int _errorLogsPage = 1;
  final int _errorLogsPageSize = 20;
  bool _errorLogsHasNext = false;
  int _errorLogsTotal = 0;
  bool _loadingErrorLogs = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchOps(), _fetchErrorLogs(page: 1)]);
    if (mounted) setState(() => _loading = false);
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

  Future<void> _fetchErrorLogs({int? page}) async {
    page = page ?? _errorLogsPage;
    if (!mounted) return;
    setState(() => _loadingErrorLogs = true);

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = Uri.parse(
        '${AppEnvironment.backendBaseUrl}/${blockchain.activeChain.chainId}/admin/errors'
        '?page=$page&pageSize=$_errorLogsPageSize',
      );
      final response = await http.get(url, headers: _adminHeaders());

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _errorLogs = data['logs'] ?? [];
          _errorLogsTotal = data['total'] ?? 0;
          _errorLogsPage = page!;
          _errorLogsHasNext = data['hasNext'] ?? false;
        });
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) setState(() => _loadingErrorLogs = false);
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
          'Operations',
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
              child: AdminOpsSection(
                ops: _ops,
                errorLogs: _errorLogs,
                errorLogsPage: _errorLogsPage,
                errorLogsTotal: _errorLogsTotal,
                errorLogsHasNext: _errorLogsHasNext,
                loadingErrorLogs: _loadingErrorLogs,
                onPreviousPage: _errorLogsPage > 1
                    ? () => _fetchErrorLogs(page: _errorLogsPage - 1)
                    : null,
                onNextPage: _errorLogsHasNext
                    ? () => _fetchErrorLogs(page: _errorLogsPage + 1)
                    : null,
              ),
            ),
    );
  }
}
