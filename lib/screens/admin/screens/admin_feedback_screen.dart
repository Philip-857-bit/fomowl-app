import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../constants/app_colors.dart';
import '../../../services/blockchain_service.dart';
import '../../../config/app_environment.dart';
import '../widgets/admin_feedback_section.dart';

class AdminFeedbackScreen extends StatefulWidget {
  final String adminSecret;

  const AdminFeedbackScreen({super.key, required this.adminSecret});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  bool _loading = true;
  List<dynamic> _feedbackItems = [];
  int _feedbackPage = 1;
  final int _feedbackPageSize = 25;
  bool _feedbackHasNext = false;
  int _feedbackTotal = 0;
  String _feedbackWalletFilter = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _fetchFeedback(page: 1);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchFeedback({int? page}) async {
    page = page ?? _feedbackPage;
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final queryParams = ['page=$page', 'pageSize=$_feedbackPageSize'];
      if (_feedbackWalletFilter.isNotEmpty) {
        queryParams.add('wallet=${Uri.encodeComponent(_feedbackWalletFilter)}');
      }

      final url = Uri.parse(
        '${AppEnvironment.backendBaseUrl}/${blockchain.activeChain.chainId}/admin/feedback'
        '?${queryParams.join('&')}',
      );
      final response = await http.get(url, headers: _adminHeaders());

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _feedbackItems = data['feedback'] ?? [];
          _feedbackTotal = data['total'] ?? 0;
          _feedbackPage = page!;
          _feedbackHasNext = data['hasNext'] ?? false;
        });
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportFeedback(String format) async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final url = Uri.parse(
        '${AppEnvironment.backendBaseUrl}/${blockchain.activeChain.chainId}/admin/feedback'
        '?format=$format&pageSize=10000',
      );
      final response = await http.get(url, headers: _adminHeaders());

      if (!mounted) return;
      if (response.statusCode == 200) {
        await Clipboard.setData(ClipboardData(text: response.body));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${response.body.length} bytes to clipboard',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
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
          'Feedback',
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
              child: AdminFeedbackSection(
                feedbackItems: _feedbackItems,
                page: _feedbackPage,
                pageSize: _feedbackPageSize,
                total: _feedbackTotal,
                hasNext: _feedbackHasNext,
                onFilterChanged: (value) =>
                    setState(() => _feedbackWalletFilter = value),
                onSearch: () => _fetchFeedback(page: 1),
                onPreviousPage: _feedbackPage > 1
                    ? () => _fetchFeedback(page: _feedbackPage - 1)
                    : null,
                onNextPage: _feedbackHasNext
                    ? () => _fetchFeedback(page: _feedbackPage + 1)
                    : null,
                onExportCsv: () => _exportFeedback('csv'),
                onExportJson: () => _exportFeedback('json'),
              ),
            ),
    );
  }
}
