import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/features/reports/report_period.dart';
import 'package:autobus/features/reports/reports_snapshot.dart';
import 'package:autobus/icons/home_figma_icons.dart';

const _reportDesignWidth = 402.0;
const _reportBackgroundColor = Color(0xFFF3F3F7);
const _reportCardColor = Color(0xFFF8FAFC);
const _reportDividerColor = Color(0xFFAAABAB);
const _reportAccentColor = Color(0xFF7F03B9);

String reportPeriodHeading(ReportPeriod period) {
  if (period == ReportPeriod.thisMonth) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[DateTime.now().month - 1];
  }
  return period.label;
}

typedef _ReportMetric = ({String label, String value});
typedef _ReportSnapshotLoader = Future<ReportsSnapshot> Function(
  ApiService api,
  ReportPeriod period,
);

class _ReportMetricRow extends StatelessWidget {
  final double scale;
  final String label;
  final String value;
  final bool showDivider;

  const _ReportMetricRow({
    required this.scale,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10 * scale),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: _reportDividerColor,
          ),
      ],
    );
  }
}

class _ReportMetricsCard extends StatelessWidget {
  final double scale;
  final List<_ReportMetric> rows;

  const _ReportMetricsCard({required this.scale, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 8 * scale),
      decoration: BoxDecoration(
        color: _reportCardColor,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _ReportMetricRow(
              scale: scale,
              label: rows[i].label,
              value: rows[i].value,
              showDivider: i < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

Future<ReportsSnapshot> _loadFinancialSnapshot(
  ApiService api,
  ReportPeriod period,
) async {
  final results = await Future.wait<dynamic>([
    api.getRevenueByTimeline(period.apiValue),
    api.getFinancials(page: 1, pageSize: 200),
  ]);
  return ReportsSnapshot(
    period: period,
    revenue: results[0] as double,
    financials: results[1] as List<Map<String, dynamic>>,
  );
}

Future<ReportsSnapshot> _loadOrdersSnapshot(
  ApiService api,
  ReportPeriod period,
) async {
  final results = await Future.wait<dynamic>([
    api.listOrders(skip: 0, limit: 200),
    api.listBillings(page: 0, size: 200),
  ]);
  return ReportsSnapshot(
    period: period,
    orders: results[0] as List<Map<String, dynamic>>,
    billings: results[1] as List<Map<String, dynamic>>,
  );
}

Future<ReportsSnapshot> _loadInventorySnapshot(
  ApiService api,
  ReportPeriod period,
) async {
  final results = await Future.wait<dynamic>([
    api.listProducts(skip: 0, limit: 200),
    api.getLowStockInventory(),
  ]);
  return ReportsSnapshot(
    period: period,
    products: results[0] as List<Map<String, dynamic>>,
    lowStock: results[1] as List<Map<String, dynamic>>,
  );
}

Future<ReportsSnapshot> _loadEngagementSnapshot(
  ApiService api,
  ReportPeriod period,
) async {
  final results = await Future.wait<dynamic>([
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
      results[0] as Map<String, List<Map<String, dynamic>>>;
  final marketing = results[2] as Map<String, dynamic>;
  final emails = results[3] as Map<String, dynamic>;
  final completedList = conversations['completed'] ?? const [];
  final completedLifecycleCount = completedList
      .where(
        (c) => (c['conversation_lifecycle'] ?? '').toString() == 'completed',
      )
      .length;

  return ReportsSnapshot(
    period: period,
    conversationsCompleted: completedLifecycleCount,
    conversationsNonIntervention: completedList.length,
    conversationsActive: conversations['intervention_active']?.length ?? 0,
    interventions: (results[1] as List<Map<String, dynamic>>).length,
    marketingAssets:
        (marketing['total'] as num?)?.toInt() ??
        (marketing['items'] as List?)?.length ??
        0,
    sentEmails:
        (emails['total_returned'] as num?)?.toInt() ??
        (emails['emails'] as List?)?.length ??
        0,
  );
}

List<_ReportMetric> _financialMetrics(ReportsSnapshot snapshot) {
  final items = snapshot.filteredFinancials;
  return [
    (label: 'Payment revenue', value: formatReportCurrency(snapshot.revenue)),
    (
      label: 'Transaction volume',
      value: formatReportCurrency(snapshot.financialVolume),
    ),
    (label: 'Total transactions', value: '${items.length}'),
    (label: 'Completed', value: '${snapshot.completedTransactions}'),
    (label: 'Pending', value: '${snapshot.pendingTransactions}'),
    (label: 'Failed', value: '${snapshot.failedTransactions}'),
  ];
}

List<_ReportMetric> _ordersMetrics(ReportsSnapshot snapshot) {
  return [
    (label: 'Total orders', value: '${snapshot.filteredOrders.length}'),
    (
      label: 'Total value',
      value: formatReportCurrency(snapshot.ordersValue),
    ),
    (label: 'Invoices sent', value: '${snapshot.orderInvoicesSent}'),
    (label: 'Invoices paid', value: '${snapshot.paidOrderInvoices}'),
    (
      label: 'Invoiced amount',
      value: formatReportCurrency(snapshot.orderInvoicesValue),
    ),
  ];
}

List<_ReportMetric> _invoicesMetrics(ReportsSnapshot snapshot) {
  return [
    (label: 'Invoices sent', value: '${snapshot.orderInvoicesSent}'),
    (label: 'Paid', value: '${snapshot.paidOrderInvoices}'),
    (label: 'Pending', value: '${snapshot.pendingOrderInvoices}'),
    (label: 'Failed', value: '${snapshot.failedOrderInvoices}'),
    (
      label: 'Total invoiced',
      value: formatReportCurrency(snapshot.orderInvoicesValue),
    ),
    (
      label: 'Collected',
      value: formatReportCurrency(snapshot.paidOrderInvoicesValue),
    ),
  ];
}

List<_ReportMetric> _inventoryMetrics(ReportsSnapshot snapshot) {
  return [
    (label: 'Products in catalogue', value: '${snapshot.products.length}'),
    (label: 'Low-stock items', value: '${snapshot.lowStock.length}'),
  ];
}

List<_ReportMetric> _engagementMetrics(ReportsSnapshot snapshot) {
  return [
    (
      label: 'Completed conversations',
      value: '${snapshot.conversationsCompleted}',
    ),
    (
      label: 'Active interventions',
      value: '${snapshot.conversationsActive}',
    ),
    (label: 'Human handovers', value: '${snapshot.interventions}'),
    (label: 'Marketing assets', value: '${snapshot.marketingAssets}'),
    (label: 'Emails sent (recent)', value: '${snapshot.sentEmails}'),
  ];
}

/// Shared Figma light-theme layout for analytics detail reports.
class _LightReportDetailScreen extends StatefulWidget {
  final String title;
  final ReportsSnapshot initialSnapshot;
  final _ReportSnapshotLoader onReload;
  final List<_ReportMetric> Function(ReportsSnapshot snapshot) buildMetrics;

  const _LightReportDetailScreen({
    required this.title,
    required this.initialSnapshot,
    required this.onReload,
    required this.buildMetrics,
  });

  @override
  State<_LightReportDetailScreen> createState() =>
      _LightReportDetailScreenState();
}

class _LightReportDetailScreenState extends State<_LightReportDetailScreen> {
  late ReportPeriod _period;
  ReportsSnapshot? _snapshot;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _period = widget.initialSnapshot.period;
    _snapshot = widget.initialSnapshot;
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final next = await widget.onReload(api, _period);
      if (!mounted) return;
      setState(() {
        _snapshot = next;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
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
                        color: isSelected ? _reportAccentColor : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? HomeSfIcon(
                            icon: HomeFigmaIcons.checkmark,
                            size: 18,
                            color: _reportAccentColor,
                          )
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

    if (selected == null || selected == _period) return;
    setState(() => _period = selected);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _reportDesignWidth;
    final snap = _snapshot;

    return Scaffold(
      backgroundColor: _reportBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            scale: scale,
            title: widget.title,
            leading: AppScreenBackButton(
              scale: scale,
              enabled: !_loading,
            ),
            trailing: IconButton(
              onPressed: _loading ? null : _showPeriodFilter,
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
                        color: _reportAccentColor,
                      ),
                    )
                  : HomeSfIcon(
                      icon: HomeFigmaIcons.analyticsFilter,
                      size: 24 * scale.clamp(0.9, 1.1),
                      color: Colors.black,
                    ),
            ),
          ),
          Expanded(
            child: snap == null
                ? Center(
                    child: CircularProgressIndicator(color: _reportAccentColor),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      19 * scale,
                      16 * scale,
                      19 * scale,
                      32 * scale,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reportPeriodHeading(_period),
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        _ReportMetricsCard(
                          scale: scale,
                          rows: widget.buildMetrics(snap),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Figma ANALYTICS financial report detail (3237:2444).
class FinancialReportDetail extends StatelessWidget {
  final ReportsSnapshot snapshot;

  const FinancialReportDetail({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _LightReportDetailScreen(
      title: 'Financial report',
      initialSnapshot: snapshot,
      onReload: _loadFinancialSnapshot,
      buildMetrics: _financialMetrics,
    );
  }
}

class OrdersReportDetail extends StatelessWidget {
  final ReportsSnapshot snapshot;

  const OrdersReportDetail({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _LightReportDetailScreen(
      title: 'Orders report',
      initialSnapshot: snapshot,
      onReload: _loadOrdersSnapshot,
      buildMetrics: _ordersMetrics,
    );
  }
}

class OrderInvoicesReportDetail extends StatelessWidget {
  final ReportsSnapshot snapshot;

  const OrderInvoicesReportDetail({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _LightReportDetailScreen(
      title: 'Order invoices',
      initialSnapshot: snapshot,
      onReload: _loadOrdersSnapshot,
      buildMetrics: _invoicesMetrics,
    );
  }
}

class OperationsReportDetail extends StatelessWidget {
  final ReportsSnapshot snapshot;

  const OperationsReportDetail({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _LightReportDetailScreen(
      title: 'Inventory report',
      initialSnapshot: snapshot,
      onReload: _loadInventorySnapshot,
      buildMetrics: _inventoryMetrics,
    );
  }
}

class EngagementReportDetail extends StatelessWidget {
  final ReportsSnapshot snapshot;

  const EngagementReportDetail({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _LightReportDetailScreen(
      title: 'Engagement report',
      initialSnapshot: snapshot,
      onReload: _loadEngagementSnapshot,
      buildMetrics: _engagementMetrics,
    );
  }
}
