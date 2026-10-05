import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/auth_screen_layout.dart';

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
  String _code = '';

  String get _destination {
    if (widget.email.isNotEmpty) return widget.email;
    if (widget.phone.isNotEmpty) return widget.phone;
    return 'your account';
  }

  void _verify(String code) {
    if (code.length != 6) return;
    context.read<AuthBloc>().add(
      VerifyResetCodeEvent(
        email: widget.email,
        phone: widget.phone,
        code: code,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = AuthScreenTokens.scaleOf(context);

    return AuthScreenScaffold(
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is ResetCodeVerified) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResetPassword(
                  email: state.email,
                  phone: state.phone,
                  code: state.code,
                ),
              ),
            );
          } else if (state is ResetCodeSent) {
            showAppSnackBar(context, state.message);
          } else if (state is AuthError &&
              (state.source == 'verify_code' ||
                  state.source == 'send_reset_code')) {
            showAppSnackBar(
              context,
              userFacingError(state.message, action: 'verifying code'),
            );
          }
        },
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
                    title: 'Verify Code',
                    subtitle: 'Enter the 6-digit code sent to $_destination',
                  ),
                  SizedBox(height: 32 * scale),
                  AuthOtpInput(
                    scale: scale,
                    enabled: !isLoading,
                    onChanged: (code) => _code = code,
                    onCompleted: _verify,
                  ),
                  SizedBox(height: 20 * scale),
                  Center(
                    child: GestureDetector(
                      onTap: isLoading
                          ? null
                          : () {
                              context.read<AuthBloc>().add(
                                SendResetCodeEvent(
                                  email: widget.email,
                                  phone: widget.phone,
                                ),
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
                    onPressed: () => _verify(_code),
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
