import 'package:flutter/material.dart';
class WalletsHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const WalletsHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
