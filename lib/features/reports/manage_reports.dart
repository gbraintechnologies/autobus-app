import 'package:autobus/barrel.dart';
import 'package:autobus/features/reports/report_details.dart';
import 'package:autobus/features/reports/report_period.dart';
import 'package:autobus/features/reports/reports_snapshot.dart';

class ManageReports extends StatefulWidget {
  const ManageReports({super.key});

  @override
  State<ManageReports> createState() => _ManageReportsState();
}

class _ManageReportsState extends State<ManageReports> {
  ReportPeriod _period = ReportPeriod.thisMonth;
  ReportsSnapshot? _snapshot;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait<dynamic>([
        api.getRevenueByTimeline(_period.apiValue),
        api.getFinancials(page: 1, pageSize: 200),
        api.listOrders(skip: 0, limit: 200),
        api.listBillings(page: 0, size: 200),
        api.listProducts(skip: 0, limit: 200),
        api.getLowStockInventory(),
        api.listMyConversations(skip: 0, limit: 100),
        api.listInterventions(limit: 100),
        api.listDigitalMarketingAssets(limit: 50, offset: 0),
        api.getMySentEmails(limit: 50),
      ]);

      final conversations =
          results[6] as Map<String, List<Map<String, dynamic>>>;
      final marketing = results[8] as Map<String, dynamic>;
      final emails = results[9] as Map<String, dynamic>;
      final interventions = results[7] as List<Map<String, dynamic>>;

      final completedList = conversations['completed'] ?? const [];
      final completedLifecycleCount = completedList
          .where(
            (c) =>
                (c['conversation_lifecycle'] ?? '').toString() == 'completed',
          )
          .length;

      if (!mounted) return;
      setState(() {
        _snapshot = ReportsSnapshot(
          period: _period,
          revenue: results[0] as double,
          financials: results[1] as List<Map<String, dynamic>>,
          orders: results[2] as List<Map<String, dynamic>>,
          billings: results[3] as List<Map<String, dynamic>>,
          products: results[4] as List<Map<String, dynamic>>,
          lowStock: results[5] as List<Map<String, dynamic>>,
          conversationsCompleted: completedLifecycleCount,
          conversationsNonIntervention: completedList.length,
          conversationsActive:
              conversations['intervention_active']?.length ?? 0,
          interventions: interventions.length,
          marketingAssets:
              parseJsonInt(marketing['total']) ??
              (marketing['items'] as List?)?.length ??
              0,
          sentEmails:
              parseJsonInt(emails['total_returned']) ??
              (emails['emails'] as List?)?.length ??
              0,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _snapshot = ReportsSnapshot(period: _period, error: _loadError);
      });
    }
  }

  void _onPeriodChanged(ReportPeriod period) {
    if (_period == period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: ManageScreenStyle.homeDashboardBodyDecoration,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: SizedBox(
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Analytics',
                            textAlign: TextAlign.center,
                            style: ManageScreenStyle.headerTitleStyle(),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              ManageScreenBackButton(),
                              SizedBox(width: 18),
                            ],
                          ),
                        ),
                        if (!_loading)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: _load,
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.white70,
                              ),
                              tooltip: 'Refresh',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PeriodSelector(
                  selected: _period,
                  onSelected: _onPeriodChanged,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: AutobusLoadingIndicator(),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF7B4BB7),
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_loadError != null) ...[
                                  _ErrorBanner(message: _loadError!),
                                  const SizedBox(height: 16),
                                ],
                                if (snap != null) ...[
                                  _OverviewSection(snapshot: snap),
                                  const SizedBox(height: 28),
                                  Text(
                                    'Detailed reports',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 1.05,
                                    children: [
                                      _ReportHubCard(
                                        icon: Icons.payments_outlined,
                                        title: 'Financial',
                                        subtitle: formatReportCurrency(
                                          snap.financialVolume,
                                        ),
                                        onTap: () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                FinancialReportDetail(
                                                  snapshot: snap,
                                                ),
                                          ),
                                        ),
                                      ),
                                      _ReportHubCard(
                                        icon: Icons.receipt_long_outlined,
                                        title: 'Orders',
                                        subtitle:
                                            '${snap.filteredOrders.length} orders',
                                        onTap: () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => OrdersReportDetail(
                                              snapshot: snap,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _ReportHubCard(
                                        icon: Icons.request_quote_outlined,
                                        title: 'Invoices',
                                        subtitle: snap.orderInvoicesSent > 0
                                            ? '${snap.orderInvoicesSent} sent · ${snap.paidOrderInvoices} paid'
                                            : 'No invoices yet',
                                        onTap: () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                OrderInvoicesReportDetail(
                                                  snapshot: snap,
                                                ),
                                          ),
                                        ),
                                      ),
                                      _ReportHubCard(
                                        icon: Icons.inventory_2_outlined,
                                        title: 'Inventory',
                                        subtitle:
                                            '${snap.lowStock.length} low stock',
                                        onTap: () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                OperationsReportDetail(
                                                  snapshot: snap,
                                                ),
                                          ),
                                        ),
                                      ),
                                      _ReportHubCard(
                                        icon: Icons.forum_outlined,
                                        title: 'Engagement',
                                        subtitle:
                                            '${snap.conversationsNonIntervention + snap.conversationsActive} chats',
                                        onTap: () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                EngagementReportDetail(
                                                  snapshot: snap,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onSelected;

  const _PeriodSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: ReportPeriod.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = ReportPeriod.values[index];
          final isSelected = period == selected;
          return FilterChip(
            label: Text(period.label),
            selected: isSelected,
            onSelected: (_) => onSelected(period),
            labelStyle: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            selectedColor: const Color(0xFF5A2D82),
            backgroundColor: const Color(0xFF1A0F2E),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF7B4BB7)
                  : const Color(0xFF3F1163),
            ),
            checkmarkColor: Colors.white,
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final ReportsSnapshot snapshot;

  const _OverviewSection({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Overview · ${snap.period.label}',
          style: GoogleFonts.montserrat(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        _HeroMetricCard(
          label: 'Revenue',
          value: formatReportCurrency(snap.revenue),
          icon: Icons.trending_up,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Order value',
                value: formatReportCurrency(snap.ordersValue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Transactions',
                value: '${snap.filteredFinancials.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Orders',
                value: '${snap.filteredOrders.length}',
                sub: '${snap.countOrdersByStatus('completed')} done',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Products',
                value: '${snap.products.length}',
                sub: '${snap.lowStock.length} low stock',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Completed txns',
                value: '${snap.completedTransactions}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Pending / failed',
                value:
                    '${snap.pendingTransactions} / ${snap.failedTransactions}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Order invoices',
                value: '${snap.orderInvoicesSent}',
                sub: '${snap.paidOrderInvoices} paid',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Invoiced value',
                value: formatReportCurrency(snap.orderInvoicesValue),
                sub: '${formatReportCurrency(snap.paidOrderInvoicesValue)} collected',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3F1163), Color(0xFF1E0C37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF5A2D82)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFB794F6), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;

  const _MetricTile({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3F1163)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: GoogleFonts.montserrat(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportHubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportHubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF3F1163)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3D1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE63946).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFE63946),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
