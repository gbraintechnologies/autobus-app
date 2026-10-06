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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppShellNavigation.shellCanPop,
      builder: (context, shellCanPop, navigator) {
        return PopScope(
          canPop: !_agentMode && !shellCanPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || _agentMode) return;
            AppShellNavigation.shellKey.currentState?.pop();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<AppNavTab>(
                valueListenable: AppShellNavigation.activeTab,
                builder: (context, tab, navigator) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: AppShellNavigation.homeVisible,
                    builder: (context, homeVisible, navigator) {
                      return AppShellScaffold(
                        activeTab: tab,
                        showBottomNav: homeVisible && !_agentMode,
                        showAiFab: homeVisible && !_agentMode,
                        onAiTap: () => _setAgentMode(true),
                        onTabSelected: (selected) =>
                            AppShellNavigation.onTabSelected(context, selected),
                        loadUnreadCount: () => context
                            .read<ApiService>()
                            .getUnreadNotificationCount(),
                        badgeRefresh: AppShellNavigation.revision,
                        body: navigator!,
                      );
                    },
                    child: navigator,
                  );
                },
                child: navigator,
              ),
              if (_agentMode)
                Positioned.fill(
                  child: AgentModePage(
                    onExit: () => _setAgentMode(false),
                  ),
                ),
            ],
          ),
        );
      },
      child: Navigator(
        key: AppShellNavigation.shellKey,
        observers: [AppShellNavigation.observer],
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: const RouteSettings(
              name: AppShellNavigation.homeRouteName,
            ),
            builder: (_) => const _HomeDashboard(),
          );
        },
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  static const surfaceColor = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                21 * scale,
                16 * scale,
                21 * scale,
                88 * scale,
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
                          showBorder: false,
                        ),
                        Expanded(
                          child: Center(
                            child: Semantics(
                              button: true,
                              label: 'Intelligence',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    AppShellNavigation.openIntelligence(
                                      context,
                                    ),
                                child: SizedBox(
                                  width: 44 * scale.clamp(0.9, 1.05),
                                  height: 44 * scale.clamp(0.9, 1.05),
                                  child: Center(
                                    child: AiSparkleIcon(
                                      size: 35 * scale.clamp(0.9, 1.05),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _MessagesButton(
                          scale: scale,
                          onTap: () => AppShellNavigation.openMessages(context),
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
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 16 * scale),
                  Text(
                    'Latests',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  HomeNeedsFeed(scale: scale),
                  SizedBox(height: 11 * scale),
                  Text(
                    'Agents',
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
                    childAspectRatio: 175 / 146,
                    children: const [
                      _HomeToolCard(
                        title: 'Messaging',
                        subtitle: 'Customer chats',
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
                        subtitle: 'New conversations',
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
                        subtitle: 'Posts and campaigns',
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
                        subtitle: 'People you sell to',
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
                        subtitle: 'Catalogue and prices',
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
                        subtitle: 'Open and completed',
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
    );
  }
}

enum _HomeToolRoute { inbox, messaging, marketing, customers, products, orders }

class _HomeToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? iconAsset;
  final Gradient gradient;
  final _HomeToolRoute route;

  const _HomeToolCard({
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconAsset,
    required this.gradient,
    required this.route,
  });

  void _open(BuildContext context) {
    switch (route) {
      case _HomeToolRoute.inbox:
        AppShellNavigation.openMessages(context);
      case _HomeToolRoute.customers:
        AppShellNavigation.onTabSelected(context, AppNavTab.people);
      case _HomeToolRoute.products:
        AppShellNavigation.onTabSelected(context, AppNavTab.shop);
      case _HomeToolRoute.messaging:
        _push(context, const ManageEmails());
      case _HomeToolRoute.marketing:
        _push(context, const ManageMarketing());
      case _HomeToolRoute.orders:
        _push(context, const ManageOrders());
    }
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return Material(
      color: _HomeDashboard.surfaceColor,
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        borderRadius: BorderRadius.circular(20 * scale),
        child: Padding(
          padding: EdgeInsets.all(20 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44 * scale,
                height: 44 * scale,
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
              SizedBox(height: 20 * scale),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesButton extends StatelessWidget {
  final double scale;
  final VoidCallback onTap;

  const _MessagesButton({
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = 50 * scale.clamp(0.9, 1.05);
    return Material(
      color: _HomeDashboard.surfaceColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Iconify(
              Ph.chat_circle,
              size: 24 * scale.clamp(0.9, 1.05),
              color: const Color(0xFF0A0A0A),
            ),
          ),
        ),
      ),
    );
  }
}
