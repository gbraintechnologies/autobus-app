import 'package:autobus/barrel.dart';

class DetachBusinessPage extends StatefulWidget {
  final String businessId;
  final String email;
  final String name;

  const DetachBusinessPage({
    super.key,
    required this.businessId,
    required this.email,
    required this.name,
  });

  @override
  State<DetachBusinessPage> createState() => _DetachBusinessPageState();
}

class _DetachBusinessPageState extends State<DetachBusinessPage> {
  final codeController = TextEditingController();
  String _pin = '';
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void _sendCode() {
    setState(() => _busy = true);
    context.read<AuthBloc>().add(SendDetachOtpEvent(businessId: widget.businessId));
  }

  void _detach() {
    final otp = codeController.text.trim();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the code sent to this business email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a 4-digit password for this business'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    context.read<AuthBloc>().add(
      DetachBusinessEvent(
        businessId: widget.businessId,
        otp: otp,
        newPassword: _pin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is DetachOtpSent) {
          setState(() {
            _codeSent = true;
            _busy = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is Authenticated && state.lastBusinessOp == 'detached') {
          Navigator.of(context).pop();
        } else if (state is AuthError && state.source == 'detach_business') {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFacingError(state.message, action: 'detaching business')),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: GestureDetector(
        onTap: dismissAppKeyboard,
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthPageHeader(
                    title: 'Detach business',
                    fontWeight: FontWeight.w300,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We’ll send a code to ${widget.email}. After you set a password, this business leaves your switcher and can be signed into separately.',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_codeSent) ...[
                    Text(
                      'Code',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextField(
                      onTapOutside: dismissAppKeyboard,
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Enter the code',
                        hintStyle: GoogleFonts.montserrat(color: Colors.black38, fontSize: 14),
                        border: const UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'New password',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PinDigitInput(
                      autofocus: true,
                      onChanged: (v) => _pin = v,
                    ),
                  ],
                  const SizedBox(height: 40),
                  Center(
                    child: _busy
                        ? const AutobusLoadingIndicator()
                        : AppButton(
                            buttonText: _codeSent ? 'Detach business' : 'Send code',
                            onPressed: _codeSent ? _detach : _sendCode,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
