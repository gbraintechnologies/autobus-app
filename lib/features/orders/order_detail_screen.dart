import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

const List<String> kOrderStatuses = [
  'pending',
  'processing',
  'confirmed',
  'cancelled',
  'completed',
];

String orderDisplayTitle(Map<String, dynamic> o) {
  final name = (o['item_name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  return (o['order_number'] ?? o['order_id'] ?? 'Order').toString();
}

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String? initialTitle;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialTitle,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _loadError;
  bool _actionBusy = false;
  bool _invoiceBusy = false;
  bool _saveCustomerBusy = false;
  String? _selectedOrderStatus;

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
      final order = await api.getOrder(widget.orderId);
      if (!mounted) return;
      final status = (order['order_status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      setState(() {
        _order = order;
        _selectedOrderStatus = kOrderStatuses.contains(status)
            ? status
            : 'pending';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
      });
    }
  }

  Future<void> _updateOrderStatus() async {
    final status = _selectedOrderStatus?.trim();
    if (status == null || status.isEmpty) return;

    setState(() => _actionBusy = true);
    try {
      final api = context.read<ApiService>();
      final updated = await api.updateOrder(
        widget.orderId,
        orderStatus: status,
      );
      if (!mounted) return;
      setState(() {
        _order = updated;
        _actionBusy = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order updated to $status')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  bool _hasSavedCustomer(Map<String, dynamic> o) {
    final id = (o['customer_id'] ?? '').toString().trim();
    return id.isNotEmpty && id.toLowerCase() != 'null';
  }

  bool _hasSaveablePhone(Map<String, dynamic> o) {
    final phone = (o['customer_phone'] ?? '').toString().trim();
    if (phone.isEmpty) return false;
    final lower = phone.toLowerCase();
    return lower != 'n/a' &&
        lower != 'na' &&
        lower != 'none' &&
        lower != '-' &&
        lower != 'unknown';
  }

  Map<String, dynamic> _customerPrefill(Map<String, dynamic> o) {
    return {
      'name': (o['customer_name'] ?? '').toString(),
      'customer_number': (o['customer_phone'] ?? '').toString(),
      'email': (o['customer_email'] ?? '').toString(),
    };
  }

  Future<void> _openPrefillCustomerForm() async {
    final o = _order;
    if (o == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerPage(
          prefill: _customerPrefill(o),
          linkOrderId: widget.orderId,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _saveCustomerFromOrder() async {
    setState(() => _saveCustomerBusy = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.saveCustomerFromOrder(widget.orderId);
      if (!mounted) return;
      final updated = result['order'];
      setState(() {
        if (updated is Map) {
          _order = Map<String, dynamic>.from(updated);
        }
        _saveCustomerBusy = false;
      });
      final msg = (result['message'] ?? 'Customer saved').toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveCustomerBusy = false);
      final msg = userFacingError(e).toLowerCase();
      final needsReview = msg.contains('network') ||
          msg.contains('customer number') ||
          msg.contains('invalid');
      if (needsReview) {
        await _openPrefillCustomerForm();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  String _formatMoney(dynamic amount, String currency) {
    if (amount == null) return '—';
    final n = amount is num ? amount.toDouble() : double.tryParse('$amount');
    if (n == null) return '—';
    final value = n == n.roundToDouble()
        ? n.toStringAsFixed(0)
        : n.toStringAsFixed(2);
    return '$currency $value';
  }

  String _formatDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '—';
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd / $mm / ${d.year}';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3F1163)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: const Color(0xFFA855F7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _statusControls() {
    final current = (_order?['order_status'] ?? '').toString().toLowerCase();
    if (current != 'pending') return const SizedBox.shrink();

    return _section('Update status', [
      DropdownButtonFormField<String>(
        value: kOrderStatuses.contains(_selectedOrderStatus)
            ? _selectedOrderStatus
            : 'pending',
        dropdownColor: const Color(0xFF1E0A32),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
        items: kOrderStatuses
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(s[0].toUpperCase() + s.substring(1)),
              ),
            )
            .toList(),
        onChanged: _actionBusy
            ? null
            : (v) => setState(() => _selectedOrderStatus = v),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _actionBusy ? null : _updateOrderStatus,
        icon: _actionBusy
            ? const AutobusLoadingIndicator(size: 18)
            : const Icon(Icons.task_alt_outlined, size: 20),
        label: Text(
          'Apply status',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFA855F7),
          side: const BorderSide(color: Color(0xFF6B21A8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ]);
  }

  Future<void> _sendOrderInvoice() async {
    setState(() => _invoiceBusy = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.sendOrderInvoice(widget.orderId);
      if (!mounted) return;
      setState(() => _invoiceBusy = false);
      final msg = (result['message'] ?? 'Invoice sent').toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _invoiceBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  Widget _invoiceControls() {
    return _section('Invoice', [
      Text(
        'Create a Paystack payment link for this order and send it to the customer in chat.',
        style: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 13,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _invoiceBusy ? null : _sendOrderInvoice,
        icon: _invoiceBusy
            ? const AutobusLoadingIndicator(size: 18)
            : const Icon(Icons.receipt_long_outlined, size: 20),
        label: Text(
          'Send invoice to customer',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFA855F7),
          side: const BorderSide(color: Color(0xFF6B21A8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ]);
  }

  Widget _buildContent() {
    final o = _order!;
    final currency = (o['currency_code'] ?? 'GHS').toString();
    final notes = (o['notes'] ?? '').toString().trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _section('Order', [
          _infoRow('Number', (o['order_number'] ?? '—').toString()),
          _infoRow('Status', (o['order_status'] ?? '—').toString()),
          _infoRow('Payment', (o['payment_status'] ?? '—').toString()),
          _infoRow('Fulfillment', (o['fulfillment_status'] ?? '—').toString()),
          _infoRow('Date', _formatDate(o['order_date'] ?? o['created_at'])),
          if ((o['order_source'] ?? '').toString().isNotEmpty)
            _infoRow('Source', (o['order_source'] ?? '').toString()),
        ]),
        _section('Item', [
          _infoRow('Product', (o['item_name'] ?? '—').toString()),
          _infoRow(
            'Quantity',
            '${o['quantity'] ?? o['total_quantity'] ?? '—'}',
          ),
          _infoRow('Total', _formatMoney(o['total_amount'], currency)),
          if (o['subtotal_amount'] != null)
            _infoRow('Subtotal', _formatMoney(o['subtotal_amount'], currency)),
        ]),
        _section('Customer', [
          _infoRow('Name', (o['customer_name'] ?? '—').toString()),
          _infoRow('Phone', (o['customer_phone'] ?? '—').toString()),
          if ((o['customer_email'] ?? '').toString().isNotEmpty)
            _infoRow('Email', (o['customer_email'] ?? '').toString()),
          if ((o['customer_location'] ?? '').toString().isNotEmpty)
            _infoRow('Location', (o['customer_location'] ?? '').toString()),
          const SizedBox(height: 4),
          if (_hasSavedCustomer(o))
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Saved to customers',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          else if (_hasSaveablePhone(o))
            OutlinedButton.icon(
              onPressed: _saveCustomerBusy ? null : _saveCustomerFromOrder,
              icon: _saveCustomerBusy
                  ? const AutobusLoadingIndicator(size: 18)
                  : const Icon(Icons.person_add_outlined, size: 20),
              label: Text(
                'Save as customer',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFA855F7),
                side: const BorderSide(color: Color(0xFF6B21A8)),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          else
            Text(
              'Add a phone number on this order before saving the customer.',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
        ]),
        if (notes.isNotEmpty)
          _section('Notes', [
            Text(
              notes,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ]),
        _invoiceControls(),
        _statusControls(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialTitle?.trim().isNotEmpty == true
        ? widget.initialTitle!
        : (_order != null ? orderDisplayTitle(_order!) : 'Order');

    return LightScreenScaffold(
      title: title,
      creditCategory: CreditCategory.server,
      body: _loading
          ? const Center(child: AutobusLoadingIndicator(size: 32))
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _load,
                      child: Text(
                        'Retry',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFA855F7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _buildContent(),
    );
  }
}
