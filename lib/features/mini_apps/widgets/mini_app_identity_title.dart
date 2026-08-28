import 'package:flutter/material.dart';

import '../mini_app_definition.dart';

/// Displays the registry-backed identity of a trusted Owllet mini app.
///
/// The launch URL is intentionally not part of this widget so mini-app chrome
/// remains visually distinct from the regular dApp browser.
class MiniAppIdentityTitle extends StatelessWidget {
  const MiniAppIdentityTitle({super.key, required this.definition, this.style});

  final MiniAppDefinition definition;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      definition.title,
      key: const ValueKey<String>('mini-app-identity-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
