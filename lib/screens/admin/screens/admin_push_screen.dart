import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../constants/app_colors.dart';
import '../../../services/blockchain_service.dart';
import '../../../config/app_environment.dart';
import '../widgets/admin_push_section.dart';

class AdminPushScreen extends StatefulWidget {
  final String adminSecret;

  const AdminPushScreen({super.key, required this.adminSecret});

  @override
  State<AdminPushScreen> createState() => _AdminPushScreenState();
}

class _AdminPushScreenState extends State<AdminPushScreen> {
  bool _loading = false;
  final TextEditingController _pushTitleController = TextEditingController();
  final TextEditingController _pushMessageController = TextEditingController();

  @override
  void dispose() {
    _pushTitleController.dispose();
    _pushMessageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
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
                  ? 'Broadcast sent to ${data['estimatedRecipients']} devices'
                  : 'Broadcast sent successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Broadcast failed: $e')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Broadcast Push',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AdminPushSection(
          onSendBroadcast: _sendBroadcast,
          titleController: _pushTitleController,
          messageController: _pushMessageController,
          isLoading: _loading,
        ),
      ),
    );
  }
}
