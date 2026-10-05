import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

String _orderListTitle(Map<String, dynamic> o) {
  final name = (o['item_name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  return (o['order_number'] ?? o['order_id'] ?? 'Order').toString();
}

String _orderListSubtitleId(Map<String, dynamic> o) {
  final num = (o['order_number'] ?? '').toString().trim();
  if (num.isNotEmpty) return num;
  return (o['order_id'] ?? '').toString();
}

String _formatOrderListDate(Map<String, dynamic> o) {
  final raw = o['order_date']?.toString() ?? o['created_at']?.toString();
  final dt = DateTime.tryParse(raw ?? '');
  if (dt == null) return '—';
  final d = dt.toLocal();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd / $mm / ${d.year}';
}

class ActiveQueries extends StatefulWidget {
  const ActiveQueries({super.key});

  @override
  State<ActiveQueries> createState() => _ActiveQueriesState();
}

class _ActiveQueriesState extends State<ActiveQueries> {
  List<Map<String, dynamic>> _orders = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  void _openOrder(BuildContext context, Map<String, dynamic> o) {
    final orderId = (o['order_id'] ?? '').toString().trim();
    if (orderId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: orderId,
          initialTitle: _orderListTitle(o),
        ),
      ),
    ).then((refreshed) {
      if (refreshed == true && mounted) _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final list = await api.listOrders(
        skip: 0,
        limit: 100,
        orderStatus: 'pending',
      );
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

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Pending Orders',
      creditCategory: CreditCategory.server,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: LightScreenTheme.accent))
          : _loadError != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28 * scale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: LightScreenTheme.emptyState(scale),
                    ),
                    SizedBox(height: 16 * scale),
                    TextButton(
                      onPressed: _loadOrders,
                      child: Text(
                        'Retry',
                        style: LightScreenTheme.listTitle(scale).copyWith(
                          color: LightScreenTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: LightScreenTheme.accent,
              onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
                        Center(
                          child: Text(
                            'No pending orders',
                            style: LightScreenTheme.emptyState(scale),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 32 * scale),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12 * scale),
                      itemBuilder: (context, index) {
                        final o = _orders[index];
                        return LightListCard(
                          scale: scale,
                          onTap: () => _openOrder(context, o),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _orderListTitle(o),
                                style: LightScreenTheme.listTitle(scale),
                              ),
                              SizedBox(height: 12 * scale),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _orderListSubtitleId(o),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: LightScreenTheme.listSubtitle(scale),
                                    ),
                                  ),
                                  SizedBox(width: 12 * scale),
                                  Text(
                                    _formatOrderListDate(o),
                                    style: LightScreenTheme.listSubtitle(scale),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
