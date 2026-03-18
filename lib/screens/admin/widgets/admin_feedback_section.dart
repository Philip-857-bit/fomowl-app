import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';

class AdminFeedbackSection extends StatefulWidget {
  final List<dynamic> feedbackItems;
  final Function(String) onFilterChanged;
  final VoidCallback onSearch;

  const AdminFeedbackSection({
    Key? key,
    required this.feedbackItems,
    required this.onFilterChanged,
    required this.onSearch,
  }) : super(key: key);

  @override
  State<AdminFeedbackSection> createState() => _AdminFeedbackSectionState();
}

class _AdminFeedbackSectionState extends State<AdminFeedbackSection> {
  late TextEditingController _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            controller: _filterController,
            onChanged: widget.onFilterChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Filter by wallet (optional)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              suffixIcon: IconButton(
                onPressed: widget.onSearch,
                icon: const Icon(Icons.search, color: Colors.white70),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.feedbackItems.isEmpty)
            Text(
              'No feedback found.',
              style: GoogleFonts.outfit(color: Colors.white54),
            )
          else
            ..._buildFeedbackItems(),
        ],
      ),
    );
  }

  List<Widget> _buildFeedbackItems() {
    return widget.feedbackItems.take(10).map((item) {
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
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              createdAt,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      );
    }).toList();
  }
}
