import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:autobus/common_design/app_error.dart';
import 'package:autobus/common_design/app_scale.dart';
import 'package:autobus/config/app_config.dart';
import 'package:autobus/common_design/colors.dart';
import 'package:autobus/common_design/credit_category.dart';
import 'package:autobus/common_design/dismiss_keyboard.dart';
import 'package:autobus/common_design/widgets/autobus_loading_indicator.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/subscription/data/apple_iap_ids.dart';
import 'package:autobus/features/subscription/services/apple_iap_service.dart';
import 'package:autobus/features/subscription/userplan.dart';

/// Opens the Autobus login page so iOS users can sign in and subscribe via Paystack.
Future<void> openManageSubscriptionsWebsite() async {
  final uri = Uri.parse(AppConfig.publicWebsiteLoginUrl);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// [RouteSettings.name] for [Navigator.popUntil] after plan purchase from this flow.
const String kManageSubscriptionRouteName = 'ManageSubscription';

class ManageSubscriptionPage extends StatefulWidget {
  const ManageSubscriptionPage({super.key});

  @override
  State<ManageSubscriptionPage> createState() => _ManageSubscriptionPageState();
}

class _ManageSubscriptionPageState extends State<ManageSubscriptionPage> {
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _credits;
  bool _loading = true;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadEmail(), _loadStatus(), _loadCredits()]);
  }

  Future<void> _loadEmail() async {
    try {
      final user = await context.read<ApiService>().getUserProfile();
      if (!mounted) return;
      setState(() {
        _userEmail = (user['email'] ?? user['user_email'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
    });
    try {
      final api = context.read<ApiService>();
      final s = await api.getMySubscriptionStatus();
      if (!mounted) return;
      setState(() {
        _status = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = null;
        _loading = false;
      });
    }
  }

  Future<void> _loadCredits() async {
    try {
      final data = await context.read<ApiService>().getMyCredits();
      if (!mounted) return;
      setState(() => _credits = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _credits = null);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadStatus(), _loadCredits()]);
  }

  String _formatCreditValue(String type, dynamic remaining) {
    final v = remaining is num
        ? remaining.toDouble()
        : double.tryParse(remaining?.toString() ?? '') ?? 0;
    if (type == CreditCategory.storageMb) {
      if (v >= 1024) return '${(v / 1024).toStringAsFixed(1)} GB';
      return '${v.toStringAsFixed(0)} MB';
    }
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  Widget _buildCreditsSection() {
    final creditsMap = _credits?['credits'];
    if (creditsMap is! Map || creditsMap.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = creditsMap.entries.toList()
      ..sort((a, b) {
        final la = CreditCategory.labelFor(a.key);
        final lb = CreditCategory.labelFor(b.key);
        return la.compareTo(lb);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Credits remaining',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ...entries.map((entry) {
          final key = entry.key.toString();
          final item = entry.value;
          if (item is! Map) return const SizedBox.shrink();
          final allocated = item['allocated'];
          final remaining = item['remaining'];
          final label = (item['label'] ?? CreditCategory.labelFor(key))
              .toString();
          final allocNum = allocated is num
              ? allocated.toDouble()
              : double.tryParse(allocated?.toString() ?? '') ?? 0;
          final remNum = remaining is num
              ? remaining.toDouble()
              : double.tryParse(remaining?.toString() ?? '') ?? 0;
          final progress = allocNum > 0 ? (remNum / allocNum).clamp(0.0, 1.0) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatCreditValue(key, remaining)} left',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: CustColors.mainCol,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.black12,
                      color: CustColors.mainCol,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatCreditValue(key, allocated)} monthly allocation',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  bool get _isAppleIap {
    return (_status?['payment_provider'] ?? '').toString() == 'apple_iap';
  }

  bool get _hasActive {
    final s = _status;
    if (s == null) return false;
    return s['has_active_subscription'] == true;
  }

  String get _planName =>
      (_status?['plan_name'] ?? '').toString().trim().isEmpty
      ? '—'
      : (_status!['plan_name']).toString();

  int get _daysRemaining {
    final v = _status?['days_remaining'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  double? get _planPrice {
    final v = _status?['plan_price'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  String _renewalLine() {
    if (!_hasActive) return 'Choose a plan to unlock premium features.';
    final d = _daysRemaining;
    if (d > 1) return '$d days until renewal';
    if (d == 1) return '1 day until renewal';
    return 'Renews today';
  }

  String? _expiresLine() {
    final raw = _status?['expires_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return 'Renews on $raw';
      final local = dt.toLocal();
      final mm = local.month.toString().padLeft(2, '0');
      final dd = local.day.toString().padLeft(2, '0');
      return 'Renewal date: ${local.year}-$mm-$dd';
    } catch (_) {
      return null;
    }
  }

  Future<void> _openPlanPicker({required bool upgrade}) async {
    var email = _userEmail.trim();
    if (email.isEmpty) {
      try {
        final user = await context.read<ApiService>().getUserProfile();
        email = (user['email'] ?? user['user_email'] ?? '').toString().trim();
        if (mounted) setState(() => _userEmail = email);
      } catch (_) {}
    }
    if (!mounted) return;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an email on your profile before changing plans.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'ManageSubscriptionSelectPlan'),
        builder: (_) => SelectPlan(
          userEmail: email,
          upgradeFromActivePlan: upgrade,
          minExclusivePlanPrice: upgrade ? _planPrice : null,
          successPopUntilRouteName: kManageSubscriptionRouteName,
        ),
      ),
    );
    if (mounted) await _refreshAll();
  }

  Future<void> _restoreApplePurchases() async {
    setState(() => _loading = true);
    try {
      final result = await AppleIapService.instance.restoreActiveSubscription();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Apple subscription restored.'
                : (result.error ?? 'No Apple subscription to restore.'),
          ),
        ),
      );
      if (result.success) await _refreshAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAppleSubscriptions() async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmCancel() async {
    if (_isAppleIap) {
      await _openAppleSubscriptions();
      return;
    }
    final reasonCtrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Cancel subscription?', style: GoogleFonts.montserrat()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You will lose access to subscription features when the current period ends, depending on server policy.',
                style: GoogleFonts.montserrat(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                onTapOutside: dismissAppKeyboard,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                maxLength: 500,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep subscription'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Cancel plan',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        );
      },
    );
    final reasonText = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (go != true || !mounted) return;

    try {
      await context.read<ApiService>().cancelMySubscription(
        reason: reasonText.isEmpty ? null : reasonText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subscription cancelled.')));
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(userFacingError(e, action: 'canceling subscription'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 244, 244, 244),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 244, 244, 244),
              Color.fromARGB(255, 236, 236, 236),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
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
                          ),
                        ),
                        Expanded(
                          child: AppFitText(
                            'Subscription',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(
                            child: AutobusLoadingIndicator(size: 36),
                          ),
                        )
                      else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasActive ? _planName : 'No active plan',
                                style: GoogleFonts.montserrat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _renewalLine(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              if (_expiresLine() != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _expiresLine()!,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _buildCreditsSection(),
                        const SizedBox(height: 18),
                        if (AppleIapIds.isIosApp) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: openManageSubscriptionsWebsite,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CustColors.mainCol,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: AppFitText(
                                'Manage Subscriptions',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _hasActive
                                ? () => _openPlanPicker(upgrade: true)
                                : () => _openPlanPicker(upgrade: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CustColors.mainCol,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                              child: AppFitText(
                                _hasActive
                                    ? 'Upgrade or change plan'
                                    : 'Choose a plan',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                          ),
                        ),
                        if (_hasActive) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _confirmCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade800,
                                side: BorderSide(color: Colors.red.shade200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: AppFitText(
                                _isAppleIap
                                    ? 'Manage on Apple ID'
                                    : 'Cancel subscription',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (AppleIapIds.isSupported) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : _restoreApplePurchases,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CustColors.mainCol,
                                side: const BorderSide(
                                  color: CustColors.mainCol,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: AppFitText(
                                'Restore Purchases',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        ],
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
