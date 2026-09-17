import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/common_design/widgets/credits_pill.dart';

/// From Email settings — Figma ANALYTICS frame 3244:3669.
class FromEmailPage extends StatefulWidget {
  const FromEmailPage({super.key});

  @override
  State<FromEmailPage> createState() => _FromEmailPageState();
}

class _FromEmailPageState extends State<FromEmailPage> {
  static const _backgroundColor = Color(0xFFF3F3F7);
  static const _fieldColor = Color(0xFFFAFAFA);
  static const _buttonColor = Color(0xFF2D0C51);
  static const _hintColor = Color(0xFFC1BCBC);
  static const _bodyColor = Color(0xFF4D4D4D);

  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadEmail() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = await context.read<ApiService>().getUserProfile();
      if (!mounted) return;
      setState(() {
        _emailController.text = (user['email'] ?? '').toString().trim();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await context.read<ApiService>().updateUserProfile(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'From email saved',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      Navigator.of(context).pop(true);
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
      if (mounted) setState(() => _saving = false);
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
            title: 'From Email',
            leading: AppScreenBackButton(scale: scale),
            trailing: CreditsPill(
              scale: scale,
              creditCategory: CreditCategory.email,
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: _buttonColor),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      29 * scale,
                      8 * scale,
                      29 * scale,
                      16 * scale,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loadError != null) ...[
                            Text(
                              _loadError!,
                              style: GoogleFonts.poppins(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 12 * scale),
                          ],
                          Text(
                            'Set the email address customers will see when you send messages from Autobus.',
                            style: GoogleFonts.poppins(
                              color: _bodyColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 20 * scale),
                          SizedBox(
                            height: 56 * scale,
                            child: TextFormField(
                              controller: _emailController,
                              cursorColor: _buttonColor,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              decoration: _fieldDecoration('noreply@autobus.com'),
                              validator: (value) {
                                final email = (value ?? '').trim();
                                if (email.isEmpty) {
                                  return 'Email is required';
                                }
                                final emailPattern = RegExp(
                                  r'^[\w\.\+\-]+@[\w\-]+\.[\w\.\-]+$',
                                );
                                if (!emailPattern.hasMatch(email)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 20 * scale),
                          Text(
                            'Use a recognizable address so customers know who the message is from and can reply with confidence.',
                            style: GoogleFonts.poppins(
                              color: _bodyColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              35 * scale,
              0,
              35 * scale,
              16 * scale + bottomInset,
            ),
            child: SizedBox(
              height: 64 * scale,
              child: FilledButton(
                onPressed: _loading || _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _buttonColor,
                  disabledBackgroundColor: _buttonColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30 * scale),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? SizedBox(
                        width: 22 * scale,
                        height: 22 * scale,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save from email',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
