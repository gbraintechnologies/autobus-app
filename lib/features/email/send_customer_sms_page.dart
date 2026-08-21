import 'package:autobus/barrel.dart';
import 'package:autobus/features/email/send_customer_message_common.dart';

class SendCustomerSmsPage extends StatefulWidget {
  const SendCustomerSmsPage({super.key});

  @override
  State<SendCustomerSmsPage> createState() => _SendCustomerSmsPageState();
}

class _SendCustomerSmsPageState extends State<SendCustomerSmsPage> {
  static const Color _purple = Color(0xFF2A1447);
  static const Color _lightGrey = Color(0xFFEBEBEB);

  final TextEditingController _messageController = TextEditingController();
  Set<int> _selectedIds = {};
  List<Map<String, dynamic>> _customers = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
    _loadCustomers();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  int get _charCount => _messageController.text.length;

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
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message is required',
            style: GoogleFonts.montserrat(),
          ),
        ),
      );
      return;
    }
    if (message.length > 160) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SMS must be 160 characters or fewer',
            style: GoogleFonts.montserrat(),
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await context.read<ApiService>().sendCustomerSms(
        customerIds: _selectedIds.toList(),
        message: message,
      );
      if (!mounted) return;
      showCustomerMessageResultsDialog(context, result, channelLabel: 'SMS');
      final sent = result['sent'] ?? 0;
      if (sent is num && sent > 0) {
        _messageController.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            CustomerMessageComposeHeader(
              title: 'SMS',
              selectedIds: _selectedIds,
              customers: _customers,
              onSelectionChanged: (ids) => setState(() => _selectedIds = ids),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        cursorColor: _purple,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 160,
                        keyboardType: TextInputType.multiline,
                        onTapOutside: dismissAppKeyboard,
                        style: GoogleFonts.montserrat(
                          color: _purple,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your SMS…',
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
                          counterStyle: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: _purple.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                    if (_charCount > 140)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$_charCount / 160',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: _charCount > 160
                                ? Colors.red
                                : _purple.withValues(alpha: 0.55),
                          ),
                        ),
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
                          'Send SMS',
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
