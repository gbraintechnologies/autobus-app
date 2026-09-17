import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// White top bar with a centered title and breathing room from side controls.
class AppScreenHeader extends StatelessWidget {
  final double scale;
  final String title;
  final Widget leading;
  final Widget? trailing;
  final double titleFontSize;

  const AppScreenHeader({
    super.key,
    required this.scale,
    required this.title,
    required this.leading,
    this.trailing,
    this.titleFontSize = 16,
  });

  static const infoCircleColor = Color(0xFFECECF0);
  static const iconColor = Color(0xFF374151);

  static double rowHeightFor(double scale) => 44 * scale.clamp(0.9, 1.0);

  /// Max width for [CreditsPill] so it can shrink instead of crowding the title.
  static double sideSlotWidthFor(double scale) => 120 * scale.clamp(0.9, 1.0);

  @override
  Widget build(BuildContext context) {
    final headerScale = scale.clamp(0.9, 1.0);
    final rowHeight = rowHeightFor(scale);
    final gap = 12 * headerScale;

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16 * scale,
            10 * headerScale,
            16 * scale,
            14 * headerScale,
          ),
          child: SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                leading,
                SizedBox(width: gap),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(width: gap),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 32 * headerScale,
                    maxWidth: sideSlotWidthFor(scale),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard light-theme back control for [AppScreenHeader].
class AppScreenBackButton extends StatelessWidget {
  final double scale;
  final VoidCallback? onPressed;
  final bool enabled;

  const AppScreenBackButton({
    super.key,
    required this.scale,
    this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final headerScale = scale.clamp(0.9, 1.0);
    return IconButton(
      onPressed: enabled
          ? (onPressed ?? () => Navigator.of(context).maybePop())
          : null,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
        minWidth: 36 * headerScale,
        minHeight: 36 * headerScale,
      ),
      icon: FigmaSvgIcon(
        FigmaIcons.back,
        size: 22 * headerScale,
        color: Colors.black,
      ),
    );
  }
}

/// Gray circular info button — Figma Intelligence header leading control.
class IntelligenceInfoButton extends StatelessWidget {
  final double scale;
  final VoidCallback onTap;

  const IntelligenceInfoButton({
    super.key,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final headerScale = scale.clamp(0.9, 1.0);
    final size = 36 * headerScale;

    return Material(
      color: AppScreenHeader.infoCircleColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: FigmaSvgIcon(
              FigmaIcons.infoHeader,
              size: 24 * headerScale,
            ),
          ),
        ),
      ),
    );
  }
}
