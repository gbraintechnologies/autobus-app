import 'package:autobus/barrel.dart';

class RecoverAccount extends StatefulWidget {
  const RecoverAccount({super.key});
  @override
  State<RecoverAccount> createState() => _RecoverAccountState();
}

class _RecoverAccountState extends State<RecoverAccount> {
  final TextEditingController identifierController = TextEditingController();

  bool _looksLikeEmail(String value) => value.contains('@');

  @override
  void dispose() {
    identifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is EmailExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account found. Sending reset code...')),
          );
          context.read<AuthBloc>().add(
            SendResetCodeEvent(email: state.email, phone: state.phone),
          );
        } else if (state is ResetCodeSent) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyCode(
                email: state.email,
                phone: state.phone,
              ),
            ),
          );
        } else if (state is AuthError &&
            (state.source == 'check_email' ||
                state.source == 'send_reset_code')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFacingError(state.message, action: 'finding account')),
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
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      'Reset Password',
                      style: GoogleFonts.montserrat(
                        color: Colors.black,
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 35,
                        width: 35,
                        decoration: BoxDecoration(
                          color: CustColors.mainCol,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CustColors.mainCol,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 50 * 0.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              Center(
                child: AutobusBranding(
                  wordmarkFontSize: 26,
                  markCircleSize: 34,
                  spacing: 14,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              Padding(
                padding: EdgeInsets.only(left: 20.0, right: 20.0),
                child: Text(
                  'Email or phone number',
                  style: GoogleFonts.montserrat(
                    color: const Color.fromARGB(255, 12, 12, 12),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: TextField(
                  onTapOutside: dismissAppKeyboard,
                  controller: identifierController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'name@example.com or phone number',
                    hintStyle: GoogleFonts.montserrat(
                      color: Colors.black38,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: const UnderlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12),
                child: Text(
                  'We will send a one-time code to reset your password.',
                  style: GoogleFonts.montserrat(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              Center(
                child: AppButton(
                  onPressed: () {
                    final identifier = identifierController.text.trim();
                    if (identifier.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter your email or phone number'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (_looksLikeEmail(identifier)) {
                      context.read<AuthBloc>().add(
                        CheckEmailExistsEvent(email: identifier),
                      );
                    } else {
                      context.read<AuthBloc>().add(
                        CheckEmailExistsEvent(phone: identifier),
                      );
                    }
                  },
                  buttonText: 'Send Code',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
