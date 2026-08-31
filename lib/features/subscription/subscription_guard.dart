import 'package:autobus/barrel.dart';

import 'services/subscription_storage.dart';

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

  static String _extractPhone(Map<String, dynamic> u) {
    final v =
        u['phone'] ??
        u['user_phone'] ??
        u['userPhone'] ??
        u['phone_number'] ??
        u['phoneNumber'] ??
        '';
    return v.toString().trim();
  }

  static bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'active';
    }
    return false;
  }

  static bool _isSubscribedFromUser(Map<String, dynamic> user) {
    const directFlags = [
      'is_subscribed',
      'subscribed',
      'has_subscription',
      'hasSubscription',
      'subscription_active',
      'subscriptionActive',
      'active_subscription',
      'activeSubscription',
      'is_premium',
      'premium',
      'paid',
    ];

    for (final k in directFlags) {
      if (_truthy(user[k])) return true;
    }

    const directIds = [
      'plan_id',
      'planId',
      'subscription_plan_id',
      'subscriptionPlanId',
      'active_plan_id',
      'activePlanId',
    ];
    for (final k in directIds) {
      final v = user[k];
      if (v != null && v.toString().trim().isNotEmpty) return true;
    }

    // Some backends represent subscription tier/plan as strings (e.g. "free").
    const directPlanStrings = [
      'plan',
      'plan_name',
      'planName',
      'tier',
      'subscription_tier',
      'subscriptionTier',
      'subscription_plan',
      'subscriptionPlan',
    ];
    for (final k in directPlanStrings) {
      final v = user[k];
      if (v is String && v.trim().isNotEmpty) return true;
    }

    final nestedCandidates = [
      user['subscription'],
      user['plan'],
      user['current_plan'],
      user['currentPlan'],
      user['active_subscription'],
      user['activeSubscription'],
    ];
    for (final c in nestedCandidates) {
      if (c is Map) {
        final m = Map<String, dynamic>.from(c);
        if (_truthy(m['active']) ||
            _truthy(m['is_active']) ||
            _truthy(m['isActive']) ||
            _truthy(m['status'])) {
          return true;
        }
        if (m['plan_id'] != null || m['planId'] != null) return true;
        // Free/trial plans can be identified by a nested name/slug even when
        // no plan_id is present.
        final name =
            (m['name'] ?? m['plan_name'] ?? m['planName'] ?? m['tier'] ?? '')
                .toString()
                .trim();
        if (name.isNotEmpty) return true;
      }
    }

    return false;
  }

  Future<({bool subscribed, bool onboarded, String email})> _resolve(
    BuildContext context,
  ) async {
    final api = context.read<ApiService>();
    var resolvedEmail = _extractEmail(user);
    var profile = user;
    var onboarded = isOnboardingCompleted(user);

    // 1) Profile from server (may include subscription-shaped fields).
    try {
      profile = await api.getUserProfile();
      resolvedEmail = _extractEmail(profile).isNotEmpty
          ? _extractEmail(profile)
          : resolvedEmail;
      onboarded = isOnboardingCompleted(profile);

      if (_isSubscribedFromUser(profile)) {
        return (
          subscribed: true,
          onboarded: onboarded,
          email: resolvedEmail,
        );
      }
    } catch (_) {
      // Keep [user] as profile; fall back to subscription/status + local cache.
    }

    // 2) Backend subscription by phone (profile /me does not include plan flags).
    final phone = _extractPhone(profile);
    if (phone.isNotEmpty) {
      try {
        final status = await api.getSubscriptionStatusByPhone(phone);
        if (status != null && _truthy(status['has_active_subscription'])) {
          return (
            subscribed: true,
            onboarded: onboarded,
            email: resolvedEmail,
          );
        }
      } catch (_) {}
    }

    // 3) iOS: App Store subscriptions are under review, so grant the
    // complimentary Free plan and skip in-app purchase.
    if (AppleIapIds.isIosApp) {
      try {
        await api.enrollIosFreePlan();
      } catch (_) {}
      return (subscribed: true, onboarded: onboarded, email: resolvedEmail);
    }

    // 4) Fallback: if the app previously completed a subscribe flow on this
    // device, it stores the selection.
    final (planId, _) = await SubscriptionStorage().loadSelection();
    final subscribed = planId != null && planId.trim().isNotEmpty;
    return (subscribed: subscribed, onboarded: onboarded, email: resolvedEmail);
  }

  @override
  Widget build(BuildContext context) {
    print('=== SUBSCRIPTION GUARD BUILDING ===');
    return FutureBuilder<({bool subscribed, bool onboarded, String email})>(
      key: ValueKey(_generation),
      future: _resolve(context).timeout(
        const Duration(seconds: 8),
        onTimeout: () => (
          subscribed: AppleIapIds.isIosApp || _isSubscribedFromUser(user),
          onboarded: isOnboardingCompleted(user),
          email: _extractEmail(user),
        ),
      ),
      builder: (context, snap) {
        print(
          'ConnectionState: ${snap.connectionState}, hasData: ${snap.hasData}',
        );
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: AutobusLoadingIndicator()),
          );
        }

        final data = snap.data;
        final subscribed = data?.subscribed == true;
        final onboarded = data?.onboarded != false;
        print(
          'Subscribed: $subscribed, Onboarded: $onboarded, Email: ${data?.email}',
        );
        if (!onboarded) {
          print('✗ Showing Business Onboarding');
          return BusinessOnboarding(
            nextScreen: AppleIapIds.isIosApp ? 'welcome' : 'subscribe',
            userEmail: data?.email ?? '',
            onCompleted: () {
              if (!mounted) return;
              setState(() => _generation++);
            },
          );
        }
        if (subscribed) {
          print('✓ Showing Home Screen');
          return const Home();
        }

        print('✗ Showing SelectPlan Screen');
        return SelectPlan(userEmail: data?.email ?? '');
      },
    );
  }
}
