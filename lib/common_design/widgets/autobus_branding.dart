import 'package:autobus/barrel.dart';
import 'package:autobus/icons/figma_icons.dart';

class AutobusWordmark extends StatelessWidget {
  const AutobusWordmark({
    super.key,
    this.fontSize = 32,
    this.fontWeight = FontWeight.w600,
    this.baseColor = const Color(0xFF09050F),
    this.accentColor = CustColors.logodeep,
    this.textAlign = TextAlign.center,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final Color baseColor;
  final Color accentColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: RichText(
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.visible,
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: baseColor,
          ),
          children: [
            TextSpan(
              text: "A",
              style: TextStyle(color: accentColor),
            ),
            const TextSpan(text: "ut"),
            TextSpan(
              text: "ob",
              style: TextStyle(color: accentColor),
            ),
            const TextSpan(text: "us"),
          ],
        ),
      ),
    );
  }
}

class AutobusMark extends StatelessWidget {
  const AutobusMark({
    super.key,
    this.circleSize = 40,
    this.primaryColor = const Color(0xFF7F03B9),
    this.secondaryColor = const Color(0xFFA92FE2),
  });

  final double circleSize;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    // Matches the exact look from `SplashPge` (two overlapping circles).
    return SizedBox(
      width: circleSize * 1.5,
      height: circleSize * 1.05,
      child: Stack(
        children: [
          Positioned(
            left: circleSize * 0.5,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: circleSize, height: circleSize),
            ),
          ),
          Positioned(
            left: 0,
            top: circleSize * 0.025,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: secondaryColor,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: circleSize, height: circleSize),
            ),
          ),
        ],
      ),
    );
  }
}

class AutobusBranding extends StatelessWidget {
  const AutobusBranding({
    super.key,
    this.wordmarkFontSize = 32,
    this.wordmarkBaseColor = const Color(0xFF09050F),
    this.wordmarkAccentColor = CustColors.logodeep,
    this.markCircleSize = 40,
    this.spacing = 18,
  });

  final double wordmarkFontSize;
  final Color wordmarkBaseColor;
  final Color wordmarkAccentColor;
  final double markCircleSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          FigmaImages.splashLogo,
          height: (wordmarkFontSize + markCircleSize) * 1.35,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}
