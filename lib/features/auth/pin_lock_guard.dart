import 'package:autobus/barrel.dart';

/// App-wide PIN lock. Lives in [MaterialApp.builder] so the lock screen sits
/// above every route (home, settings, splash) after 10 minutes away.
class PinLockGuard extends StatefulWidget {
  const PinLockGuard({super.key, required this.child});

  final Widget child;

  @override
  State<PinLockGuard> createState() => _PinLockGuardState();
}

class _PinLockGuardState extends State<PinLockGuard>
    with WidgetsBindingObserver {
  AuthState? _prevAuth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAuth(context.read<AuthBloc>().state, freshLogin: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<PinLockCubit>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      cubit.onPaused();
    } else if (state == AppLifecycleState.resumed) {
      cubit.onResumed();
    }
  }

  bool _isSignedIn(AuthState state) =>
      state is Authenticated || state is TokenRefreshed;

  dynamic _userOf(AuthState state) {
    if (state is Authenticated) return state.user;
    if (state is TokenRefreshed) return state.user;
    return null;
  }

  void _syncAuth(AuthState state, {required bool freshLogin}) {
    if (_isSignedIn(state)) {
      final key = PinLockService.userKeyFrom(_userOf(state));
      if (key == null || key.isEmpty) return;
      context.read<PinLockCubit>().bindUser(key, freshLogin: freshLogin);
      return;
    }
    if (state is Unauthenticated ||
        state is SessionExpired ||
        state is TokenRefreshFailed) {
      context.read<PinLockCubit>().reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            final prev = _prevAuth;
            _prevAuth = state;
            if (state is Authenticated || state is TokenRefreshed) {
              final freshLogin =
                  prev is AuthLoading ||
                  prev is AuthError ||
                  prev is Unauthenticated ||
                  prev is Registered;
              _syncAuth(state, freshLogin: freshLogin);
              return;
            }
            _syncAuth(state, freshLogin: false);
          },
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          return BlocBuilder<PinLockCubit, PinLockState>(
            builder: (context, pinState) {
              final signedIn = _isSignedIn(authState);
              final pending =
                  signedIn && pinState.status == PinLockStatus.unknown;
              final locked = signedIn && pinState.isLocked;
              final block = pending || locked;
              return PopScope(
                canPop: !block,
                child: Stack(
                  children: [
                    IgnorePointer(
                      ignoring: block,
                      child: widget.child,
                    ),
                    if (pending)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.white,
                          child: Center(child: AutobusLoadingIndicator()),
                        ),
                      ),
                    if (locked)
                      const Positioned.fill(child: PinLockScreen()),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
