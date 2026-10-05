import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/auth_screen_layout.dart';
import 'package:autobus/features/onboarding/details_page.dart';

class SignupOtp extends StatefulWidget {
  final String phone;
  final String userEmail;
  final String initialBusinessName;

  const SignupOtp({
    super.key,
    required this.phone,
    this.userEmail = '',
    this.initialBusinessName = '',
  });

  @override
  State<SignupOtp> createState() => _SignupOtpState();
}

class _SignupOtpState extends State<SignupOtp> {
  String _otp = '';

  void _verify(String code) {
    if (code.length != 6) return;
    context.read<AuthBloc>().add(
      VerifySignupOtpEvent(phone: widget.phone, otp: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = AuthScreenTokens.scaleOf(context);

    return AuthScreenScaffold(
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) async {
              if (state is SignupOtpVerified) {
                context.read<AuthBloc>().add(const CheckSessionEvent());
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  PageTransition(
                    type: PageTransitionType.rightToLeftWithFade,
                    duration: const Duration(milliseconds: 800),
                    child: DetailsPage(
                      userEmail: widget.userEmail,
                      initialBusinessName: widget.initialBusinessName,
                    ),
                  ),
                );
              } else if (state is SignupOtpResent) {
                showAppSnackBar(
                  context,
                  state.message,
                  backgroundColor: CustColors.mainCol,
                );
              } else if (state is AuthError &&
                  (state.source == 'signup_otp' ||
                      state.source == 'signup_otp_resend')) {
                showAppSnackBar(
                  context,
                  userFacingError(state.message, action: 'verifying code'),
                );
              }
            },
          ),
        ],
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24 * scale,
                8 * scale,
                24 * scale,
                24 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBackButton(),
                  SizedBox(height: 12 * scale),
                  AuthScreenHeader(
                    scale: scale,
                    title: 'Verify OTP',
                    subtitle: 'Enter the 6-digit code sent to ${widget.phone}',
                  ),
                  SizedBox(height: 32 * scale),
                  AuthOtpInput(
                    scale: scale,
                    enabled: !isLoading,
                    onChanged: (code) => _otp = code,
                    onCompleted: _verify,
                  ),
                  SizedBox(height: 20 * scale),
                  Center(
                    child: GestureDetector(
                      onTap: isLoading
                          ? null
                          : () {
                              context.read<AuthBloc>().add(
                                ResendSignupOtpEvent(phone: widget.phone),
                              );
                            },
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            color: AuthScreenTokens.labelColor,
                            fontSize: 13,
                          ),
                          children: [
                            const TextSpan(text: "Didn't receive code? "),
                            TextSpan(
                              text: 'Resend',
                              style: TextStyle(
                                color: AuthScreenTokens.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32 * scale),
                  AuthPrimaryButton(
                    scale: scale,
                    label: 'Verify',
                    loading: isLoading,
                    onPressed: () => _verify(_otp),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
