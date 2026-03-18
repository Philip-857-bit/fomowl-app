import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../constants/app_colors.dart';
import '../../../services/blockchain_service.dart';
import '../../../config/app_environment.dart';
import '../widgets/admin_actions_section.dart';

class AdminActionsScreen extends StatefulWidget {
  final String adminSecret;

  const AdminActionsScreen({super.key, required this.adminSecret});

  @override
  State<AdminActionsScreen> createState() => _AdminActionsScreenState();
}

class _AdminActionsScreenState extends State<AdminActionsScreen> {
  bool _loading = false;
  final TextEditingController _testPushWalletController =
      TextEditingController();
  final TextEditingController _testPushTitleController = TextEditingController(
    text: 'Owllet Admin Test Notification',
  );
  final TextEditingController _testPushMessageController =
      TextEditingController(text: 'This is a test push from admin dashboard.');

  @override
  void dispose() {
    _testPushWalletController.dispose();
    _testPushTitleController.dispose();
    _testPushMessageController.dispose();
    super.dispose();
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

  Map<String, String> _adminHeaders({bool json = false}) {
    return {
      'X-Admin-Secret': widget.adminSecret,
      if (json) 'Content-Type': 'application/json',
    };
  }

  String _extractBackendError(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error;
        }
        if (error != null) {
          return error.toString();
        }
      }
    } catch (_) {
      return fallback;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Actions',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AdminActionsSection(
          onSendTestPush: _sendTestPush,
          walletController: _testPushWalletController,
          titleController: _testPushTitleController,
          messageController: _testPushMessageController,
          isLoading: _loading,
        ),
      ),
    );
  }
}
