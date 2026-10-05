import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/ai_sparkle_icon.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_shell_navigation.dart';
import 'package:autobus/features/agent/agent_mode_store.dart';
import 'package:autobus/features/home/widgets/home_youtube_embed.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  static Route<void> routeFromWelcome() {
    return PageRouteBuilder<void>(
      settings: const RouteSettings(name: AppShellNavigation.homeRouteName),
      pageBuilder: (context, animation, secondaryAnimation) => const Home(),
      transitionDuration: const Duration(milliseconds: 1600),
      reverseTransitionDuration: const Duration(milliseconds: 700),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scaleCurved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.78, end: 1).animate(scaleCurved),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const _surfaceColor = Color(0xFFF8FAFC);

  Future<int>? _unreadCountFuture;
  bool _agentMode = false;

  @override
  void initState() {
    super.initState();
    AgentModeStore.load().then((value) {
      if (mounted) setState(() => _agentMode = value);
    });
  }

  void _setAgentMode(bool value) {
    setState(() => _agentMode = value);
    AgentModeStore.save(value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unreadCountFuture ??= context.read<ApiService>().getUnreadNotificationCount();
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _unreadCountFuture = context.read<ApiService>().getUnreadNotificationCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _agentMode
          ? AgentModePage(
              key: const ValueKey('agent-mode'),
              onExit: () => _setAgentMode(false),
            )
          : KeyedSubtree(
              key: const ValueKey('dashboard'),
              child: _buildDashboard(context),
            ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return AppShellScaffold(
      destination: AppShellDestination.home,
      onTabSelected: (tab) => AppShellNavigation.onTabSelected(context, tab),
      onCenterNavTap: () => AppShellNavigation.openIntelligence(context),
      showAiFab: true,
      onAiTap: () => _setAgentMode(true),
      body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                21 * scale,
                16 * scale,
                21 * scale,
                120 * scale + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 50 * scale.clamp(0.9, 1.05),
                    child: Row(
                      children: [
                        UserAvatar(
                          size: 50 * scale.clamp(0.9, 1.05),
                          onLightBackground: true,
                        ),
                        const Expanded(
                          child: Center(child: AiSparkleIcon(size: 35)),
                        ),
                        FutureBuilder<int>(
                          future: _unreadCountFuture,
                          builder: (context, snap) {
                            final unread = snap.data ?? 0;
                            return _NotificationBell(
                              scale: scale,
                              unreadCount: unread,
                              onTap: () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const NotificationsInboxPage(),
                                  ),
                                );
                                await _refreshNotifications();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 13 * scale),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      var displayName = 'there';
                      if (state is Authenticated) {
                        displayName =
                            (state.user['fullname'] ??
                                    state.user['email'] ??
                                    'there')
                                .toString()
                                .trim();
                      }
                      return Column(
                        children: [
                          Text(
                            'Hello $displayName',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Text(
                            'Here\u2019s what\u2019s happening in your\nbusiness today..',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 16 * scale),
                  HomeYoutubeEmbed(scale: scale),
                  SizedBox(height: 11 * scale),
                  Text(
                    'Tools',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12 * scale,
                    crossAxisSpacing: 12 * scale,
                    childAspectRatio: 175 / 168,
                    children: const [
                      _HomeToolCard(
                        title: 'Messaging',
                        iconAsset: FigmaIcons.wechat,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
                        ),
                        route: _HomeToolRoute.messaging,
                      ),
                      _HomeToolCard(
                        title: 'Inbox',
                        icon: HomeFigmaIcons.inbox,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                        ),
                        route: _HomeToolRoute.inbox,
                      ),
                      _HomeToolCard(
                        title: 'Marketing',
                        iconAsset: FigmaIcons.marketing,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFA3E635), Color(0xFF65A30D)],
                        ),
                        route: _HomeToolRoute.marketing,
                      ),
                      _HomeToolCard(
                        title: 'Customers',
                        iconAsset: FigmaIcons.customers,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFBBE24), Color(0xFFD97706)],
                        ),
                        route: _HomeToolRoute.customers,
                      ),
                      _HomeToolCard(
                        title: 'Products',
                        iconAsset: FigmaIcons.bag,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF22D3EE), Color(0xFF0891B2)],
                        ),
                        route: _HomeToolRoute.products,
                      ),
                      _HomeToolCard(
                        title: 'Orders',
                        icon: HomeFigmaIcons.orders,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF48BB6), Color(0xFFDB2777)],
                        ),
                        route: _HomeToolRoute.orders,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

enum _HomeToolRoute { inbox, messaging, marketing, customers, products, orders }

class _HomeToolCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? iconAsset;
  final Gradient gradient;
  final _HomeToolRoute route;

  const _HomeToolCard({
    required this.title,
    this.icon,
    this.iconAsset,
    required this.gradient,
    required this.route,
  });

  void _open(BuildContext context) {
    final Widget page = switch (route) {
      _HomeToolRoute.inbox => const ManageChats(),
      _HomeToolRoute.messaging => const ManageEmails(),
      _HomeToolRoute.marketing => const ManageMarketing(),
      _HomeToolRoute.customers => const ManageCustomers(),
      _HomeToolRoute.products => const ManageProducts(),
      _HomeToolRoute.orders => const ManageOrders(),
    };
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return Material(
      color: _HomeState._surfaceColor,
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
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
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                alignment: Alignment.center,
                child: iconAsset != null
                    ? FigmaSvgIcon(
                        iconAsset!,
                        size: 22 * scale.clamp(0.9, 1.05),
                        color: Colors.white,
                      )
                    : HomeSfIcon(
                        icon: icon!,
                        size: 20 * scale.clamp(0.9, 1.05),
                        color: Colors.white,
                      ),
              ),
              SizedBox(height: 12 * scale),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
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

class _NotificationBell extends StatelessWidget {
  final double scale;
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({
    required this.scale,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HomeState._surfaceColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 50 * scale.clamp(0.9, 1.05),
          height: 50 * scale.clamp(0.9, 1.05),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              FigmaSvgIcon(
                FigmaIcons.notificationBing,
                size: 24 * scale.clamp(0.9, 1.05),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 10 * scale,
                  top: 10 * scale,
                  child: Container(
                    width: 8 * scale,
                    height: 8 * scale,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
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
