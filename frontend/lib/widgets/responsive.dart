import 'package:flutter/material.dart';

/// Breakpoint helper for adaptive layouts.
class Responsive {
  Responsive._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 1200;
  }
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1200;

  /// Number of columns for a feature/tool grid.
  static int gridCols(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 500) return 1;
    if (w < 800) return 2;
    if (w < 1200) return 3;
    return 4;
  }

  /// Horizontal page padding that scales with screen width.
  static double pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return 16;
    if (w < 1200) return 32;
    return 48;
  }

  /// Max content width (centered on wide screens).
  static const double maxWidth = 1100;
}

/// Centres content and clamps it to [Responsive.maxWidth].
class MaxWidthBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const MaxWidthBox({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Responsive.maxWidth),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}
