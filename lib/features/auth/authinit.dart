import 'package:autobus/barrel.dart';
import 'package:autobus/features/subscription/subscription_guard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Handle session expiration
        if (state is SessionExpired) {
          showAppSnackBar(context, state.message);
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/signin', (route) => false);
        }
        // Handle token refresh failure
        else if (state is TokenRefreshFailed) {
          showAppSnackBar(context, 'Session error: ${state.message}');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          print('=== AuthWrapper State: ${state.runtimeType} ===');

          if (state is Authenticated) {
            print('✓ User is Authenticated');
            final dynamic u = state.user;
            final userMap = (u is Map<String, dynamic>)
                ? u
                : (u is Map
                      ? Map<String, dynamic>.from(u)
                      : <String, dynamic>{});
            return SubscriptionGuard(user: userMap);
          } else if (state is TokenRefreshed) {
            final dynamic u = state.user;
            final userMap = (u is Map<String, dynamic>)
                ? u
                : (u is Map
                      ? Map<String, dynamic>.from(u)
                      : <String, dynamic>{});
            return SubscriptionGuard(user: userMap);
          } else if (state is Unauthenticated ||
              state is AuthLoading ||
              state is AuthError) {
            // Keep Signin mounted through login/signup load and error so the
            // form (and its snackbar listener) is not torn down. Replacing the
            // Scaffold here is what hid error snackbars on iOS.
            print('✗ Auth gate: ${state.runtimeType} - showing Signin');
            return const Signin();
          } else if (state is SessionExpired) {
            print('✗ Session Expired - showing LogorSign');
            return const LogorSign();
          } else if (state is TokenRefreshing) {
            print('⏳ Token Refreshing...');
            return const Scaffold(
              body: Center(child: AutobusLoadingIndicator()),
            );
          } else if (state is TokenRefreshFailed) {
            print('✗ Token Refresh Failed: ${state.message} - showing Signin');
            return const Signin();
          } else {
            print('⏳ Initial Loading State: $state');
            return const Scaffold(
              body: Center(child: AutobusLoadingIndicator()),
            );
          }
        },
      ),
    );
  }
}
