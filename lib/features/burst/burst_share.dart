import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareBurstCode(BuildContext context, String code) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join my Burst in Owllet with code: $code',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open sharing. Try copying the code.'),
        ),
      );
    }
  }
}
