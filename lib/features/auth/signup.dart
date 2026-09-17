import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/auth_field.dart';
import 'package:autobus/common_design/widgets/auth_screen_layout.dart';
import 'package:flutter/services.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _ghanaTenController = TextEditingController();
  final _ghanaCheckController = TextEditingController();
  final _ghanaCardCheckFocusNode = FocusNode();

  String _pin = '';

  String get _ghanaCardValue {
    final ten = _ghanaTenController.text.trim();
    final one = _ghanaCheckController.text.trim();
    if (ten.isEmpty && one.isEmpty) return '';
    return 'GHA-$ten-$one';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _ghanaTenController.dispose();
    _ghanaCheckController.dispose();
    _ghanaCardCheckFocusNode.dispose();
    super.dispose();
  }

  void _submitSignup() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      showAppSnackBar(context, 'Please enter a username');
      return;
    }
    if (_pin.length != 4) {
      showAppSnackBar(context, 'Please enter a 4-digit PIN');
      return;
    }

    context.read<AuthBloc>().add(
      SignupEvent(
        username: username,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        password: _pin,
        company: _companyController.text.trim(),
        ghanaCard: _ghanaCardValue,
      ),
    );
  }

  Widget _ghanaCardField(double scale, bool enabled) {
    final style = GoogleFonts.montserrat(
      fontSize: 14 * scale.clamp(0.9, 1.05),
      color: Colors.black87,
    );

    return AuthField(
      width: AuthScreenTokens.fieldWidth(scale),
      height: AuthScreenTokens.fieldHeight(scale),
      scale: scale,
      icon: Icons.badge_outlined,
      enabled: enabled,
      child: Row(
        children: [
          Text('GHA-', style: style),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _ghanaTenController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              maxLength: 10,
              style: style,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                if (v.length == 10) {
                  FocusScope.of(context).requestFocus(_ghanaCardCheckFocusNode);
                }
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                isDense: true,
                hintText: 'XXXXXXXXXX',
              ),
            ),
          ),
          Text('-', style: style),
          SizedBox(
            width: 28 * scale,
            child: TextField(
              controller: _ghanaCheckController,
              focusNode: _ghanaCardCheckFocusNode,
              enabled: enabled,
              keyboardType: TextInputType.number,
              maxLength: 1,
              textAlign: TextAlign.center,
              style: style,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                isDense: true,
                hintText: 'X',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = AuthScreenTokens.scaleOf(context);
    final fieldWidth = AuthScreenTokens.fieldWidth(scale);
    final fieldHeight = AuthScreenTokens.fieldHeight(scale);

    return AuthScreenScaffold(
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is Registered) {
                Navigator.of(context).pushReplacement(
                  PageTransition(
                    type: PageTransitionType.rightToLeftWithFade,
                    duration: const Duration(milliseconds: 800),
                    child: SignupOtp(
                      phone: _phoneController.text.trim(),
                      userEmail: _emailController.text.trim(),
                      initialBusinessName: _companyController.text.trim(),
                    ),
                  ),
                );
              } else if (state is AuthError && state.source == 'signup') {
                showAppSnackBar(
                  context,
                  userFacingError(state.message, action: 'creating account'),
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
                    title: 'Sign Up',
                    subtitle: 'Create your Autobus account',
                  ),
                  SizedBox(height: 28 * scale),
                  AuthFieldLabel(scale: scale, label: 'Username'),
                  SizedBox(height: 8 * scale),
                  AuthField(
                    width: fieldWidth,
                    height: fieldHeight,
                    scale: scale,
                    icon: Icons.person_outline,
                    controller: _usernameController,
                    enabled: !isLoading,
                    hintText: 'Enter your username',
                  ),
                  SizedBox(height: 16 * scale),
                  AuthFieldLabel(scale: scale, label: 'Phone'),
                  SizedBox(height: 8 * scale),
                  AuthField(
                    width: fieldWidth,
                    height: fieldHeight,
                    scale: scale,
                    icon: Icons.phone_outlined,
                    controller: _phoneController,
                    enabled: !isLoading,
                    hintText: '0241234567',
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16 * scale),
                  AuthFieldLabel(scale: scale, label: 'Company'),
                  SizedBox(height: 8 * scale),
                  AuthField(
                    width: fieldWidth,
                    height: fieldHeight,
                    scale: scale,
                    icon: Icons.business_outlined,
                    controller: _companyController,
                    enabled: !isLoading,
                    hintText: 'Enter your company name',
                  ),
                  SizedBox(height: 16 * scale),
                  AuthFieldLabel(scale: scale, label: 'Ghana Card'),
                  SizedBox(height: 8 * scale),
                  _ghanaCardField(scale, !isLoading),
                  SizedBox(height: 16 * scale),
                  AuthFieldLabel(scale: scale, label: 'Email'),
                  SizedBox(height: 8 * scale),
                  AuthField(
                    width: fieldWidth,
                    height: fieldHeight,
                    scale: scale,
                    icon: Icons.email_outlined,
                    controller: _emailController,
                    enabled: !isLoading,
                    hintText: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16 * scale),
                  AuthFieldLabel(scale: scale, label: 'Pin'),
                  SizedBox(height: 8 * scale),
                  PinDigitInput(
                    enabled: !isLoading,
                    onChanged: (v) => _pin = v,
                  ),
                  SizedBox(height: 28 * scale),
                  AuthPrimaryButton(
                    scale: scale,
                    label: 'Sign up',
                    loading: isLoading,
                    onPressed: _submitSignup,
                  ),
                  SizedBox(height: 16 * scale),
                  AuthLegalNotice(
                    prefix: 'By signing up, you agree to the ',
                    textColor: AuthScreenTokens.labelColor,
                    linkColor: AuthScreenTokens.accentColor,
                  ),
                  SizedBox(height: 28 * scale),
                  AuthLinkText(
                    scale: scale,
                    prompt: 'Already have an account?',
                    action: 'Sign In',
                    onTap: () => Navigator.of(context).maybePop(),
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
