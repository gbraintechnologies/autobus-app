import 'package:autobus/barrel.dart';
import 'package:autobus/main.dart';
import 'dart:developer';

class SelectPlan extends StatefulWidget {
  final String userEmail;
  /// When true, payment completion calls [upgradeMySubscription] instead of subscribe.
  final bool upgradeFromActivePlan;
  /// Only plans with `price` strictly greater than this are shown (upgrade flow).
  final double? minExclusivePlanPrice;
  /// Passed to [SubscriptionBillPage] so pay+activate returns to this route.
  final String? successPopUntilRouteName;

  const SelectPlan({
    required this.userEmail,
    this.upgradeFromActivePlan = false,
    this.minExclusivePlanPrice,
    this.successPopUntilRouteName,
    super.key,
  });

  @override
  State<SelectPlan> createState() => _SelectPlanState();
}

class _SelectPlanState extends State<SelectPlan> with TickerProviderStateMixin {
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = true;
  int? _expandedPlanId; // int to match plan.id
  int? _selectedPlanId; // int to match plan.id

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  List<SubscriptionPlan> get _visiblePlans {
    final minP = widget.minExclusivePlanPrice;
    if (minP == null) return _plans;
    return _plans.where((p) => p.price > minP).toList();
  }

  Future<void> _fetchPlans() async {
    try {
      final plans = await apiService.getSubscriptionPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
          if (_selectedPlanId != null &&
              !_visiblePlans.any((p) => p.id == _selectedPlanId)) {
            _selectedPlanId = null;
            _expandedPlanId = null;
          }
        });
      }
    } catch (e) {
      log('SelectPlan: Failed to load plans — $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  SubscriptionPlan? get _selectedPlan => _selectedPlanId == null
      ? null
      : _visiblePlans.where((p) => p.id == _selectedPlanId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF130522),
      body: _GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                const _HeaderLogo(),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: AutobusLoadingIndicator(size: 36),
                        )
                      : _visiblePlans.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              widget.minExclusivePlanPrice != null
                                  ? 'There is no higher plan available right now. Contact support if you need a custom tier.'
                                  : 'No plans available.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(color: Colors.white),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    AppFitText(
                                      widget.upgradeFromActivePlan
                                          ? 'Upgrade plan'
                                          : 'User Type',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.upgradeFromActivePlan
                                          ? 'Pick a higher tier to continue'
                                          : 'Select a user type',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    for (final plan in _visiblePlans) ...[
                                      Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 400,
                                          ),
                                          child: _PlanExpandableTile(
                                            plan: plan,
                                            expanded:
                                                _expandedPlanId == plan.id,
                                            selected:
                                                _selectedPlanId == plan.id,
                                            onTap: () {
                                              setState(() {
                                                final isExpanding =
                                                    _expandedPlanId != plan.id;
                                                _expandedPlanId = isExpanding
                                                    ? plan.id
                                                    : null;
                                                _selectedPlanId = plan.id;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                _BottomCta(
                  label: widget.upgradeFromActivePlan ? 'Continue' : 'Next',
                  enabled: _selectedPlan != null,
                  onPressed: () {
                    final selected = _selectedPlan;
                    if (selected == null) return;
                    Navigator.of(context).push(
                      PageTransition(
                        type: PageTransitionType.rightToLeftWithFade,
                        duration: const Duration(milliseconds: 1000),
                        reverseDuration: const Duration(milliseconds: 600),
                        child: SubscriptionBillPage(
                          plan: selected,
                          userEmail: widget.userEmail,
                          isUpgrade: widget.upgradeFromActivePlan,
                          successPopUntilRouteName: widget.successPopUntilRouteName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanExpandableTile extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  const _PlanExpandableTile({
    required this.plan,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.white.withOpacity(selected ? 0.95 : 0.55);

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: expanded ? 18 : 20,
          ),
          decoration: BoxDecoration(
            color: expanded ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: expanded
              ? _ExpandedPlanContent(plan: plan)
              : Center(
                  child: AppFitText(
                    plan.name,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ExpandedPlanContent extends StatelessWidget {
  final SubscriptionPlan plan;
  const _ExpandedPlanContent({required this.plan});

  static Widget _itemRow({
    required IconData icon,
    required String label,
    required Color baseColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 18,
            width: 18,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                color: baseColor.withOpacity(0.85),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final col = CustColors.mainCol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFitText(
          plan.name,
          alignment: Alignment.centerLeft,
          style: GoogleFonts.montserrat(
            color: col,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        AppFitText(
          plan.priceText,
          alignment: Alignment.centerLeft,
          style: GoogleFonts.montserrat(
            color: col,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (plan.features.isNotEmpty) ...[
          Text(
            'Features',
            style: GoogleFonts.montserrat(
              color: col.withOpacity(0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          for (final f in plan.features)
            _itemRow(icon: Icons.check, label: f, baseColor: col),
        ],
        if (plan.agents.isNotEmpty) ...[
          if (plan.features.isNotEmpty) const SizedBox(height: 6),
          Text(
            'Agents',
            style: GoogleFonts.montserrat(
              color: col.withOpacity(0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          for (final a in plan.agents)
            _itemRow(
              icon: Icons.smart_toy_outlined,
              label: SubscriptionPlan.formatAgentLabel(a),
              baseColor: col,
            ),
        ],
      ],
    );
  }
}

class _BottomCta extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _BottomCta({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !enabled,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: (MediaQuery.sizeOf(context).width * 0.6).clamp(200.0, 280.0),
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.7)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 18),
                Expanded(
                  child: AppFitText(
                    label,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF9C27B0),
            ),
          ),
          Transform.translate(
            offset: const Offset(-12, 0),
            child: Container(
              height: 34,
              width: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6A1B9A),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Autobus',
            maxLines: 1,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  final Widget child;
  const _GradientBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF130522), Color(0xFF2D0C51), Color(0xFF130522)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
