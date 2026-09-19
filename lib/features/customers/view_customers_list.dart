import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

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
        backgroundColor: LightScreenTheme.surface,
        title: Text(
          'Delete customer?',
          style: GoogleFonts.poppins(color: Colors.black),
        ),
        content: Text(
          'Remove $name from your contacts? This cannot be undone.',
          style: GoogleFonts.poppins(
            color: LightScreenTheme.body,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: LightScreenTheme.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red.shade400),
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
          content: Text('Deleted $name', style: GoogleFonts.poppins()),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e),
            style: GoogleFonts.poppins(),
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

  Widget _customerTile(double scale, Map<String, dynamic> c) {
    final phone = (c['customer_number'] ?? '').toString();
    final email = (c['email'] ?? '').toString().trim();
    final network = (c['network'] ?? '').toString().trim();

    return LightListCard(
      scale: scale,
      padding: EdgeInsets.all(20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _customerName(c),
                  style: LightScreenTheme.listTitle(scale),
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _openEdit(c),
                icon: HomeSfIcon(icon: HomeFigmaIcons.edit, color: LightScreenTheme.accent, size: 22 * scale),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 36 * scale, minHeight: 36 * scale),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(c),
                icon: HomeSfIcon(icon: HomeFigmaIcons.delete, color: Colors.red.shade400, size: 22 * scale),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 36 * scale, minHeight: 36 * scale),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Text(
              phone,
              style: LightScreenTheme.listTitle(scale).copyWith(
                color: LightScreenTheme.accent,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (email.isNotEmpty) ...[
            SizedBox(height: 4 * scale),
            Text(email, style: LightScreenTheme.listSubtitle(scale)),
          ],
          if (network.isNotEmpty) ...[
            SizedBox(height: 4 * scale),
            Text(network, style: LightScreenTheme.listSubtitle(scale)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Your customers',
      creditCategory: CreditCategory.server,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: LightScreenTheme.accent))
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28 * scale),
                    child: Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: LightScreenTheme.emptyState(scale),
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  TextButton(
                    onPressed: _load,
                    child: Text(
                      'Retry',
                      style: LightScreenTheme.listTitle(scale).copyWith(
                        color: LightScreenTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: LightScreenTheme.accent,
              onRefresh: _load,
              child: _customers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
                        Center(
                          child: Text(
                            'No customers yet',
                            style: LightScreenTheme.emptyState(scale),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 32 * scale),
                      itemCount: _customers.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12 * scale),
                      itemBuilder: (context, index) => _customerTile(scale, _customers[index]),
                    ),
            ),
    );
  }
}
