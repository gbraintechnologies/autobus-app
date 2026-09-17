import 'package:autobus/barrel.dart';
import 'package:autobus/features/customers/widgets/customer_picker_sheet.dart';

/// Shared header + recipient chips for customer messaging compose screens.
class CustomerMessageComposeHeader extends StatelessWidget {
  final String title;
  final Set<int> selectedIds;
  final List<Map<String, dynamic>> customers;
  final ValueChanged<Set<int>> onSelectionChanged;

  const CustomerMessageComposeHeader({
    super.key,
    required this.title,
    required this.selectedIds,
    required this.customers,
    required this.onSelectionChanged,
  });

  static const Color purple = Color(0xFF2A1447);

  Future<void> _openPicker(BuildContext context) async {
    final result = await showCustomerPickerSheet(
      context,
      initialSelection: selectedIds,
    );
    if (result != null) onSelectionChanged(result);
  }

  String _nameForId(int id) {
    for (final c in customers) {
      final raw = c['id'];
      final cid = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (cid == id) return (c['name'] ?? 'Customer').toString();
    }
    return 'Customer';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: SizedBox(
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: purple,
                        border: Border.all(
                          color: const Color(0xFFA92FEB),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: purple,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _openPicker(context),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: purple,
                        border: Border.all(
                          color: const Color(0xFFA92FEB),
                          width: 0.5,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.contacts_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          if (selectedIds.isNotEmpty)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFA92FE2),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '${selectedIds.length}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selectedIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedIds.map((id) {
                  return Chip(
                    label: Text(
                      _nameForId(id),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: purple,
                      ),
                    ),
                    deleteIcon: Icon(Icons.close, size: 16, color: purple),
                    onDeleted: () {
                      final next = Set<int>.from(selectedIds)..remove(id);
                      onSelectionChanged(next);
                    },
                    backgroundColor: const Color(0xFFEBEBEB),
                    side: BorderSide(color: purple.withValues(alpha: 0.2)),
                  );
                }).toList(),
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Tap contacts to choose recipients',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: purple.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
}

void showCustomerMessageResultsDialog(
  BuildContext context,
  Map<String, dynamic> response, {
  required String channelLabel,
}) {
  final sent = response['sent'] ?? 0;
  final failed = response['failed'] ?? 0;
  final total = response['total'] ?? 0;
  final results = response['results'];
  final List<Map<String, dynamic>> items = results is List
      ? results.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        '$channelLabel sent',
        style: GoogleFonts.poppins(
          color: CustomerMessageComposeHeader.purple,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$sent of $total delivered${failed > 0 ? ', $failed failed' : ''}.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: CustomerMessageComposeHeader.purple,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final r = items[i];
                  final ok = r['success'] == true;
                  final name = (r['customer_name'] ?? 'Customer').toString();
                  final msg = (r['message'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          ok ? Icons.check_circle : Icons.error_outline,
                          size: 18,
                          color: ok ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$name: $msg',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: CustomerMessageComposeHeader.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'OK',
            style: GoogleFonts.poppins(
              color: CustColors.logolight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
