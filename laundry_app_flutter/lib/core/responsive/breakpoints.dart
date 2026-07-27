import 'package:flutter/material.dart';

class Breakpoints {
  const Breakpoints._();

  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;
}

enum ScreenSize { compact, medium, expanded }

extension ScreenSizeX on BuildContext {
  ScreenSize get screenSize {
    final width = MediaQuery.sizeOf(this).width;
    if (width < Breakpoints.compact) {
      return ScreenSize.compact;
    }
    if (width < Breakpoints.medium) {
      return ScreenSize.medium;
    }
    return ScreenSize.expanded;
  }

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isExpanded => screenSize == ScreenSize.expanded;
}
