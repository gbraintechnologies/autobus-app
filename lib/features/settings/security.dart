import 'package:autobus/barrel.dart';

class Security extends StatelessWidget {
  const Security({super.key});

  Future<void> _openPinSetup(BuildContext context, PinSetupMode mode) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SetupPinPage(mode: mode)),
    );
    if (ok != true || !context.mounted) return;
    final message = switch (mode) {
      PinSetupMode.create => 'App PIN enabled',
      PinSetupMode.change => 'PIN updated',
      PinSetupMode.disable => 'App PIN turned off',
    };
    showAppSnackBar(context, message, backgroundColor: CustColors.mainCol);
  }

  Future<void> _onTogglePin(BuildContext context, bool enable) async {
    await _openPinSetup(
      context,
      enable ? PinSetupMode.create : PinSetupMode.disable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotificationBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Security()),
                        );
                      },
                      child: _circleIcon(Icons.share_outlined),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      NotificationMenuTile(
                        item: SecurityMenuItem(
                          "Change Password",
                          Icons.person_outline,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RecoverAccount(),
                              ),
                            );
                          },
                        ),
                      ),
                      BlocBuilder<PinLockCubit, PinLockState>(
                        builder: (context, pinState) {
                          final enabled = pinState.isEnabled;
                          return Column(
                            children: [
                              _PinSwitchTile(
                                enabled: !pinState.busy,
                                value: enabled,
                                onChanged: (val) => _onTogglePin(context, val),
                              ),
                              if (enabled)
                                NotificationMenuTile(
                                  item: SecurityMenuItem(
                                    "Change PIN",
                                    Icons.pin_outlined,
                                    () => _openPinSetup(
                                      context,
                                      PinSetupMode.change,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      NotificationMenuTile(
                        item: SecurityMenuItem(
                          "2FA",
                          Icons.notifications_none,
                          () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(dynamic icon) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: icon is IconData
          ? Icon(icon, color: Colors.white70, size: 18)
          : Iconify(icon, color: Colors.white70, size: 8),
    );
  }
}

class _PinSwitchTile extends StatelessWidget {
  const _PinSwitchTile({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App PIN',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ask for your PIN after 10 minutes away',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PinToggle(value: value, enabled: enabled),
          ],
        ),
      ),
    );
  }
}

class _PinToggle extends StatelessWidget {
  const _PinToggle({required this.value, required this.enabled});

  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final trackColor = value
        ? CustColors.mainCol
        : Colors.black.withValues(alpha: 0.12);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.55,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: trackColor,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              value ? Icons.check_rounded : Icons.remove_rounded,
              size: 16,
              color: value ? CustColors.mainCol : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationMenuTile extends StatelessWidget {
  final SecurityMenuItem item;

  const NotificationMenuTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.onTap,
      leading: Icon(item.icon, color: Colors.black87),
      title: Text(
        item.title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black54),
    );
  }
}

class SecurityMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  SecurityMenuItem(this.title, this.icon, this.onTap);
}

class NotificationBackground extends StatelessWidget {
  final Widget child;
  const NotificationBackground({super.key, required this.child});

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
