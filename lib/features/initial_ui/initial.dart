import 'package:autobus/barrel.dart';
import 'package:autobus/features/onboarding/onboarding_page.dart';
import 'package:autobus/features/onboarding/onboarding_storage.dart';

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _navigated = false;
  bool? _hasSeenSplash;
  bool _forceMarketingSplash = false;
  Timer? _splashTimer;
  Timer? _authStallTimer;
  Timer? _failsafeTimer;

  @override
  void initState() {
    super.initState();
    print('=== SPLASH WRAPPER INIT ===');
    _startAuthStallTimer();
    _loadSplashPref();
    _failsafeTimer = Timer(const Duration(seconds: 4), _onFailsafe);
  }

  void _startAuthStallTimer() {
    _authStallTimer?.cancel();
    _authStallTimer = Timer(const Duration(seconds: 12), () {
      if (_navigated || !mounted) return;
      print('=== AUTH STALL TIMEOUT - PROCEEDING ===');
      _goToAuth();
    });
  }

  Future<void> _loadSplashPref() async {
    try {
      final seen = await OnboardingStorage()
          .hasSeenSplash()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      if (!mounted) return;
      setState(() => _hasSeenSplash = seen);
      _handleAuthResolved(context.read<AuthBloc>().state);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasSeenSplash = false);
      _handleAuthResolved(context.read<AuthBloc>().state);
    }
  }

  void _goToAuth() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _splashTimer?.cancel();
    _authStallTimer?.cancel();
    _failsafeTimer?.cancel();
    print('=== NAVIGATING TO AUTH WRAPPER ===');
    if (_hasSeenSplash == false) {
      unawaited(OnboardingStorage().markSplashSeen());
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  void _scheduleSplashTimeout() {
    _splashTimer?.cancel();
    _splashTimer = Timer(const Duration(seconds: 3), _goToAuth);
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
      if (_hasSeenSplash == true) {
        _goToAuth();
      } else if (_hasSeenSplash == false) {
        _scheduleSplashTimeout();
      }
    }
  }

  void _onFailsafe() {
    if (_navigated || !mounted) return;
    final state = context.read<AuthBloc>().state;
    if (_isLoggedIn(state)) {
      _goToAuth();
      return;
    }
    if (_hasSeenSplash == false) {
      setState(() => _forceMarketingSplash = true);
      _scheduleSplashTimeout();
      return;
    }
    _goToAuth();
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _authStallTimer?.cancel();
    _failsafeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_hasSeenSplash == null) return;
        _handleAuthResolved(state);
      },
      builder: (context, state) {
        if (_isLoggedIn(state)) {
          return const Scaffold(
            body: Center(child: AutobusLoadingIndicator()),
          );
        }

        final showOnboarding =
            _forceMarketingSplash ||
            ((_hasSeenSplash == false) && _isLoggedOut(state));
        if (showOnboarding) {
          return OnboardingPage(onFinished: _goToAuth);
        }

        return const Scaffold(
          body: Center(child: AutobusLoadingIndicator()),
        );
      },
    );
  }
}
