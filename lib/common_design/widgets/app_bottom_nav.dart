import 'package:autobus/common_design/colors.dart';
import 'package:autobus/common_design/widgets/ai_sparkle_icon.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ph.dart';

enum AppNavTab { home, people, shop, notifications }

const appShellDesignWidth = 402.0;

const _pillBarHeight = 50.0;
const _pillBottomGap = 10.0;
const _fabClearance = 14.0;

const _activeColor = CustColors.logodeep;
const _iconInk = CustColors.mainCol;
const _badgeRed = CustColors.accentRed;

/// Floating pill navigation used on the main dashboard shell.
class AppBottomNav extends StatelessWidget {
  final AppNavTab activeTab;
  final ValueChanged<AppNavTab>? onTabSelected;
  final Future<int> Function()? loadUnreadCount;
  final Listenable? badgeRefresh;

  const AppBottomNav({
    super.key,
    this.activeTab = AppNavTab.home,
    this.onTabSelected,
    this.loadUnreadCount,
    this.badgeRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final barHeight = _pillBarHeight * scale.clamp(0.92, 1.08);
    final iconSize = 20 * scale.clamp(0.9, 1.08);
    final radius = barHeight / 2;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        0,
        12 * scale,
        _pillBottomGap * scale + bottomInset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: barHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6 * scale),
              child: Row(
                children: [
                  _NavSlot(
                    label: 'Home',
                    active: activeTab == AppNavTab.home,
                    scale: scale,
                    onTap: () => onTabSelected?.call(AppNavTab.home),
                    icon: Iconify(
                      activeTab == AppNavTab.home ? Ph.house_fill : Ph.house,
                      size: iconSize,
                      color: activeTab == AppNavTab.home
                          ? _activeColor
                          : _iconInk,
                    ),
                  ),
                  _NavSlot(
                    label: 'Customers',
                    active: activeTab == AppNavTab.people,
                    scale: scale,
                    onTap: () => onTabSelected?.call(AppNavTab.people),
                    icon: Iconify(
                      activeTab == AppNavTab.people ? Ph.users_fill : Ph.users,
                      size: iconSize,
                      color: activeTab == AppNavTab.people
                          ? _activeColor
                          : _iconInk,
                    ),
                  ),
                  _NavSlot(
                    label: 'Products',
                    active: activeTab == AppNavTab.shop,
                    scale: scale,
                    onTap: () => onTabSelected?.call(AppNavTab.shop),
                    icon: Iconify(
                      activeTab == AppNavTab.shop
                          ? Ph.storefront_fill
                          : Ph.storefront,
                      size: iconSize,
                      color: activeTab == AppNavTab.shop
                          ? _activeColor
                          : _iconInk,
                    ),
                  ),
                  _NotificationNavSlot(
                    iconSize: iconSize,
                    scale: scale,
                    active: activeTab == AppNavTab.notifications,
                    loadUnreadCount: loadUnreadCount,
                    badgeRefresh: badgeRefresh,
                    onTap: () =>
                        onTabSelected?.call(AppNavTab.notifications),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  final String label;
  final Widget icon;
  final double scale;
  final bool active;
  final int badgeCount;
  final VoidCallback? onTap;

  const _NavSlot({
    required this.label,
    required this.icon,
    required this.scale,
    this.active = false,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: active,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Center(
            child: _BadgeAnchor(
              count: badgeCount,
              scale: scale,
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationNavSlot extends StatefulWidget {
  final double iconSize;
  final double scale;
  final bool active;
  final Future<int> Function()? loadUnreadCount;
  final Listenable? badgeRefresh;
  final VoidCallback? onTap;

  const _NotificationNavSlot({
    required this.iconSize,
    required this.scale,
    this.active = false,
    this.loadUnreadCount,
    this.badgeRefresh,
    this.onTap,
  });

  @override
  State<_NotificationNavSlot> createState() => _NotificationNavSlotState();
}

class _NotificationNavSlotState extends State<_NotificationNavSlot> {
  int _count = 0;
  bool _wasCurrent = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    widget.badgeRefresh?.addListener(_reload);
  }

  @override
  void didUpdateWidget(covariant _NotificationNavSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.badgeRefresh != widget.badgeRefresh) {
      oldWidget.badgeRefresh?.removeListener(_reload);
      widget.badgeRefresh?.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.badgeRefresh?.removeListener(_reload);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && !_wasCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }
    _wasCurrent = current;
  }

  Future<void> _reload() async {
    final load = widget.loadUnreadCount;
    if (!mounted || load == null) return;
    final request = ++_request;
    try {
      final count = await load();
      if (!mounted || request != _request || count == _count) return;
      setState(() => _count = count);
    } catch (_) {
      if (!mounted || request != _request || _count == 0) return;
      setState(() => _count = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _count > 0 ? ', $_count unread' : '';
    return _NavSlot(
      label: 'Notifications$unread',
      scale: widget.scale,
      active: widget.active,
      badgeCount: _count,
      onTap: widget.onTap,
      icon: FigmaSvgIcon(
        FigmaIcons.notificationBing,
        size: widget.iconSize,
        color: widget.active ? _activeColor : _iconInk,
      ),
    );
  }
}

class _BadgeAnchor extends StatelessWidget {
  final int count;
  final double scale;
  final Widget child;

  const _BadgeAnchor({
    required this.count,
    required this.scale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        if (count > 0)
          Positioned(
            top: -3 * scale,
            right: -5 * scale,
            child: _CountBadge(count: count, scale: scale),
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final double scale;

  const _CountBadge({required this.count, required this.scale});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final wide = label.length > 1;
    final size = 13 * scale.clamp(0.9, 1.05);
    return Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: EdgeInsets.symmetric(horizontal: wide ? 3 * scale : 0),
      decoration: BoxDecoration(
        color: _badgeRed,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: Colors.white, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 8 * scale.clamp(0.9, 1.05),
          fontWeight: FontWeight.w700,
          height: 1,
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
  final AppNavTab activeTab;
  final Widget body;
  final Color backgroundColor;
  final bool showAiFab;
  final VoidCallback? onAiTap;
  final ValueChanged<AppNavTab>? onTabSelected;
  final Future<int> Function()? loadUnreadCount;
  final Listenable? badgeRefresh;
  final bool showBottomNav;

  const AppShellScaffold({
    super.key,
    this.activeTab = AppNavTab.home,
    required this.body,
    this.backgroundColor = const Color(0xFFF3F3F7),
    this.showAiFab = false,
    this.onAiTap,
    this.onTabSelected,
    this.loadUnreadCount,
    this.badgeRefresh,
    this.showBottomNav = true,
  });

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                body,
                if (showAiFab)
                  Positioned(
                    right: 16 * scale,
                    bottom: _fabClearance * scale,
                    child: AppAiAssistantFab(onTap: onAiTap),
                  ),
              ],
            ),
          ),
          if (showBottomNav && !keyboardOpen)
            AppBottomNav(
              activeTab: activeTab,
              onTabSelected: onTabSelected,
              loadUnreadCount: loadUnreadCount,
              badgeRefresh: badgeRefresh,
            ),
        ],
      ),
    );
  }
}
