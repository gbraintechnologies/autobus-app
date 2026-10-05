import 'package:flutter/material.dart';

/// Breakpoints and layout helpers for phone, tablet, and desktop widths.
class ResponsiveLayout {
  ResponsiveLayout._();

  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1024;
  static const double maxContentWidthTablet = 720;
  static const double maxContentWidthDesktop = 960;
  static const double maxButtonWidth = 400;
  static const double maxFormWidth = 440;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isTablet(BuildContext context) =>
      screenWidth(context) >= tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      screenWidth(context) >= desktopBreakpoint;

  static double maxContentWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width >= desktopBreakpoint) return maxContentWidthDesktop;
    if (width >= tabletBreakpoint) return maxContentWidthTablet;
    return width;
  }

  static double horizontalPadding(BuildContext context) {
    final width = screenWidth(context);
    if (width >= desktopBreakpoint) return 48;
    if (width >= tabletBreakpoint) return 32;
    return 20;
  }

  /// Hub/dashboard tile columns from available content width.
  static int gridCrossAxisCount(
    BuildContext context, {
    double minTileWidth = 160,
    int minCount = 2,
    int maxCount = 4,
  }) {
    final width =
        maxContentWidth(context) - horizontalPadding(context) * 2;
    final count = (width / minTileWidth).floor();
    return count.clamp(minCount, maxCount);
  }

  static double buttonWidth(BuildContext context, {double fraction = 0.6}) {
    final width = screenWidth(context);
    return (width * fraction).clamp(240.0, maxButtonWidth);
  }

  static double formMaxWidth(BuildContext context) {
    if (isTablet(context)) return maxFormWidth;
    return 360;
  }

  static double chatBubbleMaxWidth(BuildContext context) {
    final width = maxContentWidth(context);
    return (width * 0.72).clamp(260.0, 480.0);
  }
}

/// Centers content and caps width on tablet and desktop.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveLayout.maxContentWidth(context),
        ),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.horizontalPadding(context),
              ),
          child: child,
        ),
      ),
    );
  }
}
