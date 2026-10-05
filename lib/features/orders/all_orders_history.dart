import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

String _orderHistoryTitle(Map<String, dynamic> o) {
  final name = (o['item_name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  return (o['order_number'] ?? o['order_id'] ?? 'Order').toString();
}

String _orderHistorySubtitleId(Map<String, dynamic> o) {
  final num = (o['order_number'] ?? '').toString().trim();
  if (num.isNotEmpty) return num;
  return (o['order_id'] ?? '').toString();
}

String _formatOrderHistoryDate(Map<String, dynamic> o) {
  final raw = o['order_date']?.toString() ?? o['created_at']?.toString();
  final dt = DateTime.tryParse(raw ?? '');
  if (dt == null) return '—';
  final d = dt.toLocal();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd / $mm / ${d.year}';
}

class AllOrdersHistory extends StatefulWidget {
  final String title;
  final String? orderStatus;
  final String emptyMessage;

  const AllOrdersHistory({
    super.key,
    this.title = 'All Orders',
    this.orderStatus,
    this.emptyMessage = 'No orders yet',
  });

  @override
  State<AllOrdersHistory> createState() => _AllOrdersHistoryState();
}

class _AllOrdersHistoryState extends State<AllOrdersHistory> {
  List<Map<String, dynamic>> _orders = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      var list = await api.listOrders(
        skip: 0,
        limit: 200,
        orderStatus: widget.orderStatus,
      );
      final statusFilter = widget.orderStatus?.trim().toLowerCase();
      if (statusFilter != null && statusFilter.isNotEmpty) {
        list = list
            .where(
              (o) =>
                  (o['order_status'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase() ==
                  statusFilter,
            )
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _orders = const [];
      });
    }
  }

  void _openOrder(BuildContext context, Map<String, dynamic> o) {
    final orderId = (o['order_id'] ?? '').toString().trim();
    if (orderId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: orderId,
          initialTitle: _orderHistoryTitle(o),
        ),
      ),
    ).then((refreshed) {
      if (refreshed == true && mounted) _loadOrders();
    });
  }

  Widget _orderTile(BuildContext context, Map<String, dynamic> o) {
    return GestureDetector(
      onTap: () => _openOrder(context, o),
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3F1163), width: 1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _orderHistoryTitle(o),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (widget.orderStatus == null) ...[
            const SizedBox(height: 8),
            Text(
              (o['order_status'] ?? '').toString(),
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _orderHistorySubtitleId(o),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatOrderHistoryDate(o),
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LightScreenScaffold(
      title: widget.title,
      creditCategory: CreditCategory.server,
      body: _loading
          ? const Center(child: AutobusLoadingIndicator(size: 32))
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loadOrders,
                    child: Text(
                      'Retry',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFA855F7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFA855F7),
              onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.25,
                        ),
                        Center(
                          child: Text(
                            widget.emptyMessage,
                            style: GoogleFonts.outfit(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _orderTile(context, _orders[index]);
                      },
                    ),
            ),
    );
  }
}
