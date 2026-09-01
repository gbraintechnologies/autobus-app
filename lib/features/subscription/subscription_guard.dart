import 'package:autobus/barrel.dart';

class SubscriptionGuard extends StatefulWidget {
  final Map<String, dynamic> user;

  const SubscriptionGuard({required this.user, super.key});

  @override
  State<SubscriptionGuard> createState() => _SubscriptionGuardState();
}

class _SubscriptionGuardState extends State<SubscriptionGuard> {
  int _generation = 0;

  Map<String, dynamic> get user => widget.user;

  static String _extractEmail(Map<String, dynamic> u) {
    final v = u['email'] ?? u['user_email'] ?? u['userEmail'] ?? '';
    return v.toString();
  }

  Future<({bool onboarded, String email})> _resolve(BuildContext context) async {
    final api = context.read<ApiService>();
    var resolvedEmail = _extractEmail(user);
    var profile = user;
    var onboarded = isOnboardingCompleted(user);

    try {
      profile = await api.getUserProfile();
      resolvedEmail = _extractEmail(profile).isNotEmpty
          ? _extractEmail(profile)
          : resolvedEmail;
      onboarded = isOnboardingCompleted(profile);
    } catch (_) {}

    return (onboarded: onboarded, email: resolvedEmail);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({bool onboarded, String email})>(
      key: ValueKey(_generation),
      future: _resolve(context).timeout(
        const Duration(seconds: 8),
        onTimeout: () => (
          onboarded: isOnboardingCompleted(user),
          email: _extractEmail(user),
        ),
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: AutobusLoadingIndicator()),
          );
        }

        final onboarded = snap.data?.onboarded != false;
        if (!onboarded) {
          return BusinessOnboarding(
            nextScreen: 'welcome',
            userEmail: snap.data?.email ?? '',
            onCompleted: () {
              if (!mounted) return;
              setState(() => _generation++);
            },
          );
        }
        return const Home();
      },
    );
  }
}
