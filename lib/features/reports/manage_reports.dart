import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/features/reports/report_details.dart';
import 'package:autobus/features/reports/report_period.dart';
import 'package:autobus/features/reports/reports_snapshot.dart';
import 'package:autobus/icons/home_figma_icons.dart';
/// Analytics dashboard — Figma frame 3237:2235.
class ManageReports extends StatefulWidget {
  const ManageReports({super.key});

  @override
  State<ManageReports> createState() => _ManageReportsState();
}

class _ManageReportsState extends State<ManageReports> {
  static const _surfaceColor = Color(0xFFF8FAFC);
  static const _accentColor = Color(0xFF7F03B9);
  static const _positiveSubColor = Color(0xFF51830B);
  static const _negativeSubColor = Color(0xFFE11D48);

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
        api.listDigitalMarketingAssets(limit: 50, offset: 0).catchError(
          (_) => <String, dynamic>{'items': <dynamic>[], 'total': 0},
        ),
        api.getMySentEmails(limit: 50).catchError(
          (_) => <String, dynamic>{'emails': <dynamic>[], 'total_returned': 0},
        ),
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

  Future<void> _showPeriodFilter() async {
    final selected = await showModalBottomSheet<ReportPeriod>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(21, 16, 21, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter by period',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...ReportPeriod.values.map((period) {
                  final isSelected = period == _period;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      period.label,
                      style: GoogleFonts.poppins(
                        color: isSelected ? _accentColor : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? HomeSfIcon(icon: HomeFigmaIcons.checkmark, size: 18, color: _accentColor)
                        : null,
                    onTap: () => Navigator.pop(context, period),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) _onPeriodChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final snap = _snapshot;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F7),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            scale: scale,
            title: 'Analytics',
            leading: IconButton(
              onPressed: _showPeriodFilter,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: 32 * scale,
                minHeight: 32 * scale,
              ),
              icon: HomeSfIcon(
                icon: HomeFigmaIcons.analyticsFilter,
                size: 24 * scale.clamp(0.9, 1.1),
                color: Colors.black,
              ),
            ),
            trailing: IconButton(
              onPressed: _loading ? null : _load,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: 32 * scale,
                minHeight: 32 * scale,
              ),
              icon: _loading
                  ? SizedBox(
                      width: 22 * scale,
                      height: 22 * scale,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accentColor,
                      ),
                    )
                  : HomeSfIcon(
                      icon: HomeFigmaIcons.analyticsRefresh,
                      size: 24 * scale.clamp(0.9, 1.1),
                      color: Colors.black,
                    ),
            ),
          ),
          Expanded(
            child: _loading && snap == null
                ? Center(
                    child: CircularProgressIndicator(color: _accentColor),
                  )
                : RefreshIndicator(
                    color: _accentColor,
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        17 * scale,
                        12 * scale,
                        17 * scale,
                        32 * scale,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loadError != null) ...[
                            _AnalyticsErrorBanner(message: _loadError!),
                            SizedBox(height: 12 * scale),
                          ],
                          if (snap != null) ...[
                            _RevenueHeroCard(
                              scale: scale,
                              revenue: formatReportCurrency(snap.revenue),
                            ),
                            SizedBox(height: 8 * scale),
                            _MetricsGrid(scale: scale, snapshot: snap),
                            SizedBox(height: 24 * scale),
                            Text(
                              'Detailed reports',
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12 * scale),
                            _DetailedReportsSection(
                              scale: scale,
                              snapshot: snap,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RevenueHeroCard extends StatelessWidget {
  final double scale;
  final String revenue;

  const _RevenueHeroCard({required this.scale, required this.revenue});

  static const _greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA3E635), Color(0xFF3D7A08)],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95 * scale,
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      decoration: BoxDecoration(
        color: _ManageReportsState._surfaceColor,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Row(
        children: [
          Container(
            width: 44 * scale,
            height: 44 * scale,
            decoration: BoxDecoration(
              gradient: _greenGradient,
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Center(
              child: HomeSfIcon(
                icon: HomeFigmaIcons.analyticsRevenue,
                size: 22 * scale.clamp(0.9, 1.1),
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 18 * scale),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenue',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4 * scale),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    revenue,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
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

class _MetricsGrid extends StatelessWidget {
  final double scale;
  final ReportsSnapshot snapshot;

  const _MetricsGrid({required this.scale, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    return Column(
      children: [
        _MetricRow(
          scale: scale,
          tiles: [
            _MetricTileData(
              label: 'Order value',
              value: formatReportCurrency(snap.ordersValue),
            ),
            _MetricTileData(
              label: 'Invoiced value',
              value: formatReportCurrency(snap.orderInvoicesValue),
              subtitle:
                  '${formatReportCurrency(snap.paidOrderInvoicesValue)} collected',
              subtitleColor: _ManageReportsState._positiveSubColor,
            ),
            _MetricTileData(
              label: 'Transactions',
              value: '${snap.filteredFinancials.length}',
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        _MetricRow(
          scale: scale,
          tiles: [
            _MetricTileData(
              label: 'Completed txns',
              value: '${snap.completedTransactions}',
            ),
            _MetricTileData(
              label: 'Pending txns',
              value: '${snap.pendingTransactions}',
            ),
            _MetricTileData(
              label: 'Failed txns',
              value: '${snap.failedTransactions}',
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        _MetricRow(
          scale: scale,
          tiles: [
            _MetricTileData(
              label: 'Orders',
              value: '${snap.filteredOrders.length}',
              subtitle: '${snap.countOrdersByStatus('completed')} done',
              subtitleColor: _ManageReportsState._negativeSubColor,
            ),
            _MetricTileData(
              label: 'Order invoices',
              value: '${snap.orderInvoicesSent}',
              subtitle: '${snap.paidOrderInvoices} paid',
              subtitleColor: _ManageReportsState._negativeSubColor,
            ),
            _MetricTileData(
              label: 'Products',
              value: '${snap.products.length}',
              subtitle: '${snap.lowStock.length} low stock',
              subtitleColor: _ManageReportsState._negativeSubColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTileData {
  final String label;
  final String value;
  final String? subtitle;
  final Color? subtitleColor;

  const _MetricTileData({
    required this.label,
    required this.value,
    this.subtitle,
    this.subtitleColor,
  });
}

class _MetricRow extends StatelessWidget {
  final double scale;
  final List<_MetricTileData> tiles;

  const _MetricRow({required this.scale, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) SizedBox(width: 7 * scale),
            Expanded(child: _MetricTile(scale: scale, data: tiles[i])),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final double scale;
  final _MetricTileData data;

  const _MetricTile({required this.scale, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 95 * scale),
      padding: EdgeInsets.fromLTRB(14 * scale, 12 * scale, 8 * scale, 12 * scale),
      decoration: BoxDecoration(
        color: _ManageReportsState._surfaceColor,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8 * scale),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              maxLines: 1,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (data.subtitle != null) ...[
            SizedBox(height: 2 * scale),
            Text(
              data.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: data.subtitleColor ?? Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailedReportsSection extends StatelessWidget {
  final double scale;
  final ReportsSnapshot snapshot;

  const _DetailedReportsSection({
    required this.scale,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    final chatCount = snap.conversationsNonIntervention + snap.conversationsActive;
    final invoiceSubtitle = snap.orderInvoicesSent > 0
        ? '${snap.orderInvoicesSent} sent · ${snap.paidOrderInvoices} paid'
        : 'No invoice';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReportGradientCard(
                scale: scale,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFA3E635), Color(0xFF3D7A08)],
                ),
                icon: HomeFigmaIcons.analyticsFinancial,
                title: 'Financial',
                subtitle: formatReportCurrency(snap.financialVolume),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FinancialReportDetail(snapshot: snap),
                  ),
                ),
              ),
            ),
            SizedBox(width: 7 * scale),
            Expanded(
              child: _ReportGradientCard(
                scale: scale,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF22C6DE), Color(0xFF0B748E)],
                ),
                icon: HomeFigmaIcons.analyticsOrdersReport,
                title: 'Orders',
                subtitle: '${snap.filteredOrders.length} orders',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => OrdersReportDetail(snapshot: snap),
                  ),
                ),
              ),
            ),
            SizedBox(width: 7 * scale),
            Expanded(
              child: _ReportGradientCard(
                scale: scale,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFA364C1), Color(0xFF610A8A)],
                ),
                icon: HomeFigmaIcons.analyticsInvoices,
                title: 'Invoices',
                subtitle: invoiceSubtitle,
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => OrderInvoicesReportDetail(snapshot: snap),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        Row(
          children: [
            Expanded(
              child: _ReportGradientCard(
                scale: scale,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF60A1F2), Color(0xFF174AB9)],
                ),
                icon: HomeFigmaIcons.analyticsInventory,
                title: 'Inventory',
                subtitle: '${snap.lowStock.length} low stock',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => OperationsReportDetail(snapshot: snap),
                  ),
                ),
              ),
            ),
            SizedBox(width: 7 * scale),
            Expanded(
              child: _ReportGradientCard(
                scale: scale,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF0AC78), Color(0xFFB25710)],
                ),
                icon: HomeFigmaIcons.analyticsEngagement,
                title: 'Engagement',
                subtitle: '$chatCount chats',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => EngagementReportDetail(snapshot: snap),
                  ),
                ),
              ),
            ),
            SizedBox(width: 7 * scale),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _ReportGradientCard extends StatelessWidget {
  final double scale;
  final LinearGradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportGradientCard({
    required this.scale,
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12 * scale),
        child: Ink(
          padding: EdgeInsets.fromLTRB(14 * scale, 7 * scale, 8 * scale, 8 * scale),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeSfIcon(
                icon: icon,
                size: 16 * scale.clamp(0.9, 1.05),
                color: const Color(0xFFFCD34D),
              ),
              SizedBox(height: 6 * scale),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsErrorBanner extends StatelessWidget {
  final String message;

  const _AnalyticsErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const HomeSfIcon(icon: HomeFigmaIcons.warning, color: Color(0xFFE11D48), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: const Color(0xFF881337),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
