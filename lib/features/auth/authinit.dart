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
  Widget _formGate = const LoggedOutGate();

  /// Last authenticated shell — kept during in-place token refresh so the app
  /// does not flash LogorSign / a Guest-labeled home.
  Widget? _authedShell;
  Timer? _initialTimeout;
  String? _shellUserId;

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

  bool _hasUserIdentity(Map<String, dynamic> user) {
    final id = (user['id'] ?? user['user_id'] ?? user['userId'] ?? '')
        .toString()
        .trim();
    final email = (user['email'] ?? user['user_email'] ?? user['userEmail'] ?? '')
        .toString()
        .trim();
    final phone =
        (user['phone'] ?? user['user_phone'] ?? user['phone_number'] ?? '')
            .toString()
            .trim();
    return id.isNotEmpty || email.isNotEmpty || phone.isNotEmpty;
  }

  void _popToRoot() {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.popUntil((route) => route.isFirst);
  }

  Widget _requireAuthShell(dynamic user) {
    final map = _userMap(user);
    if (!_hasUserIdentity(map)) {
      _authedShell = null;
      _shellUserId = null;
      _formGate = const LoggedOutGate();
      return _formGate;
    }
    final id = (map['id'] ?? map['user_id'] ?? '').toString().trim();
    if (_authedShell != null && _shellUserId != null && _shellUserId == id) {
      return _authedShell!;
    }
    _shellUserId = id;
    _authedShell = SubscriptionGuard(user: map);
    return _authedShell!;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated ||
            state is SessionExpired ||
            state is TokenRefreshFailed) {
          _authedShell = null;
          _formGate = const LoggedOutGate();
          _shellUserId = null;
          _popToRoot();
        }

        if (state is Authenticated && state.resetNavigation) {
          _popToRoot();
        }

        if (state is SessionExpired) {
          showAppSnackBar(context, userFacingError(state.message));
        } else if (state is TokenRefreshFailed) {
          showAppSnackBar(context, userFacingError(state.message));
        }
      },
      builder: (context, state) {
        print('=== AuthWrapper State: ${state.runtimeType} ===');

        if (state is Authenticated) {
          print('✓ User is Authenticated');
          _initialTimeout?.cancel();
          return _requireAuthShell(state.user);
        }
        if (state is TokenRefreshed) {
          _initialTimeout?.cancel();
          return _requireAuthShell(state.user);
        }

        if (state is Unauthenticated ||
            state is SessionExpired ||
            state is TokenRefreshFailed) {
          print('✗ ${state.runtimeType} - showing logged-out gate');
          _authedShell = null;
          _formGate = const LoggedOutGate();
          return _formGate;
        }

        // In-app refresh: keep the authenticated shell mounted.
        if (state is TokenRefreshing && _authedShell != null) {
          return _authedShell!;
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
            state is TokenRefreshing ||
            state is DetachOtpSent) {
          if (_authedShell != null) {
            return _authedShell!;
          }
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
