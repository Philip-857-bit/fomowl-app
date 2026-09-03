import 'package:flutter/widgets.dart';

class DiscoverProviderApprovalRequest {
  const DiscoverProviderApprovalRequest({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
}

typedef DiscoverProviderApprovalHandler = Future<bool> Function(
  BuildContext context,
  DiscoverProviderApprovalRequest request,
);
