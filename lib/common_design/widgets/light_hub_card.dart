import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/icons/home_figma_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hub grid card — `#F8FAFC` surface, optional gradient icon tile.
class LightHubCard extends StatelessWidget {
  /// Tall enough for icon + two-line title + subtitle without overflow.
  static const tileAspectRatio = 175 / 168;

  final double scale;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? iconWidget;
  final Gradient? iconGradient;
  final Color? iconTileColor;
  final Color? iconColor;
  final Color? subtitleColor;
  final VoidCallback onTap;

  const LightHubCard({
    super.key,
    required this.scale,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconWidget,
    this.iconGradient,
    this.iconTileColor,
    this.iconColor,
    this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = 20 * scale.clamp(0.9, 1.05);
    final hasTileFill = iconGradient != null || iconTileColor != null;

    return Material(
      color: LightScreenTheme.surface,
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20 * scale),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16 * scale,
            16 * scale,
            16 * scale,
            14 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40 * scale,
                height: 40 * scale,
                decoration: BoxDecoration(
                  gradient: iconGradient,
                  color: iconGradient != null
                      ? null
                      : (iconTileColor ??
                          LightScreenTheme.accent.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                alignment: Alignment.center,
                child: iconWidget ??
                    HomeSfIcon(
                      icon: icon,
                      size: iconSize,
                      color: hasTileFill
                          ? Colors.white
                          : (iconColor ?? LightScreenTheme.accent),
                    ),
              ),
              SizedBox(height: 12 * scale),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 6 * scale),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: subtitleColor ?? LightScreenTheme.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-column hub tile grid with overflow-safe card height.
class LightHubGrid extends StatelessWidget {
  final double scale;
  final List<Widget> children;

  const LightHubGrid({
    super.key,
    required this.scale,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: LightScreenTheme.gridGap * scale,
      crossAxisSpacing: LightScreenTheme.gridGap * scale,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: LightHubCard.tileAspectRatio,
      children: children,
    );
  }
}
