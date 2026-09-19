import 'package:autobus/common_design/widgets/ai_sparkle_icon.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppNavTab { home, analytics }

/// Which main shell screen is active — drives nav icon colors only.
enum AppShellDestination { home, analytics, intelligence }

const appShellDesignWidth = 402.0;

/// Shared bottom navigation used across main app screens.
class AppBottomNav extends StatelessWidget {
  final AppShellDestination destination;
  final ValueChanged<AppNavTab>? onTabSelected;
  final VoidCallback? onCenterTap;

  const AppBottomNav({
    super.key,
    this.destination = AppShellDestination.home,
    this.onTabSelected,
    this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final barHeight = 80 * scale;
    final fabSize = 48 * scale.clamp(0.9, 1.1);
    final fabOverlap = fabSize / 2;
    final iconSize = 20 * scale.clamp(0.9, 1.1);
    final notchGap = 6 * scale;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        21 * scale,
        0,
        21 * scale,
        8 * scale + bottomInset,
      ),
      child: SizedBox(
        height: barHeight + fabOverlap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: CustomPaint(
                painter: _DockNavBarPainter(
                  cornerRadius: 24 * scale,
                  notchRadius: fabSize / 2 + notchGap,
                ),
                child: SizedBox(
                  height: barHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavTabButton(
                          scale: scale,
                          label: 'Home',
                          active: destination == AppShellDestination.home,
                          onTap: () => onTabSelected?.call(AppNavTab.home),
                          icon: _HomeNavIcon(
                            active: destination == AppShellDestination.home,
                            size: iconSize,
                          ),
                        ),
                      ),
                      SizedBox(width: fabSize + 16 * scale),
                      Expanded(
                        child: _NavTabButton(
                          scale: scale,
                          label: 'Analytics',
                          active: destination == AppShellDestination.analytics,
                          onTap: () => onTabSelected?.call(AppNavTab.analytics),
                          icon: _AnalyticsNavIcon(
                            active: destination == AppShellDestination.analytics,
                            size: iconSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _CenterNavFab(
                size: fabSize,
                active: destination == AppShellDestination.intelligence,
                onTap: onCenterTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White Figma dock: rounded rectangle with a circular bite for the center FAB.
class _DockNavBarPainter extends CustomPainter {
  final double cornerRadius;
  final double notchRadius;

  const _DockNavBarPainter({
    required this.cornerRadius,
    required this.notchRadius,
  });

  Path _dock(Size size) {
    final bar = Path()
      ..addRRect(
        RRect.fromLTRBR(
          0,
          0,
          size.width,
          size.height,
          Radius.circular(cornerRadius),
        ),
      );
    final notch = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, 0),
          radius: notchRadius,
        ),
      );
    return Path.combine(PathOperation.difference, bar, notch);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _dock(size);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.12), 12, false);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _DockNavBarPainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.notchRadius != notchRadius;
  }
}

class _CenterNavFab extends StatelessWidget {
  final double size;
  final bool active;
  final VoidCallback? onTap;

  const _CenterNavFab({
    required this.size,
    this.active = false,
    this.onTap,
  });

  static const _accentColor = Color(0xFF7F03B9);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _accentColor : Colors.white,
      elevation: 10,
      shadowColor: const Color(0x40005D5D),
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
              active ? FigmaIcons.aiFab : FigmaIcons.ai,
              size: size * 0.58,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeNavIcon extends StatelessWidget {
  final bool active;
  final double size;

  const _HomeNavIcon({required this.active, required this.size});

  static const _activeColor = Color(0xFF6929C4);
  static const _inactiveColor = Color(0xFF6F6F6F);

  @override
  Widget build(BuildContext context) {
    return FigmaSvgIcon(
      FigmaIcons.navHome,
      size: size,
      color: active ? _activeColor : _inactiveColor,
    );
  }
}

class _AnalyticsNavIcon extends StatelessWidget {
  final bool active;
  final double size;

  const _AnalyticsNavIcon({required this.active, required this.size});

  static const _activeColor = Color(0xFF6929C4);
  static const _inactiveColor = Color(0xFF6F6F6F);

  @override
  Widget build(BuildContext context) {
    return FigmaSvgIcon(
      FigmaIcons.navAnalytics,
      size: size,
      color: active ? _activeColor : _inactiveColor,
    );
  }
}

class _NavTabButton extends StatelessWidget {
  final double scale;
  final String label;
  final bool active;
  final Widget icon;
  final VoidCallback? onTap;

  const _NavTabButton({
    required this.scale,
    required this.label,
    required this.active,
    required this.icon,
    this.onTap,
  });

  static const _activeColor = Color(0xFF6929C4);
  static const _inactiveColor = Color(0xFF6F6F6F);

  @override
  Widget build(BuildContext context) {
    final color = active ? _activeColor : _inactiveColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12 * scale),
      child: Padding(
        padding: EdgeInsets.only(top: 20 * scale, bottom: 10 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(height: 4 * scale),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Purple floating AI button shown above the nav on main screens.
class AppAiAssistantFab extends StatelessWidget {
  final VoidCallback? onTap;

  const AppAiAssistantFab({super.key, this.onTap});

  static const _accentColor = Color(0xFF7F03B9);

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final size = 48 * scale.clamp(0.9, 1.1);

    return Material(
      color: _accentColor,
      elevation: 8,
      shadowColor: const Color(0x3D005D5D),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: AiSparkleIcon(
              size: size * 0.73,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard shell for screens that share the bottom nav and AI FAB.
class AppShellScaffold extends StatelessWidget {
  final AppShellDestination destination;
  final Widget body;
  final Color backgroundColor;
  final bool showAiFab;
  final VoidCallback? onAiTap;
  final VoidCallback? onCenterNavTap;
  final ValueChanged<AppNavTab>? onTabSelected;

  const AppShellScaffold({
    super.key,
    this.destination = AppShellDestination.home,
    required this.body,
    this.backgroundColor = const Color(0xFFF3F3F7),
    this.showAiFab = false,
    this.onAiTap,
    this.onCenterNavTap,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          body,
          if (showAiFab)
            Positioned(
              right: 12 * scale,
              bottom: 96 * scale + bottomInset,
              child: AppAiAssistantFab(onTap: onAiTap),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              destination: destination,
              onTabSelected: onTabSelected,
              onCenterTap: onCenterNavTap,
            ),
          ),
        ],
      ),
    );
  }
}
