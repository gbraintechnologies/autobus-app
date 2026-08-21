import 'package:autobus/barrel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _subscriptionStatus;
  bool _subscriptionLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubscriptionSummary());
  }

  Future<void> _loadSubscriptionSummary() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! Authenticated) {
      if (mounted) {
        setState(() {
          _subscriptionLoading = false;
          _subscriptionStatus = null;
        });
      }
      return;
    }
    try {
      final api = context.read<ApiService>();
      final s = await api.getMySubscriptionStatus();
      if (!mounted) return;
      setState(() {
        _subscriptionStatus = s;
        _subscriptionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptionStatus = null;
        _subscriptionLoading = false;
      });
    }
  }

  String _subscriptionTitle() {
    if (_subscriptionLoading) return 'Loading…';
    final s = _subscriptionStatus;
    if (s == null) return 'No active plan';
    final active = s['has_active_subscription'] == true;
    if (!active) return 'No active plan';
    final name = (s['plan_name'] ?? '').toString().trim();
    return name.isEmpty ? 'Active subscription' : name;
  }

  String _subscriptionSubtitle() {
    if (_subscriptionLoading) return ' ';
    final s = _subscriptionStatus;
    if (s == null) return 'Tap Subscription below to choose a plan';
    final active = s['has_active_subscription'] == true;
    if (!active) return 'Tap Subscription below to choose a plan';
    final d = s['days_remaining'];
    final days = d is int ? d : int.tryParse(d?.toString() ?? '0') ?? 0;
    if (days > 1) return '$days days until renewal';
    if (days == 1) return '1 day until renewal';
    return 'Renews today';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Handle unauthenticated state (successful logout)
        if (state is Unauthenticated) {
          // Navigate to signin page and remove all previous routes
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LogorSign()),
            (route) => false,
          );
        }
        // Handle logout errors
        else if (state is AuthError && state.source == 'logout') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message.isNotEmpty
                    ? userFacingError(state.message)
                    : 'Error signing out',
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        body: _SettingsBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  /// 🔝 Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// Back Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: CustColors.mainCol,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),

                      /// Company Name / Username
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          String username = 'User';
                          if (state is Authenticated) {
                            username =
                                state.user['fullname'] ??
                                state.user['email'] ??
                                'User';
                          }
                          return Text(
                            username,
                            style: GoogleFonts.montserrat(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                      ),

                      /// Share Icon
                      _circleIcon(Icons.share_outlined),
                    ],
                  ),

                  const SizedBox(height: 40),

                  /// Subscription summary (under top bar)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _subscriptionTitle(),
                          style: GoogleFonts.montserrat(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _subscriptionSubtitle(),
                          style: GoogleFonts.montserrat(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// ⚙️ Settings Card
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: _buildMenuItems()
                          .map((item) => _SettingsMenuTile(item: item))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 26),

                  /// 🚪 Logout Card with loading state
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      bool isLoading = state is AuthLoading;

                      return GestureDetector(
                        onTap: isLoading ? null : () => _handleLogout(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isLoading ? 'Logging out...' : "Logout",
                                style: GoogleFonts.montserrat(
                                  color: isLoading ? Colors.grey : Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (isLoading)
                                const AutobusLoadingIndicator(size: 20)
                              else
                                const Icon(
                                  Icons.logout,
                                  color: Colors.red,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<SettingsMenuItem> _buildMenuItems() {
    return [
      SettingsMenuItem("Profile", Icons.person_outline, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Profile()),
        );
      }),
      SettingsMenuItem("Subscription", Icons.auto_awesome_rounded, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: kManageSubscriptionRouteName),
            builder: (_) => const ManageSubscriptionPage(),
          ),
        ).then((_) => _loadSubscriptionSummary());
      }),
      if (AppleIapIds.isIosApp)
        SettingsMenuItem("Manage Subscriptions", Icons.open_in_new, () {
          openManageSubscriptionsWebsite();
        }),
      SettingsMenuItem("Notifications", Icons.notifications_none, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
      }),
      SettingsMenuItem("Password & Security", Icons.lock_outline, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Security()),
        );
      }),
      SettingsMenuItem("Help & Support", Icons.help_outline, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelpPage()),
        );
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
                  color: Colors.black.withOpacity(0.12),
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
                    color: Colors.red.withOpacity(0.10),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 26),
                ),
                const SizedBox(height: 14),
                Text(
                  'Log out?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can log back in at any time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
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
                            color: Colors.black.withOpacity(0.12),
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
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
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
                          style: GoogleFonts.montserrat(
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

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: Colors.white70, size: 18),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  final SettingsMenuItem item;

  const _SettingsMenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.onTap,
      leading: Icon(item.icon, color: Colors.black87),
      title: Text(
        item.title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black54),
    );
  }
}

class SettingsMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  SettingsMenuItem(this.title, this.icon, this.onTap);
}

class _SettingsBackground extends StatelessWidget {
  final Widget child;
  const _SettingsBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 244, 244, 244),
            Color.fromARGB(255, 240, 240, 240),
            Color.fromARGB(255, 236, 236, 236),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
