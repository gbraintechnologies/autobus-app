import 'package:autobus/barrel.dart';

/// Bottom sheet to search and multi-select saved customers.
Future<Set<int>?> showCustomerPickerSheet(
  BuildContext context, {
  required Set<int> initialSelection,
}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _CustomerPickerSheet(initialSelection: initialSelection),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  final Set<int> initialSelection;

  const _CustomerPickerSheet({required this.initialSelection});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  static const Color _purple = Color(0xFF2A1447);

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _customers = const [];
  late Set<int> _selected;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initialSelection);
    _searchController.addListener(() => setState(() {}));
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
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

  String _customerSubtitle(Map<String, dynamic> c) {
    final phone = (c['customer_number'] ?? '').toString();
    final email = (c['email'] ?? '').toString().trim();
    if (phone.isNotEmpty && email.isNotEmpty) return '$phone · $email';
    if (phone.isNotEmpty) return phone;
    if (email.isNotEmpty) return email;
    return '';
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers.where((c) {
      final name = _customerName(c).toLowerCase();
      final phone = (c['customer_number'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.contacts_outlined, color: _purple),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select recipients',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _purple,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, _selected),
                      child: Text(
                        'Done (${_selected.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CustColors.logolight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  cursorColor: _purple,
                  onTapOutside: dismissAppKeyboard,
                  decoration: InputDecoration(
                    hintText: 'Search contacts…',
                    prefixIcon: const Icon(Icons.search, color: _purple),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14, color: _purple),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: AutobusLoadingIndicator())
                      : _loadError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loadCustomers,
                                child: Text(
                                  'Retry',
                                  style: GoogleFonts.poppins(
                                    color: CustColors.logolight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                      ? Center(
                          child: Text(
                            _customers.isEmpty
                                ? 'No customers yet. Add contacts from the Customers screen.'
                                : 'No matches for your search.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _purple.withValues(alpha: 0.65),
                            ),
                          ),
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final c = filtered[index];
                            final id = _customerId(c);
                            if (id == null) return const SizedBox.shrink();
                            final checked = _selected.contains(id);
                            return CheckboxListTile(
                              value: checked,
                              activeColor: CustColors.logolight,
                              checkColor: Colors.white,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _customerName(c),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _purple,
                                ),
                              ),
                              subtitle: Text(
                                _customerSubtitle(c),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _purple.withValues(alpha: 0.55),
                                ),
                              ),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
