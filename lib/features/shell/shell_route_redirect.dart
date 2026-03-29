import 'package:flutter/material.dart';

import 'app_shell_controller.dart';

class ShellRouteRedirect extends StatefulWidget {
  const ShellRouteRedirect({super.key, required this.tab});

  final AppShellTab tab;

  @override
  State<ShellRouteRedirect> createState() => _ShellRouteRedirectState();
}

class _ShellRouteRedirectState extends State<ShellRouteRedirect> {
  bool _redirected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_redirected) {
      return;
    }
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        '/shell',
        arguments: AppShellTab.values.indexOf(widget.tab),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(),
    );
  }
}
