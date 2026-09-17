import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/auth_field.dart';
import 'package:autobus/common_design/widgets/auth_screen_layout.dart';

class Signin extends StatefulWidget {
  const Signin({super.key, this.initialIdentifier});

  /// Prefills the email / username field (e.g. after subscribe → re-login).
  final String? initialIdentifier;

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialIdentifier?.trim() ?? '',
  );
  String _pin = '';

  @override
  void initState() {
    super.initState();
    if (_emailController.text.isEmpty) {
      LastLoginStore.read().then((id) {
        if (!mounted || id == null || _emailController.text.isNotEmpty) return;
        _emailController.text = id;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).push(
      PageTransition(
        type: PageTransitionType.leftToRightWithFade,
        child: const LogorSign(),
      ),
    );
  }

  void _submitLogin() {
    final email = _emailController.text.trim();
    if (email.isEmpty || _pin.length != 4) return;

    context.read<AuthBloc>().add(
      LoginEvent(identifier: email, password: _pin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = AuthScreenTokens.scaleOf(context);
    final fieldWidth = AuthScreenTokens.fieldWidth(scale);
    final fieldHeight = AuthScreenTokens.fieldHeight(scale);

    return AuthScreenScaffold(
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
          } else if (state is AuthError && state.source == 'login') {
            showAppSnackBar(
              context,
              userFacingError(state.message, action: 'signing in'),
            );
          }
        },
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
                AuthBackButton(onTap: _onBack),
                SizedBox(height: 12 * scale),
                AuthScreenHeader(
                  scale: scale,
                  title: 'Sign In',
                  subtitle: 'Agentic business management',
                ),
                SizedBox(height: 32 * scale),
                AuthField(
                  width: fieldWidth,
                  height: fieldHeight,
                  scale: scale,
                  icon: Icons.person_outline,
                  controller: _emailController,
                  enabled: !isLoading,
                  hintText: 'Email or username',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16 * scale),
                AuthFieldLabel(scale: scale, label: 'PIN'),
                SizedBox(height: 8 * scale),
                PinDigitInput(
                  enabled: !isLoading,
                  onChanged: (v) => _pin = v,
                  onCompleted: (_) {
                    if (_emailController.text.isNotEmpty) {
                      _submitLogin();
                    }
                  },
                ),
                SizedBox(height: 16 * scale),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageTransition(
                          type: PageTransitionType.rightToLeftWithFade,
                          child: const RecoverAccount(),
                        ),
                      );
                    },
                    child: Text(
                      'Forgot password?',
                      style: GoogleFonts.montserrat(
                        color: AuthScreenTokens.labelColor,
                        fontSize: 13 * scale.clamp(0.9, 1.05),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 28 * scale),
                AuthPrimaryButton(
                  scale: scale,
                  label: 'Sign in',
                  loading: isLoading,
                  onPressed: _submitLogin,
                ),
                SizedBox(height: 32 * scale),
                AuthLinkText(
                  scale: scale,
                  prompt: "Don't have an account?",
                  action: 'Sign Up',
                  onTap: () {
                    Navigator.of(context).push(
                      PageTransition(
                        type: PageTransitionType.leftToRightWithFade,
                        child: const Signup(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
