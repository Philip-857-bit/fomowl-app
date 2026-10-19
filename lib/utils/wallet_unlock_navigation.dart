import 'package:flutter/material.dart';

/// Named app routes use `MaterialPageRoute<dynamic>`. Check the returned value
/// rather than requesting a `Route<bool>`, which fails before navigation.
Future<bool> requestWalletUnlock(BuildContext context) async {
  final result = await Navigator.pushNamed<dynamic>(
    context,
    '/unlock',
    arguments: {'returnToPrevious': true},
  );
  return result == true;
}
