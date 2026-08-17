import 'package:autobus/barrel.dart';

class SignupOtp extends StatefulWidget {
  final String phone;

  const SignupOtp({super.key, required this.phone});

  @override
  State<SignupOtp> createState() => _SignupOtpState();
}

class _SignupOtpState extends State<SignupOtp> {
  final TextEditingController codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is SignupOtpVerified) {
              context.read<SuccessBloc>().add(
                ShowSuccessEvent(
                  message: 'Account verified successfully!',
                  nextScreen: 'subscribe',
                ),
              );
              Navigator.of(context).pushReplacement(
                PageTransition(
                  type: PageTransitionType.rightToLeftWithFade,
                  duration: const Duration(milliseconds: 1000),
                  reverseDuration: const Duration(milliseconds: 600),
                  child: const Success(),
                ),
              );
            }
            if (state is SignupOtpResent) {
              showAppSnackBar(
                context,
                state.message,
                backgroundColor: CustColors.mainCol,
              );
            }
            if (state is AuthError &&
                (state.source == 'signup_otp' ||
                    state.source == 'signup_otp_resend')) {
              showAppSnackBar(context, state.message);
            }
          },
        ),
      ],
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
                      'Verify OTP',
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
                      onTap: () => Navigator.of(context).pop(),
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
              SizedBox(height: MediaQuery.of(context).size.height * 0.07),
              Center(
                child: const AutobusBranding(
                  wordmarkFontSize: 22,
                  markCircleSize: 30,
                  spacing: 12,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.07),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Text(
                  'Enter the OTP sent to ${widget.phone}',
                  style: GoogleFonts.montserrat(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    hintText: 'Enter 6-digit OTP',
                    hintStyle: GoogleFonts.montserrat(
                      color: Colors.black38,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: const UnderlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: GestureDetector(
                  onTap: () {
                    context.read<AuthBloc>().add(
                      ResendSignupOtpEvent(phone: widget.phone),
                    );
                  },
                  child: Text(
                    'Did not receive code? Resend',
                    style: GoogleFonts.montserrat(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              Center(
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return AppButton(
                      onPressed: () {
                        if (isLoading) return;

                        if (codeController.text.trim().isEmpty) {
                          showAppSnackBar(
                            context,
                            'Please enter the verification code',
                          );
                          return;
                        }

                        context.read<AuthBloc>().add(
                          VerifySignupOtpEvent(
                            phone: widget.phone,
                            otp: codeController.text.trim(),
                          ),
                        );
                      },
                      buttonText: isLoading ? 'Verifying...' : 'Verify',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
