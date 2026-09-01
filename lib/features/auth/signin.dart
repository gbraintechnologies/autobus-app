import 'package:autobus/barrel.dart';

class Signin extends StatefulWidget {
  const Signin({super.key, this.initialIdentifier});

  /// Prefills the email / username field (e.g. after subscribe → re-login).
  final String? initialIdentifier;

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  late final TextEditingController emailController = TextEditingController(
    text: widget.initialIdentifier?.trim() ?? '',
  );
  String _pin = '';

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (emailController.text.isEmpty || _pin.length != 4) {
      return;
    }

    context.read<AuthBloc>().add(
      LoginEvent(identifier: emailController.text.trim(), password: _pin),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('=== SIGNIN SCREEN BUILDING ===');
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
          } else if (state is AuthError && state.source == 'login') {
            showAppSnackBar(context, userFacingError(state.message, action: 'signing in'));
          }
        },
        builder: (context, state) {
          final bool isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthPageHeader(
                      title: 'Login',
                      onBack: () => Navigator.of(context).pop(),
                    ),

                    const SizedBox(height: 24),

                    const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AutobusBranding(
                          wordmarkFontSize: 26,
                          markCircleSize: 34,
                          spacing: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Email or Username',
                              style: GoogleFonts.montserrat(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              onTapOutside: dismissAppKeyboard,
                              controller: emailController,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                border: const UnderlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                hintText: 'Enter email or username',
                                hintStyle: GoogleFonts.montserrat(
                                  color: Colors.black38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'PIN',
                              style: GoogleFonts.montserrat(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            PinDigitInput(
                              enabled: !isLoading,
                              onChanged: (v) => _pin = v,
                              onCompleted: (_) {
                                if (emailController.text.isNotEmpty) {
                                  _submitLogin();
                                }
                              },
                            ),
                            const SizedBox(height: 32),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    PageTransition(
                                      type: PageTransitionType
                                          .rightToLeftWithFade,
                                      child: const RecoverAccount(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot Password ?',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Center(
                              child: AppButton(
                                onPressed: isLoading ? null : _submitLogin,
                                buttonText: 'Login',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: MediaQuery.of(context).size.height * 0.25),

                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Dont have an Account ?",
                            style: GoogleFonts.montserrat(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                PageTransition(
                                  type: PageTransitionType.leftToRightWithFade,
                                  child: const Signup(),
                                ),
                              );
                            },
                            child: AppFitText(
                              'Sign Up',
                              style: GoogleFonts.montserrat(
                                color: CustColors.mainCol,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
