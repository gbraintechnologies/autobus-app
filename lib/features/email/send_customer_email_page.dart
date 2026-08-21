import 'package:autobus/barrel.dart';
import 'package:autobus/features/email/send_customer_message_common.dart';

class SendCustomerEmailPage extends StatefulWidget {
  const SendCustomerEmailPage({super.key});

  @override
  State<SendCustomerEmailPage> createState() => _SendCustomerEmailPageState();
}

class _SendCustomerEmailPageState extends State<SendCustomerEmailPage> {
  static const Color _purple = Color(0xFF2A1447);
  static const Color _lightGrey = Color(0xFFEBEBEB);

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  Set<int> _selectedIds = {};
  List<Map<String, dynamic>> _customers = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = await context.read<ApiService>().listCustomers();
      if (!mounted) return;
      setState(() => _customers = list);
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least one customer',
            style: GoogleFonts.montserrat(),
          ),
        ),
      );
      return;
    }
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subject and message are required',
            style: GoogleFonts.montserrat(),
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await context.read<ApiService>().sendCustomerEmail(
        customerIds: _selectedIds.toList(),
        subject: subject,
        body: body,
      );
      if (!mounted) return;
      showCustomerMessageResultsDialog(context, result, channelLabel: 'Email');
      final sent = result['sent'] ?? 0;
      if (sent is num && sent > 0) {
        _subjectController.clear();
        _bodyController.clear();
        setState(() => _selectedIds = {});
      }
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
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.montserrat(
        color: _purple.withValues(alpha: 0.55),
        fontSize: 14,
      ),
      filled: true,
      fillColor: _lightGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            CustomerMessageComposeHeader(
              title: 'Email',
              selectedIds: _selectedIds,
              customers: _customers,
              onSelectionChanged: (ids) => setState(() => _selectedIds = ids),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    TextField(
                      controller: _subjectController,
                      cursorColor: _purple,
                      onTapOutside: dismissAppKeyboard,
                      style: GoogleFonts.montserrat(color: _purple, fontSize: 14),
                      decoration: _inputDecoration('Subject'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyController,
                      cursorColor: _purple,
                      minLines: 6,
                      maxLines: 12,
                      keyboardType: TextInputType.multiline,
                      onTapOutside: dismissAppKeyboard,
                      style: GoogleFonts.montserrat(color: _purple, fontSize: 14),
                      decoration: _inputDecoration('Write your email…'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    disabledBackgroundColor: _purple.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: AutobusLoadingIndicator(size: 22),
                        )
                      : Text(
                          'Send email',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
