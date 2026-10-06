import 'package:autobus/barrel.dart';

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _navigated = false;
  bool _showSplash = false;
  Timer? _authStallTimer;
  Timer? _failsafeTimer;

  @override
  void initState() {
    super.initState();
    print('=== SPLASH WRAPPER INIT ===');
    _startAuthStallTimer();
    _failsafeTimer = Timer(const Duration(seconds: 4), _onFailsafe);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleAuthResolved(context.read<AuthBloc>().state);
    });
  }

  void _startAuthStallTimer() {
    _authStallTimer?.cancel();
    _authStallTimer = Timer(const Duration(seconds: 12), () {
      if (_navigated || !mounted) return;
      final state = context.read<AuthBloc>().state;
      if (_isLoggedIn(state)) {
        print('=== AUTH STALL TIMEOUT - PROCEEDING ===');
        _goToAuth();
        return;
      }
      _revealSplash();
    });
  }

  void _revealSplash() {
    if (_navigated || !mounted || _showSplash) return;
    setState(() => _showSplash = true);
  }

  void _goToAuth() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _authStallTimer?.cancel();
    _failsafeTimer?.cancel();
    print('=== NAVIGATING TO AUTH WRAPPER ===');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
      (route) => false,
    );
  }

  bool _isLoggedIn(AuthState state) =>
      state is Authenticated || state is TokenRefreshed;

  bool _isLoggedOut(AuthState state) =>
      state is Unauthenticated ||
      state is SessionExpired ||
      state is TokenRefreshFailed ||
      state is AuthError;

  void _handleAuthResolved(AuthState state) {
    if (_isLoggedIn(state)) {
      _goToAuth();
      return;
    }

    if (_isLoggedOut(state)) {
      _revealSplash();
    }
  }

  void _onFailsafe() {
    if (_navigated || !mounted) return;
    final state = context.read<AuthBloc>().state;
    if (_isLoggedIn(state)) {
      _goToAuth();
      return;
    }
    _revealSplash();
  }

  @override
  void dispose() {
    _authStallTimer?.cancel();
    _failsafeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) => _handleAuthResolved(state),
      builder: (context, state) {
        if (_isLoggedIn(state)) {
          return const Scaffold(body: Center(child: AutobusLoadingIndicator()));
        }

        if (_showSplash || _isLoggedOut(state)) {
          return OnboardingPage(onFinished: _goToAuth);
        }

        return const Scaffold(body: Center(child: AutobusLoadingIndicator()));
      },
    );
  }
}
