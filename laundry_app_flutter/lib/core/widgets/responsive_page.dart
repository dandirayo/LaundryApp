import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageHorizontal,
      AppSpacing.pageTop,
      AppSpacing.pageHorizontal,
      AppSpacing.pageBottom,
    ),
    this.maxWidth = 900,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
