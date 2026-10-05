import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:autobus/common_design/credit_category.dart';
import 'package:autobus/common_design/user_facing_error.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/autobus_loading_indicator.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/subscription/userplan.dart';
import 'package:autobus/features/subscription/payment_method_page.dart';
import 'package:autobus/icons/figma_icons.dart';

/// [RouteSettings.name] for [Navigator.popUntil] after plan purchase from this flow.
const String kManageSubscriptionRouteName = 'ManageSubscription';

class ManageSubscriptionPage extends StatefulWidget {
  const ManageSubscriptionPage({super.key});

  @override
  State<ManageSubscriptionPage> createState() => _ManageSubscriptionPageState();
}

class _ManageSubscriptionPageState extends State<ManageSubscriptionPage> {
  static const _heroPurple = Color(0xFF2D0C51);
  static const _actionBg = Color(0xFFF8FAFC);
  static const _actionInk = Color(0xFF0E0E0E);
  static const _historyMuted = Color(0xFF727272);
  static const _historyCredits = Color(0xFF555555);
  static const _pricePurple = Color(0xFF7F03B9);
  static const _rule = Color(0xFFE6E6E6);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Map<String, dynamic>? _status;
  Map<String, dynamic>? _credits;
  List<_CreditHistoryItem> _history = const [];
  bool _loading = true;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadEmail(),
      _loadStatus(),
      _loadCredits(),
      _loadHistory(),
    ]);
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

  Future<void> _loadHistory() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getFinancials(page: 1, pageSize: 50),
        api.listBillings(page: 0, size: 50),
      ]);
      if (!mounted) return;
      final financials = results[0];
      final billings = results[1];
      final items = <_CreditHistoryItem>[];

      for (final row in financials) {
        final item = _itemFromFinancial(row);
        if (item != null) items.add(item);
      }
      for (final row in billings) {
        final source = (row['source_type'] ?? '').toString().toUpperCase();
        if (source == 'ORDER') continue;
        final item = _itemFromBilling(row);
        if (item != null) items.add(item);
      }

      items.sort((a, b) {
        final at = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

      setState(() => _history = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _history = const []);
    }
  }

  _CreditHistoryItem? _itemFromFinancial(Map<String, dynamic> row) {
    final title = (row['description'] ??
            row['narration'] ??
            row['title'] ??
            row['type'] ??
            '')
        .toString()
        .trim();
    final amount = _nullableDouble(row['amount'] ?? row['total'] ?? row['value']);
    final at = DateTime.tryParse(
      (row['created_at'] ?? row['paid_at'] ?? row['date'] ?? '').toString(),
    );
    final credits = _nullableDouble(
      row['credits'] ?? row['credit_amount'] ?? row['quantity'],
    );
    if (title.isEmpty && amount == null && at == null) return null;
    return _CreditHistoryItem(
      title: title.isEmpty ? 'Purchase of ${_displayPlanName.toLowerCase()}' : title,
      at: at,
      creditsLabel: credits == null ? null : '${_formatNumber(credits)} credits',
      amount: amount,
    );
  }

  _CreditHistoryItem? _itemFromBilling(Map<String, dynamic> row) {
    final title = (row['description'] ??
            row['narration'] ??
            row['reference'] ??
            '')
        .toString()
        .trim();
    final amount = _nullableDouble(row['amount'] ?? row['total']);
    final at = DateTime.tryParse(
      (row['created_at'] ?? row['paid_at'] ?? '').toString(),
    );
    if (title.isEmpty && amount == null && at == null) return null;
    return _CreditHistoryItem(
      title: title.isEmpty ? 'Purchase of ${_displayPlanName.toLowerCase()}' : title,
      at: at,
      creditsLabel: null,
      amount: amount,
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadStatus(), _loadCredits(), _loadHistory()]);
  }

  Map<String, dynamic>? get _preferredCredit {
    final creditsMap = _credits?['credits'];
    if (creditsMap is! Map) return null;
    final preferred =
        creditsMap[CreditCategory.server] ?? creditsMap[CreditCategory.llm];
    if (preferred is Map) return Map<String, dynamic>.from(preferred);
    for (final value in creditsMap.values) {
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  double? _nullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _formatNumber(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  String get _remainingLabel {
    final rem = _nullableDouble(_preferredCredit?['remaining']);
    if (rem == null) return '0';
    return _formatNumber(rem);
  }

  String get _allocatedLabel {
    final alloc = _nullableDouble(_preferredCredit?['allocated']);
    if (alloc == null || alloc <= 0) return '—';
    return _formatNumber(alloc);
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

  String get _displayPlanName =>
      _planName == '—' ? 'No active plan' : _planName;

  double? get _planPrice {
    final v = _status?['plan_price'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  List<_CreditHistoryItem> get _visibleHistory {
    if (_history.isNotEmpty) return _history;
    if (!_hasActive) return const [];
    final at = DateTime.tryParse(
      (_status?['started_at'] ??
              _status?['created_at'] ??
              _status?['expires_at'] ??
              '')
          .toString(),
    );
    final alloc = _nullableDouble(_preferredCredit?['allocated']);
    return [
      _CreditHistoryItem(
        title: 'Purchase of ${_planName.toLowerCase()}',
        at: at,
        creditsLabel: alloc == null ? null : '${_formatNumber(alloc)} credits',
        amount: _planPrice,
      ),
    ];
  }

  String _formatHistoryDate(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]} . $hh:$mm';
  }

  String _formatMoney(double amount) {
    final shown = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '\$$shown';
  }

  Future<void> _openPlanPicker({
    required bool upgrade,
    bool renewStyle = false,
  }) async {
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
          minExclusivePlanPrice: upgrade && !renewStyle ? _planPrice : null,
          successPopUntilRouteName: kManageSubscriptionRouteName,
          topUpStyle: !renewStyle,
          renewStyle: renewStyle,
          remainingCreditsLabel: renewStyle
              ? '$_remainingLabel credits left'
              : null,
        ),
      ),
    );
    if (mounted) await _refreshAll();
  }

  Future<void> _onTopup() => _openPlanPicker(upgrade: _hasActive);

  Future<void> _onRenew() => _openPlanPicker(upgrade: false, renewStyle: true);

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
          title: Text('Cancel subscription?', style: GoogleFonts.poppins()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You will lose access to subscription features when the current period ends, depending on server policy.',
                style: GoogleFonts.poppins(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
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
        SnackBar(content: Text(userFacingError(e, fallback: AppUserMessages.save))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Credits',
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: _heroPurple,
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: LightScreenTheme.listPagePadding(scale),
          children: [
            if (_loading)
              Padding(
                padding: EdgeInsets.all(48 * scale),
                child: const Center(child: AutobusLoadingIndicator(size: 36)),
              )
            else ...[
              _heroCard(scale),
              SizedBox(height: 12 * scale),
              _actionsCard(scale),
              SizedBox(height: 12 * scale),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaymentMethodPage(),
                      ),
                    );
                  },
                  child: Text(
                    'Payment method',
                    style: GoogleFonts.poppins(
                      fontSize: LightScreenTheme.typeBody,
                      fontWeight: FontWeight.w500,
                      color: _heroPurple,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8 * scale),
              _historyHeader(scale),
              SizedBox(height: 10 * scale),
              if (_visibleHistory.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24 * scale),
                  child: Text(
                    'No credit purchases yet.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _historyMuted,
                    ),
                  ),
                )
              else
                ..._visibleHistory.map((item) => _historyRow(scale, item)),
              if (_hasActive) ...[
                SizedBox(height: 20 * scale),
                Center(
                  child: TextButton(
                    onPressed: _confirmCancel,
                    child: Text(
                      _isAppleIap
                          ? 'Manage on Apple ID'
                          : 'Cancel subscription',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroCard(double scale) {
    return Container(
      width: double.infinity,
      height: 174 * scale,
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        21 * scale,
        16 * scale,
        33 * scale,
      ),
      decoration: BoxDecoration(
        color: _heroPurple,
        borderRadius: BorderRadius.circular(15 * scale),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 20 * scale,
            child: Text(
              _displayPlanName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 20 / 14,
              ),
            ),
          ),
          SizedBox(height: 9 * scale),
          SizedBox(
            height: 63 * scale,
            child: Center(
              child: Text(
                _remainingLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
          SizedBox(
            height: 20 * scale,
            child: Text(
              'Out of $_allocatedLabel credits left',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 20 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(double scale) {
    return Container(
      height: 74 * scale,
      decoration: BoxDecoration(
        color: _actionBg,
        borderRadius: BorderRadius.circular(15 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              scale: scale,
              iconAsset: FigmaIcons.tokenOutline,
              label: 'Topup',
              onTap: _onTopup,
            ),
          ),
          Expanded(
            child: _actionButton(
              scale: scale,
              iconAsset: FigmaIcons.refresh,
              label: 'Renew',
              onTap: _onRenew,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required double scale,
    required String iconAsset,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15 * scale),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FigmaSvgIcon(
              iconAsset,
              size: 24 * scale,
            ),
            SizedBox(height: 4 * scale),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: _actionInk,
                        fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyHeader(double scale) {
    return Row(
      children: [
        Text(
          'History',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(width: 16 * scale),
        Expanded(
          child: Container(height: 1, color: _rule),
        ),
      ],
    );
  }

  Widget _historyRow(double scale, _CreditHistoryItem item) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FigmaSvgIcon(
            FigmaIcons.token,
            size: 30 * scale,
          ),
          SizedBox(width: 18 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF161616),
                  ),
                ),
                if (item.at != null)
                  Text(
                    _formatHistoryDate(item.at),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _historyMuted,
                    ),
                  ),
                if (item.creditsLabel != null)
                  Text(
                    item.creditsLabel!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _historyCredits,
                    ),
                  ),
              ],
            ),
          ),
          if (item.amount != null)
            Text(
              _formatMoney(item.amount!),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _pricePurple,
              ),
            ),
        ],
      ),
    );
  }
}

class _CreditHistoryItem {
  final String title;
  final DateTime? at;
  final String? creditsLabel;
  final double? amount;

  const _CreditHistoryItem({
    required this.title,
    this.at,
    this.creditsLabel,
    this.amount,
  });
}
