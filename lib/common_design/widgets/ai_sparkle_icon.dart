import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/material.dart';

/// Purple-outlined AI sparkle from the HOME header and FAB.
class AiSparkleIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const AiSparkleIcon({
    super.key,
    this.size = 35,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final asset = color == Colors.white ? FigmaIcons.aiFab : FigmaIcons.ai;
    return FigmaSvgIcon(
      asset,
      size: size,
      color: color == null || color == Colors.white ? null : color,
    );
  }
}
