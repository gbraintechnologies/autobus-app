import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:flutter/material.dart';

/// List row container for light detail screens.
class LightListCard extends StatelessWidget {
  final double scale;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  const LightListCard({
    super.key,
    required this.scale,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: LightScreenTheme.surface,
        borderRadius: BorderRadius.circular(20 * scale),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20 * scale),
        child: content,
      ),
    );
  }
}
