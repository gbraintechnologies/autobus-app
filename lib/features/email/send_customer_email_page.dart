import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/common_design/widgets/credits_pill.dart';
import 'package:autobus/features/customers/widgets/customer_picker_sheet.dart';
import 'package:autobus/features/email/send_customer_message_common.dart';
import 'package:autobus/icons/home_figma_icons.dart';

/// Send Email compose — Figma ANALYTICS frame 3242:3534.
class SendCustomerEmailPage extends StatefulWidget {
  const SendCustomerEmailPage({super.key});

  @override
  State<SendCustomerEmailPage> createState() => _SendCustomerEmailPageState();
}

class _SendCustomerEmailPageState extends State<SendCustomerEmailPage> {
  static const _backgroundColor = Color(0xFFF3F3F7);
  static const _fieldColor = Color(0xFFFAFAFA);
  static const _buttonColor = Color(0xFF2D0C51);
  static const _hintColor = Color(0xFFC1BCBC);

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

  Future<void> _openRecipientPicker() async {
    final result = await showCustomerPickerSheet(
      context,
      initialSelection: _selectedIds,
    );
    if (result != null) setState(() => _selectedIds = result);
  }

  String _nameForId(int id) {
    for (final c in _customers) {
      final raw = c['id'];
      final cid = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (cid == id) return (c['name'] ?? 'Customer').toString();
    }
    return 'Customer';
  }

  Future<void> _send() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least one recipient',
            style: GoogleFonts.poppins(),
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
            style: GoogleFonts.poppins(),
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
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: _hintColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            scale: scale,
            title: 'Send Email',
            leading: AppScreenBackButton(scale: scale),
            trailing: _RecipientPickerButton(
              scale: scale,
              count: _selectedIds.length,
              onTap: _openRecipientPicker,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                28 * scale,
                8 * scale,
                28 * scale,
                16 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tap the icon on your upper right to choose recipient',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: _hintColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                  if (_selectedIds.isNotEmpty) ...[
                    SizedBox(height: 12 * scale),
                    Wrap(
                      spacing: 8 * scale,
                      runSpacing: 8 * scale,
                      children: _selectedIds.map((id) {
                        return Chip(
                          label: Text(
                            _nameForId(id),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _selectedIds = Set<int>.from(_selectedIds)
                                ..remove(id);
                            });
                          },
                          backgroundColor: _fieldColor,
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                  ],
                  SizedBox(height: 16 * scale),
                  SizedBox(
                    height: 56 * scale,
                    child: TextField(
                      controller: _subjectController,
                      cursorColor: _buttonColor,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      decoration: _fieldDecoration('Subject'),
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  SizedBox(
                    height: 211 * scale,
                    child: TextField(
                      controller: _bodyController,
                      cursorColor: _buttonColor,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      decoration: _fieldDecoration('Write your message here...'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              35 * scale,
              0,
              35 * scale,
              24 * scale + bottomInset,
            ),
            child: SizedBox(
              height: 64 * scale.clamp(0.9, 1.05),
              child: FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: _buttonColor,
                  disabledBackgroundColor: _buttonColor.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30 * scale),
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
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientPickerButton extends StatelessWidget {
  final double scale;
  final int count;
  final VoidCallback onTap;

  const _RecipientPickerButton({
    required this.scale,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final headerScale = scale.clamp(0.9, 1.0);
    final size = 50 * headerScale;

    return Material(
      color: CreditsPill.pillColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              HomeSfIcon(
                icon: HomeFigmaIcons.viewCustomers,
                color: Colors.black,
                size: 26 * headerScale,
              ),
              if (count > 0)
                Positioned(
                  right: 6 * headerScale,
                  top: 6 * headerScale,
                  child: Container(
                    padding: EdgeInsets.all(4 * headerScale),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7F03B9),
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 18 * headerScale,
                      minHeight: 18 * headerScale,
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
