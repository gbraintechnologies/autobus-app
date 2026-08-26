import 'package:autobus/barrel.dart';

class VerifyCode extends StatefulWidget {
  final String email;
  final String phone;

  const VerifyCode({
    super.key,
    this.email = '',
    this.phone = '',
  });

  @override
  State<VerifyCode> createState() => _VerifyCodeState();
}

class _VerifyCodeState extends State<VerifyCode> {
  final TextEditingController codeController = TextEditingController();

  String get _destination {
    if (widget.email.isNotEmpty) return widget.email;
    if (widget.phone.isNotEmpty) return widget.phone;
    return 'your account';
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ResetCodeVerified) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPassword(
                email: state.email,
                phone: state.phone,
                code: codeController.text.trim(),
              ),
            ),
          );
        } else if (state is ResetCodeSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is AuthError &&
            (state.source == 'verify_code' ||
                state.source == 'send_reset_code')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFacingError(state.message, action: 'verifying code')),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.03),
              AuthPageHeader(
                title: 'Verify Code',
                fontWeight: FontWeight.w300,
                onBack: () => Navigator.of(context).pop(),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Image.asset('assets/img/bot.png'),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.06),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Text(
                  'Enter the code sent to $_destination',
                  style: GoogleFonts.montserrat(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.only(left: 20.0, right: 20.0),
                child: Text(
                  'Enter Code',
                  style: GoogleFonts.montserrat(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: TextField(
                  onTapOutside: dismissAppKeyboard,
                  controller: codeController,
                  decoration: InputDecoration(
                    hintText: 'Enter 6-digit code',
                    hintStyle: GoogleFonts.montserrat(
                      color: Colors.black38,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: const UnderlineInputBorder(),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: GestureDetector(
                  onTap: () {
                    context.read<AuthBloc>().add(
                      SendResetCodeEvent(
                        email: widget.email,
                        phone: widget.phone,
                      ),
                    );
                  },
                  child: Text(
                    'Did not receive code? Resend Code',
                    style: GoogleFonts.montserrat(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              Center(
                child: AppButton(
                  onPressed: () {
                    if (codeController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter the verification code'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    context.read<AuthBloc>().add(
                      VerifyResetCodeEvent(
                        email: widget.email,
                        phone: widget.phone,
                        code: codeController.text.trim(),
                      ),
                    );
                  },
                  buttonText: 'Verify Code',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
