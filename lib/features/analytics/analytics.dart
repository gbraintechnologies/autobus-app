import 'package:autobus/barrel.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  double _growthPercentage = 0.0;
  String _growthMonth = '';
  int _rmaValue = 0;
  int _valValue = 0;
  List<MetricData> _metrics = [];

  late final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final results = await Future.wait([
        _apiService.getTotalRevenue(),
        _apiService.getFinancials(),
        _apiService.listOrders(skip: 0, limit: 200),
        _apiService.listBillings(page: 0, size: 200),
      ]);

      final revenue = results[0] as double;
      final transactions = results[1] as List<Map<String, dynamic>>;
      final orders = results[2] as List<Map<String, dynamic>>;
      final billings = results[3] as List<Map<String, dynamic>>;

      final completed = transactions
          .where((t) => t['status'] == 'completed')
          .length;
      final pending = transactions
          .where((t) => t['status'] == 'pending')
          .length;
      final failed = transactions.where((t) => t['status'] == 'failed').length;
      final totalTxn = transactions.length;
      final totalAmount = transactions.fold<double>(
        0,
        (sum, t) => sum + (parseJsonDouble(t['amount']) ?? 0),
      );

      final now = DateTime.now();
      final monthNames = [
        '',
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

      final growth = totalAmount > 0 && revenue > 0
          ? ((revenue / totalAmount) * 100).clamp(0.0, 100.0)
          : 0.0;

      final orderIds = orders
          .map((o) => (o['order_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      final orderInvoices = billings.where((b) {
        if ((b['source_type'] ?? '').toString().toUpperCase() != 'ORDER') {
          return false;
        }
        final externalId = (b['external_id'] ?? '').toString();
        return externalId.isEmpty || orderIds.contains(externalId);
      }).toList();
      final paidInvoices = orderInvoices
          .where((b) => (b['status'] ?? '').toString().toUpperCase() == 'PAID')
          .length;
      final pendingInvoices = orderInvoices
          .where(
            (b) => (b['status'] ?? '').toString().toUpperCase() == 'PENDING',
          )
          .length;
      final invoicedValue = orderInvoices.fold<double>(
        0,
        (sum, b) => sum + (parseJsonDouble(b['amount']) ?? 0),
      );

      setState(() {
        _growthPercentage = double.parse(growth.toStringAsFixed(1));
        _growthMonth = monthNames[now.month];
        _rmaValue = totalTxn;
        _valValue = completed;
        _metrics = [
          MetricData('Total Transactions', totalTxn, 0),
          MetricData('Completed', completed, 0),
          MetricData('Pending', pending, 0),
          MetricData('Failed', failed, 0),
          MetricData('Total Amount', totalAmount.toInt(), 0),
          MetricData('Revenue', revenue.toInt(), 0),
          MetricData('Order Invoices', orderInvoices.length, 0),
          MetricData('Invoices Paid', paidInvoices, 0),
          MetricData('Invoices Pending', pendingInvoices, 0),
          MetricData('Invoiced Value', invoicedValue.toInt(), 0),
        ];
      });
    } catch (_) {
      // leave metrics empty on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AnalyticsBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              _buildTopBar(),

              const SizedBox(height: 30),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      // Growth & Average Card
                      _buildGrowthAverageCard(),

                      const SizedBox(height: 20),

                      // Metrics Grid
                      _buildMetricsGrid(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2D2D44),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          Text(
            'Reports',
            style: GoogleFonts.montserrat(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),

          const UserAvatar(size: 48, onLightBackground: true),
        ],
      ),
    );
  }

  Widget _buildGrowthAverageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _GrowthWidget(
              percentage: _growthPercentage,
              month: _growthMonth,
            ),
          ),
          const SizedBox(width: 20),

          Expanded(
            child: _AverageWidget(rmaValue: _rmaValue, valValue: _valValue),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _metrics.length,
      itemBuilder: (context, index) {
        return _MetricCard(metric: _metrics[index]);
      },
    );
  }
}

class _GrowthWidget extends StatelessWidget {
  final double percentage;
  final String month;

  const _GrowthWidget({required this.percentage, required this.month});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: percentage / 100,
                        strokeWidth: 5,
                        strokeAlign: BorderSide.strokeAlignInside,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    Text(
                      '${percentage.toInt()}%',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    month,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AverageWidget extends StatelessWidget {
  final int rmaValue;
  final int valValue;

  const _AverageWidget({required this.rmaValue, required this.valValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'RMA',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'VAL',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        rmaValue.toString(),
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        valValue.toString(),
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final MetricData metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final isPositive = metric.percentageChange >= 0;
    final changeColor = isPositive
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE63946);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // FIX 1: Removed MainAxisAlignment.spaceBetween (it spread 3 children
        // unevenly). Now using Spacer() to push the value row to the bottom.
        children: [
          // Title
          Text(
            metric.title,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Value and Change Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            // FIX 2: Changed CrossAxisAlignment.end → center so the large
            // number and the badge pill sit on the same vertical midpoint.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main Value
              Text(
                metric.value.toString(),
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),

              // Percentage Change Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: changeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isPositive ? '+' : ''}${metric.percentageChange.toStringAsFixed(2)}%',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: changeColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: changeColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MetricData {
  final String title;
  final int value;
  final double percentageChange;

  MetricData(this.title, this.value, this.percentageChange);

  factory MetricData.fromJson(Map<String, dynamic> json) {
    return MetricData(
      (json['title'] ?? '').toString(),
      parseJsonInt(json['value']) ?? 0,
      parseJsonDouble(json['percentageChange']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'value': value,
      'percentageChange': percentageChange,
    };
  }
}

class _AnalyticsBackground extends StatelessWidget {
  final Widget child;

  const _AnalyticsBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8E8E8), Color(0xFFE0E0E0), Color(0xFFD8D8D8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
