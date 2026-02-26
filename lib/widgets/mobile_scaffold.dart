import 'package:flutter/material.dart';

/// Mobile Scaffold Wrapper
/// Constrains content to 430px width on web/desktop for mobile-like appearance.
/// Uses LayoutBuilder to guarantee tight height constraints so that
/// Expanded/Flexible children inside Column always work correctly.
class MobileScaffold extends StatelessWidget {
  final Color? backgroundColor;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  const MobileScaffold({
    super.key,
    this.backgroundColor,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use tight width + height so Column/Expanded children work
          final width = constraints.maxWidth > 430
              ? 430.0
              : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: body,
            ),
          );
        },
      ),
      bottomNavigationBar: bottomNavigationBar != null
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: bottomNavigationBar!,
              ),
            )
          : null,
      floatingActionButton: floatingActionButton,
    );
  }
}
