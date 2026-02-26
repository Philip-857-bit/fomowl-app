import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeCard extends StatelessWidget {
  final String data;
  final double size;

  const QrCodeCard({
    super.key,
    required this.data,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
