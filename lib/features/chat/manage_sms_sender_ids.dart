import 'package:autobus/barrel.dart';

class ManageSmsSenderIds extends StatefulWidget {
  const ManageSmsSenderIds({super.key});

  @override
  State<ManageSmsSenderIds> createState() => _ManageSmsSenderIdsState();
}

class _ManageSmsSenderIdsState extends State<ManageSmsSenderIds> {
  var _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final rows = await context.read<ApiService>().listSmsSenderIds();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _rows = const [];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _approved => _rows
      .where((r) => (r['status'] ?? '').toString().toLowerCase() == 'approved')
      .toList();

  List<Map<String, dynamic>> get _notApproved => _rows
      .where((r) => (r['status'] ?? '').toString().toLowerCase() != 'approved')
      .toList();

  Future<void> _openRegisterDialog() async {
    final result =
        await showDialog<({String senderId, String? notes})>(
      context: context,
      builder: (_) => const _SmsSenderIdDialog(),
    );
    if (!mounted || result == null) return;

    try {
      await context.read<ApiService>().registerSmsSenderId(
            senderId: result.senderId,
            notes: result.notes,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sender ID submitted for approval.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e),
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ManageScreenHeader(
                    title: 'SMS Sender IDs',
                    padding: EdgeInsets.zero,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_loading)
                          IconButton(
                            onPressed: _refresh,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white70,
                            ),
                            tooltip: 'Refresh',
                          ),
                        IconButton(
                          onPressed: _openRegisterDialog,
                          icon: const Icon(Icons.add, color: Colors.white),
                          tooltip: 'Register Sender ID',
                        ),
                        const CreditAvatar(creditCategory: CreditCategory.llm),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Register a Sender ID for SMS. Approved IDs can be used after the Autobus team verifies them.',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _loading
                        ? const Center(child: AutobusLoadingIndicator(size: 32))
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            color: Colors.white,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_loadError != null) ...[
                                    Text(
                                      _loadError!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: Colors.amber.shade200,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  _SectionHeader(
                                    title: 'Approved',
                                    count: _approved.length,
                                  ),
                                  const SizedBox(height: 12),
                                  if (_approved.isEmpty)
                                    const _EmptyHint(
                                      text: 'No approved Sender IDs yet.',
                                    )
                                  else
                                    for (final row in _approved)
                                      _SenderIdCard(row: row),
                                  const SizedBox(height: 28),
                                  _SectionHeader(
                                    title: 'Not approved',
                                    count: _notApproved.length,
                                  ),
                                  const SizedBox(height: 12),
                                  if (_notApproved.isEmpty)
                                    const _EmptyHint(
                                      text:
                                          'No pending or rejected Sender IDs.',
                                    )
                                  else
                                    for (final row in _notApproved)
                                      _SenderIdCard(row: row),
                                  const SizedBox(height: 88),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterDialog,
        backgroundColor: const Color(0xFF9333EA),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Register Sender ID',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SenderIdCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _SenderIdCard({required this.row});

  static String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending approval';
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderId = (row['sender_id'] ?? '').toString();
    final status = (row['status'] ?? 'pending').toString().toLowerCase();
    final company = (row['company_name'] ?? '').toString().trim();
    final notes = (row['notes'] ?? '').toString().trim();
    final rejection = (row['rejection_reason'] ?? '').toString().trim();
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1333).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  senderId,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _statusLabel(status),
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (company.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              company,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notes,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (rejection.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: $rejection',
              style: GoogleFonts.poppins(
                color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmsSenderIdDialog extends StatefulWidget {
  const _SmsSenderIdDialog();

  @override
  State<_SmsSenderIdDialog> createState() => _SmsSenderIdDialogState();
}

class _SmsSenderIdDialogState extends State<_SmsSenderIdDialog> {
  final _senderIdController = TextEditingController();
  final _notesController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _senderIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 13,
      ),
      errorText: errorText,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: const Color(0xFF9333EA).withValues(alpha: 0.45),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: const Color(0xFF9333EA).withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF9333EA)),
      ),
    );
  }

  void _submit() {
    final senderId = _senderIdController.text.trim();
    if (senderId.length < 3) {
      setState(() {
        _error = 'Enter a Sender ID (at least 3 characters).';
      });
      return;
    }
    Navigator.of(context).pop((
      senderId: senderId,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight =
        (media.size.height - media.viewInsets.bottom - 48).clamp(240.0, media.size.height * 0.85);
    return Dialog(
      backgroundColor: const Color(0xFF1A1333),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register SMS Sender ID',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Submit the name that appears as the SMS sender. It is registered under your business name from signup so SMS cannot be sent under a different company. The Autobus team will verify and approve it before it can be used.',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _senderIdController,
                autofocus: true,
                onTapOutside: dismissAppKeyboard,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                textCapitalization: TextCapitalization.characters,
                decoration: _fieldDecoration(
                  hint: 'Sender ID (e.g. AutoBus)',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                onTapOutside: dismissAppKeyboard,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                maxLines: 2,
                decoration: _fieldDecoration(hint: 'Notes (optional)'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                    ),
                    child: Text(
                      'Submit',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
