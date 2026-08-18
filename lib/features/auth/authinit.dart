import 'package:autobus/barrel.dart';
import 'package:autobus/features/subscription/subscription_guard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  /// Last login/signup landing page. Kept mounted through AuthLoading/AuthError
  /// so form snackbar listeners are not torn down (iOS).
  Widget _formGate = const LogorSign();
  Timer? _initialTimeout;

  @override
  void initState() {
    super.initState();
    _initialTimeout = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final state = context.read<AuthBloc>().state;
      if (state is AuthInitial || state is TokenRefreshing) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _initialTimeout?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _userMap(dynamic user) {
    if (user is Map<String, dynamic>) return user;
    if (user is Map) return Map<String, dynamic>.from(user);
    return <String, dynamic>{};
  }

  void _popToRoot() {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated ||
            state is SessionExpired ||
            state is TokenRefreshFailed) {
          _formGate = const LogorSign();
        }

        if (state is SessionExpired) {
          showAppSnackBar(context, state.message);
          _popToRoot();
        } else if (state is TokenRefreshFailed) {
          showAppSnackBar(context, 'Session error: ${state.message}');
        }
      },
      builder: (context, state) {
        print('=== AuthWrapper State: ${state.runtimeType} ===');

        if (state is Authenticated) {
          print('✓ User is Authenticated');
          _initialTimeout?.cancel();
          return SubscriptionGuard(user: _userMap(state.user));
        }
        if (state is TokenRefreshed) {
          _initialTimeout?.cancel();
          return SubscriptionGuard(user: _userMap(state.user));
        }

        if (state is Unauthenticated ||
            state is SessionExpired ||
            state is TokenRefreshFailed) {
          print('✗ ${state.runtimeType} - showing LogorSign');
          _formGate = const LogorSign();
          return _formGate;
        }

        // Keep Signin/LogorSign mounted through login/signup load and error so
        // the form (and its snackbar listener) is not torn down. Replacing the
        // Scaffold here is what hid error snackbars on iOS.
        if (state is AuthLoading ||
            state is AuthError ||
            state is Registered ||
            state is SignupOtpVerified ||
            state is SignupOtpResent ||
            state is EmailExists ||
            state is ResetCodeSent ||
            state is ResetCodeVerified ||
            state is PasswordResetSuccess ||
            state is TokenRefreshing) {
          print('✗ Auth gate: ${state.runtimeType} - keeping form');
          return _formGate;
        }

        // AuthInitial — brief loader, then login landing if session check stalls.
        if (_initialTimeout?.isActive == false) {
          print('⏳ Session check timed out - showing LogorSign');
          return _formGate;
        }
        print('⏳ Initial Loading State: $state');
        return const Scaffold(
          body: Center(child: AutobusLoadingIndicator()),
        );
      },
    );
  }
}
