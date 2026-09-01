import 'package:autobus/barrel.dart';

class ManageSenderEmailPage extends StatefulWidget {
  const ManageSenderEmailPage({super.key});

  @override
  State<ManageSenderEmailPage> createState() => _ManageSenderEmailPageState();
}

class _ManageSenderEmailPageState extends State<ManageSenderEmailPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _fieldError;
  String _savedEmail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = await context.read<ApiService>().getUserProfile();
      final email = (user['sender_email'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _savedEmail = email;
        _controller.text = email;
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

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        _fieldError = 'Enter a from email, for example noreply@useautobus.com';
      });
      return;
    }
    setState(() {
      _saving = true;
      _fieldError = null;
    });
    try {
      final updated = await context.read<ApiService>().updateSenderEmail(
        senderEmail: value,
      );
      if (!mounted) return;
      final saved = (updated['sender_email'] ?? value).toString().trim();
      setState(() {
        _savedEmail = saved;
        _controller.text = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'From email saved. Emails will send as $saved.',
            style: GoogleFonts.montserrat(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldError = userFacingError(e);
      });
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
                  const ManageScreenHeader(
                    title: 'From email',
                    padding: EdgeInsets.zero,
                    trailing: CreditAvatar(creditCategory: CreditCategory.email),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _loading
                        ? const Center(child: AutobusLoadingIndicator(size: 32))
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Add the From address Autobus uses when sending email on your behalf. Use an Autobus address such as noreply@useautobus.com.',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (_loadError != null) ...[
                                  Text(
                                    _loadError!,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.amber.shade200,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextField(
                                  controller: _controller,
                                  enabled: !_saving,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  onTapOutside: dismissAppKeyboard,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'noreply@useautobus.com',
                                    hintStyle: GoogleFonts.montserrat(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      fontSize: 14,
                                    ),
                                    errorText: _fieldError,
                                    errorMaxLines: 3,
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.06),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF3F1163),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF3F1163),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF9333EA),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'You can enter noreply, noreply@useautobus.com, or noreply.useautobus.com. Replies go to your profile email.',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                                if (_savedEmail.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Currently sending from $_savedEmail',
                                    style: GoogleFonts.montserrat(
                                      color: const Color(0xFF22C55E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 28),
                                ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2A1447),
                                    disabledBackgroundColor: const Color(
                                      0xFF2A1447,
                                    ).withValues(alpha: 0.4),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                  child: _saving
                                      ? const AutobusLoadingIndicator(size: 22)
                                      : Text(
                                          'Save from email',
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                ),
                              ],
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
