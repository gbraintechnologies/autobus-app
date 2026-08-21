import 'package:autobus/barrel.dart';

class ViewCustomersPage extends StatefulWidget {
  const ViewCustomersPage({super.key});

  @override
  State<ViewCustomersPage> createState() => _ViewCustomersPageState();
}

class _ViewCustomersPageState extends State<ViewCustomersPage> {
  List<Map<String, dynamic>> _customers = const [];
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
      final list = await api.listCustomers();
      if (!mounted) return;
      setState(() {
        _customers = list;
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

  int? _customerId(Map<String, dynamic> c) {
    final raw = c['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String _customerName(Map<String, dynamic> c) =>
      (c['name'] ?? 'Customer').toString();

  Future<void> _confirmDelete(Map<String, dynamic> customer) async {
    final id = _customerId(customer);
    if (id == null) return;
    final name = _customerName(customer);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E0C37),
        title: Text(
          'Delete customer?',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        content: Text(
          'Remove $name from your contacts? This cannot be undone.',
          style: GoogleFonts.montserrat(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.montserrat(color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteCustomer(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $name', style: GoogleFonts.montserrat()),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e),
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openEdit(Map<String, dynamic> customer) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AddCustomerPage(existing: customer),
      ),
    ).then((refreshed) {
      if (refreshed == true && mounted) _load();
    });
  }

  Widget _customerTile(Map<String, dynamic> c) {
    final phone = (c['customer_number'] ?? '').toString();
    final email = (c['email'] ?? '').toString().trim();
    final network = (c['network'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3F1163), width: 1),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _customerName(c),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _openEdit(c),
                icon: const Icon(Icons.edit_outlined, color: Color(0xFFA855F7)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(c),
                icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              phone,
              style: GoogleFonts.outfit(
                color: const Color(0xFFA855F7),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ],
          if (network.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              network,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: ManageScreenStyle.homeDashboardBodyDecoration,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ManageScreenBackButton(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          'Your customers',
                          style: ManageScreenStyle.headerTitleStyle(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _loading
                        ? const Center(child: AutobusLoadingIndicator(size: 32))
                        : _loadError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _loadError!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.75),
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
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFA855F7),
                            onRefresh: _load,
                            child: _customers.isEmpty
                                ? ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height: MediaQuery.sizeOf(context).height * 0.2,
                                      ),
                                      Center(
                                        child: Text(
                                          'No customers yet',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    children: _customers.map(_customerTile).toList(),
                                  ),
                          ),
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
