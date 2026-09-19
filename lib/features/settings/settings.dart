import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _switchColor = Color(0xFF2D0C51);
  static const _switchSubtitle = Color(0xFFBABABA);
  static const _rowText = Color(0xFF3E3E3E);
  static const _deleteColor = Color(0xFFE60B51);
  static const _logoutColor = Color(0xFFE11D48);

  Map<String, dynamic>? _credits;
  bool _creditsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCreditsSummary());
  }

  Future<void> _loadCreditsSummary() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! Authenticated) {
      if (mounted) {
        setState(() {
          _creditsLoading = false;
          _credits = null;
        });
      }
      return;
    }
    try {
      final api = context.read<ApiService>();
      final s = await api.getMyCredits();
      if (!mounted) return;
      setState(() {
        _credits = s;
        _creditsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _credits = null;
        _creditsLoading = false;
      });
    }
  }

  String _creditsTitle() {
    if (_creditsLoading) return 'Loading…';
    final wallet = _credits?['wallet'];
    if (wallet is Map) {
      final v = wallet['remaining'];
      final remaining = v is num
          ? v.toDouble()
          : double.tryParse(v?.toString() ?? '') ?? 0;
      final text = remaining == remaining.roundToDouble()
          ? remaining.toStringAsFixed(0)
          : remaining.toStringAsFixed(1);
      return '$text credits';
    }
    return 'Credits';
  }

  String _creditsSubtitle() {
    if (_creditsLoading) return ' ';
    return 'Tap Credits below to buy more';
  }

  String _usernameFromState(AuthState state) {
    if (state is Authenticated) {
      return state.user['fullname'] ?? state.user['email'] ?? 'User';
    }
    return 'Guest';
  }

  void _openSubscription() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: kManageSubscriptionRouteName),
        builder: (_) => const ManageSubscriptionPage(),
      ),
    ).then((_) {
      if (mounted) _loadCreditsSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoggedOutGate()),
            (route) => false,
          );
        } else if (state is AuthError && state.source == 'logout') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message.isNotEmpty
                    ? userFacingError(state.message)
                    : 'Error signing out',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return LightScreenScaffold(
            title: _usernameFromState(state),
            body: SingleChildScrollView(
              padding: LightScreenTheme.listPagePadding(scale),
              child: Column(
                children: [
                  _SettingsCard(
                    scale: scale,
                    color: _switchColor,
                    onTap: () => showBusinessSwitcher(context),
                    child: Row(
                      children: [
                        FigmaSvgIcon(
                          FigmaIcons.switchBusiness,
                          size: 24 * scale,
                          color: Colors.white,
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Switch Business',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Add, switch, or detach businesses on this login',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: _switchSubtitle,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20 * scale),
                  _SettingsCard(
                    scale: scale,
                    onTap: _openSubscription,
                    child: Row(
                      children: [
                        FigmaSvgIcon(
                          FigmaIcons.token,
                          size: 30 * scale,
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _creditsTitle(),
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _creditsSubtitle(),
                                style: GoogleFonts.poppins(
                                  color: _rowText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FigmaSvgIcon(
                          FigmaIcons.chevronDown,
                          size: 30 * scale,
                          color: const Color(0xFF4C4C4C),
                          chevronRight: true,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: LightScreenTheme.sectionGap * scale),
                  _SettingsCard(
                    scale: scale,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16 * scale,
                      vertical: 10 * scale,
                    ),
                    child: Column(
                      children: [
                        for (final item in _buildMenuItems())
                          _SettingsMenuTile(scale: scale, item: item),
                      ],
                    ),
                  ),
                  SizedBox(height: LightScreenTheme.sectionGap * scale),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      final isLoading = authState is AuthLoading;
                      return _SettingsCard(
                        scale: scale,
                        padding: EdgeInsets.fromLTRB(
                          30 * scale,
                          18 * scale,
                          30 * scale,
                          18 * scale,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: isLoading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const DeleteAccountPage(),
                                        ),
                                      );
                                    },
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 10 * scale),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Delete account',
                                    style: GoogleFonts.poppins(
                                      color: _deleteColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: isLoading
                                  ? null
                                  : () => _handleLogout(context),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 10 * scale),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    isLoading ? 'Logging out...' : 'Logout',
                                    style: GoogleFonts.poppins(
                                      color: isLoading
                                          ? Colors.grey
                                          : _logoutColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<SettingsMenuItem> _buildMenuItems() {
    return [
      SettingsMenuItem('Profile', FigmaIcons.profile, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Profile()),
        );
      }),
      SettingsMenuItem('Credits', FigmaIcons.tokenOutline, _openSubscription),
      SettingsMenuItem('Notifications', FigmaIcons.notification, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
      }),
      SettingsMenuItem('Password & Security', FigmaIcons.password, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Security()),
        );
      }),
      SettingsMenuItem('Help & Support', FigmaIcons.info, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelpPage()),
        );
      }),
      SettingsMenuItem('Terms and Conditions', FigmaIcons.documents, () {
        openAuthLegalUrl(AppConfig.termsOfServiceUrl);
      }),
      SettingsMenuItem('Privacy Policy', FigmaIcons.documents, () {
        openAuthLegalUrl(AppConfig.privacyPolicyUrl);
      }),
    ];
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.10),
                  ),
                  child: HomeSfIcon(
                    icon: HomeFigmaIcons.logout,
                    color: Colors.red,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Log out?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can log back in at any time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<AuthBloc>().add(LogoutEvent());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final double scale;
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const _SettingsCard({
    required this.scale,
    required this.child,
    this.onTap,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = 15 * scale;
    final content = Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 88 * scale),
      padding: padding ??
          EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 20 * scale),
      decoration: BoxDecoration(
        color: color ?? LightScreenTheme.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  final double scale;
  final SettingsMenuItem item;

  const _SettingsMenuTile({required this.scale, required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12 * scale),
          child: Row(
            children: [
              SizedBox(
                width: 28 * scale,
                child: FigmaSvgIcon(
                  item.iconAsset,
                  size: 20 * scale,
                  color: const Color(0xFF4E4E4E),
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.poppins(
                    color: _SettingsPageState._rowText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              FigmaSvgIcon(
                FigmaIcons.chevronDown,
                size: 24 * scale,
                color: const Color(0xFF4C4C4C),
                chevronRight: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsMenuItem {
  final String title;
  final String iconAsset;
  final VoidCallback onTap;

  SettingsMenuItem(this.title, this.iconAsset, this.onTap);
}
