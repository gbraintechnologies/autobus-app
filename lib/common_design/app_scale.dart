import 'package:flutter/material.dart';

/// Screen-aware type scale for the whole app.
///
/// Combines device width/height (vs a 390×844 design) with the OS accessibility
/// text scale, then clamps so small phones and large system fonts do not wrap
/// labels or blow out layouts.
class AppScale {
  AppScale._();

  static const double designWidth = 390;
  static const double designHeight = 844;

  /// Layout factor from the current screen vs the design size.
  static double layoutOf(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final widthFactor = (size.width / designWidth).clamp(0.80, 1.12);
    final heightFactor = (size.height / designHeight).clamp(0.80, 1.12);
    return (widthFactor * 0.75) + (heightFactor * 0.25);
  }

  /// OS text scale, limited so accessibility settings cannot break screens.
  static double osFactorOf(BuildContext context) {
    final os = MediaQuery.textScalerOf(context).scale(14) / 14;
    return os.clamp(0.90, 1.20);
  }

  /// Combined scaler to install at the [MaterialApp] root.
  static TextScaler textScalerOf(BuildContext context) {
    final combined = (layoutOf(context) * osFactorOf(context)).clamp(0.80, 1.25);
    return TextScaler.linear(combined);
  }
}

/// One-line (or few-line) text that shrinks to fit instead of wrapping/overflowing.
class AppFitText extends StatelessWidget {
  const AppFitText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.alignment,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final AlignmentGeometry? alignment;

  AlignmentGeometry get _alignment {
    if (alignment != null) return alignment!;
    switch (textAlign) {
      case TextAlign.left:
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: _alignment,
      child: Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: maxLines > 1,
        overflow: TextOverflow.visible,
      ),
    );
  }
}
